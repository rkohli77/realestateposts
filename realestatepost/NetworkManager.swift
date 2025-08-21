// iOS Companion App for Real Estate Facebook Automation
// Enhanced SwiftUI Implementation with Error Handling

import SwiftUI
import Foundation
import Combine

// **MARK: - Data Models**
struct PropertyListing: Codable, Identifiable {
    let id = UUID()
    let address: String
    let price: String
    let bedrooms: Int
    let bathrooms: Int
    let sqft: Int?
    let features: [String]
    let type: String
    let neighborhood: String?
    let city: String
    let imageUrl: String?
    
    // Helper computed property for formatted display
    var formattedPrice: String {
        return price.hasPrefix("$") ? price : "$\(price)"
    }
    
    var bedroomBathroomText: String {
        return "\(bedrooms) bed, \(bathrooms) bath"
    }
}

struct QueueItem: Codable, Identifiable {
    let id: String
    let type: String
    let content: String
    let priority: Int
    let status: String
    let createdAt: String
    
    // Helper for formatted date display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        if let date = isoFormatter.date(from: createdAt) {
            return formatter.string(from: date)
        }
        return createdAt
    }
}

struct QueueResponse: Codable {
    let queue: [QueueItem]
    let dailyPostCount: Int
    let remainingPostsToday: Int
}

struct APIResponse: Codable {
    let success: Bool
    let message: String?
    let queueId: String?
    let generatedContent: String?
    let error: String?
    let listing: PropertyListingResponse?
    let facebook: FacebookResponse?
}

struct PropertyListingResponse: Codable {
    let id: String?
    let address: String?
    let price: String?
    let city: String?
    let type: String?
    let bedrooms: Int?
    let bathrooms: Int?
}

struct FacebookResponse: Codable {
    let success: Bool
    let postId: String?
    let message: String?
    let error: String?
}

// **MARK: - Custom Error Types**
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case networkUnavailable
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkUnavailable:
            return "Network unavailable"
        case .notFound:
            return "Endpoint not found - check server configuration"
        }
    }
}

