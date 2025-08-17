// iOS Companion App for Real Estate Facebook Automation
// SwiftUI Implementation

import SwiftUI
import Foundation
import Combine

// MARK: - Data Models
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
}

struct QueueItem: Codable, Identifiable {
    let id: String
    let type: String
    let content: String
    let priority: Int
    let status: String
    let createdAt: String
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
}

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    private let baseURL = "http://localhost:3000/api" // Replace with your server URL
    
    private init() {}
    
    func addListing(_ listing: PropertyListing) async throws -> APIResponse {
        let url = URL(string: "\(baseURL)/listings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(listing)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(APIResponse.self, from: data)
    }
    
    func postNow(content: String, imageUrl: String? = nil) async throws -> APIResponse {
        let url = URL(string: "\(baseURL)/post-now")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["content": content, "imageUrl": imageUrl ?? ""]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(APIResponse.self, from: data)
    }
    
    func getQueue() async throws -> QueueResponse {
        let url = URL(string: "\(baseURL)/queue")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(QueueResponse.self, from: data)
    }
    
    func generateTipPost(topic: String) async throws -> APIResponse {
        let url = URL(string: "\(baseURL)/tip-post")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["topic": topic]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(APIResponse.self, from: data)
    }
}
