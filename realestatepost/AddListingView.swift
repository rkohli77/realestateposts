import SwiftUI

// MARK: - Add Listing View
struct AddListingView: View {
    @State private var address = ""
    @State private var price = ""
    @State private var bedrooms = 3
    @State private var bathrooms = 2
    @State private var sqft = ""
    @State private var propertyType = "House"
    @State private var neighborhood = ""
    @State private var city = ""
    @State private var features = ""
    @State private var imageUrl = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var generatedContent = ""
    
    let propertyTypes = ["House", "Condo", "Townhouse", "Apartment", "Multi-Family"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Property Details") {
                    TextField("Address", text: $address)
                    TextField("Price (e.g., $450,000)", text: $price)
                    
                    Stepper("Bedrooms: \(bedrooms)", value: $bedrooms, in: 1...10)
                    Stepper("Bathrooms: \(bathrooms)", value: $bathrooms, in: 1...10)
                    
                    TextField("Square Footage", text: $sqft)
                        .keyboardType(.numberPad)
                    
                    Picker("Property Type", selection: $propertyType) {
                        ForEach(propertyTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Location") {
                    TextField("Neighborhood", text: $neighborhood)
                    TextField("City", text: $city)
                }
                
                Section("Additional Info") {
                    TextField("Key Features (comma separated)", text: $features, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Image URL", text: $imageUrl)
                }
                
                if !generatedContent.isEmpty {
                    Section("Generated Content Preview") {
                        Text(generatedContent)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                Button(action: submitListing) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isLoading ? "Generating Post..." : "Generate & Queue Post")
                    }
                }
                .disabled(isLoading || address.isEmpty || price.isEmpty)
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)
                .padding()
                .background(address.isEmpty || price.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(8)
            }
            .navigationTitle("Add Listing")
        }
        .alert("Result", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func submitListing() {
        isLoading = true
        
        let listing = PropertyListing(
            address: address,
            price: price,
            bedrooms: bedrooms,
            bathrooms: bathrooms,
            sqft: Int(sqft),
            features: features.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            type: propertyType,
            neighborhood: neighborhood.isEmpty ? nil : neighborhood,
            city: city,
            imageUrl: imageUrl.isEmpty ? nil : imageUrl
        )
        
        Task {
            do {
                let response = try await NetworkManager.shared.addListing(listing)
                
                await MainActor.run {
                    isLoading = false
                    if response.success {
                        generatedContent = response.generatedContent ?? ""
                        alertMessage = "Listing successfully added to posting queue!"
                        clearForm()
                    } else {
                        alertMessage = response.error ?? "Failed to add listing"
                    }
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    alertMessage = "Error: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
    
    private func clearForm() {
        address = ""
        price = ""
        bedrooms = 3
        bathrooms = 2
        sqft = ""
        neighborhood = ""
        city = ""
        features = ""
        imageUrl = ""
    }
}