// **MARK: - Network Manager**
class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    private let baseURL = "https://real-estate-sage-theta.vercel.app"
    private let timeout: TimeInterval = 30.0
    
    @Published var isLoading = false
    @Published var lastError: String?
    
    private init() {}
    
    private var defaultSession: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        return URLSession(configuration: config)
    }
    
    // **MARK: - API Methods**
    
    func addListing(_ listing: PropertyListing) async throws -> APIResponse {
        // Try different possible endpoints based on your server structure
        let possibleEndpoints = [
            "/api/post-listing",           // Direct route in main server
            "/api/facebook/post-listing",  // If using router with /api/facebook prefix
            "/facebook/post-listing"       // If using router with /facebook prefix
        ]
        
        var lastError: Error?
        
        for endpoint in possibleEndpoints {
            do {
                let response = try await makeListingRequest(endpoint: endpoint, listing: listing)
                print("✅ Successfully connected to endpoint: \(endpoint)")
                return response
            } catch NetworkError.notFound {
                print("❌ Endpoint not found: \(endpoint)")
                lastError = NetworkError.notFound
                continue
            } catch {
                print("❌ Error with endpoint \(endpoint): \(error)")
                lastError = error
                // Don't continue for other types of errors, they likely indicate a real problem
                throw error
            }
        }
        
        // If we get here, none of the endpoints worked
        throw lastError ?? NetworkError.notFound
    }
    
    private func makeListingRequest(endpoint: String, listing: PropertyListing) async throws -> APIResponse {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw NetworkError.invalidURL
        }
        
        print("🔗 Trying endpoint: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        
        // Create a dictionary representation instead of encoding the struct directly
        let listingDict: [String: Any] = [
            "address": listing.address,
            "price": listing.price,
            "bedrooms": listing.bedrooms,
            "bathrooms": listing.bathrooms,
            "sqft": listing.sqft as Any,
            "features": listing.features,
            "type": listing.type,
            "neighborhood": listing.neighborhood as Any,
            "city": listing.city,
            "imageUrl": listing.imageUrl as Any
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: listingDict)
            
            let (data, response) = try await defaultSession.data(for: request)
            
            print("📥 Response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            
            // Check HTTP response status
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 HTTP Status: \(httpResponse.statusCode)")
                
                switch httpResponse.statusCode {
                case 200...299:
                    // Success - continue to decode
                    break
                case 404:
                    throw NetworkError.notFound
                case 400...499:
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorData["error"] as? String {
                        throw NetworkError.serverError(errorMessage)
                    }
                    throw NetworkError.serverError("Client error: HTTP \(httpResponse.statusCode)")
                case 500...599:
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorData["error"] as? String {
                        throw NetworkError.serverError(errorMessage)
                    }
                    throw NetworkError.serverError("Server error: HTTP \(httpResponse.statusCode)")
                default:
                    throw NetworkError.serverError("Unexpected status: HTTP \(httpResponse.statusCode)")
                }
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(APIResponse.self, from: data)
        } catch let error as DecodingError {
            print("❌ Decoding error: \(error)")
//            print("📄 Raw response: \(String(data: data, encoding: .utf8) ?? "No data")")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            print("❌ Network error: \(error)")
            throw NetworkError.networkUnavailable
        }
    }
    
    func postNow(content: String) async throws -> APIResponse {
        // Try different possible endpoints
        let possibleEndpoints = [
            "/api/post-now",           // Direct route in main server
            "/api/facebook/post-now",  // If using router with /api/facebook prefix
            "/facebook/post-now"       // If using router with /facebook prefix
        ]
        
        var lastError: Error?
        
        for endpoint in possibleEndpoints {
            do {
                let response = try await makePostRequest(endpoint: endpoint, content: content)
                print("✅ Successfully connected to endpoint: \(endpoint)")
                return response
            } catch NetworkError.notFound {
                print("❌ Endpoint not found: \(endpoint)")
                lastError = NetworkError.notFound
                continue
            } catch {
                print("❌ Error with endpoint \(endpoint): \(error)")
                lastError = error
                throw error
            }
        }
        
        throw lastError ?? NetworkError.notFound
    }
    
    private func makePostRequest(endpoint: String, content: String) async throws -> APIResponse {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw NetworkError.invalidURL
        }
        
        print("🔗 Trying endpoint: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        
        let payload: [String: Any] = ["content": content]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (data, response) = try await defaultSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 HTTP Status: \(httpResponse.statusCode)")
                
                switch httpResponse.statusCode {
                case 200...299:
                    break
                case 404:
                    throw NetworkError.notFound
                default:
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorData["error"] as? String {
                        throw NetworkError.serverError(errorMessage)
                    }
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            return try JSONDecoder().decode(APIResponse.self, from: data)
        } catch let error as DecodingError {
            print("❌ Decoding error: \(error)")
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkUnavailable
        }
    }
    
    func getQueue() async throws -> QueueResponse {
        guard let url = URL(string: "\(baseURL)/api/queue") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        
        do {
            let (data, response) = try await defaultSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                guard 200...299 ~= httpResponse.statusCode else {
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            return try JSONDecoder().decode(QueueResponse.self, from: data)
        } catch let error as DecodingError {
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkUnavailable
        }
    }
    
    func generateTipPost(topic: String) async throws -> APIResponse {
        guard let url = URL(string: "\(baseURL)/api/tip-post") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")
        
        let payload = ["topic": topic]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (data, response) = try await defaultSession.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                guard 200...299 ~= httpResponse.statusCode else {
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorData["error"] as? String {
                        throw NetworkError.serverError(errorMessage)
                    }
                    throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            
            return try JSONDecoder().decode(APIResponse.self, from: data)
        } catch let error as DecodingError {
            throw NetworkError.decodingError
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkUnavailable
        }
    }
    
    // **MARK: - Debug Methods**
    
    func testAllEndpoints() async {
        print("🧪 Testing all possible endpoints...")
        
        let testEndpoints = [
            "/",
            "/api/facebook-status",
            "/api/page-info",
            "/api/post-listing",
            "/api/post-now",
            "/api/facebook/post-listing",
            "/api/facebook/post-now",
            "/facebook/post-listing",
            "/facebook/post-now"
        ]
        
        for endpoint in testEndpoints {
            guard let url = URL(string: "\(baseURL)\(endpoint)") else { continue }
            
            do {
                var request = URLRequest(url: url)
                request.httpMethod = endpoint.contains("post") ? "POST" : "GET"
                request.timeoutInterval = 10
                
                let (_, response) = try await defaultSession.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    let status = httpResponse.statusCode
                    let statusEmoji = status == 200 ? "✅" : (status == 404 ? "❌" : "⚠️")
                    print("\(statusEmoji) \(endpoint): HTTP \(status)")
                }
            } catch {
                print("❌ \(endpoint): \(error.localizedDescription)")
            }
        }
    }
    
    // **MARK: - Convenience Methods**
    
    @MainActor
    func postListingWithUI(_ listing: PropertyListing) async {
        isLoading = true
        lastError = nil
        
        do {
            let response = try await addListing(listing)
            if !response.success {
                lastError = response.error ?? "Unknown error occurred"
            }
        } catch {
            lastError = error.localizedDescription
        }
        
        isLoading = false
    }
    
    @MainActor
    func postNowWithUI(content: String, imageUrl: String? = nil) async {
        isLoading = true
        lastError = nil
        
        do {
            let response = try await postNow(content: content)
            if !response.success {
                lastError = response.error ?? "Failed to post content"
            }
        } catch {
            lastError = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // Test connection to server
    func testConnection() async -> Bool {
        do {
            guard let url = URL(string: "\(baseURL)/") else { return false }
            let (_, response) = try await defaultSession.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            print("Connection test failed: \(error)")
            return false
        }
    }
}
