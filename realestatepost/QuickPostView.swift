import SwiftUI

// MARK: - Quick Post View
struct QuickPostView: View {
    @State private var postContent = ""
    @State private var imageUrl = ""
    @State private var tipTopic = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedPostType = "manual"
    
    let postTypes = ["manual", "tip"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Post Type") {
                    Picker("Type", selection: $selectedPostType) {
                        Text("Manual Post").tag("manual")
                        Text("Generate Tip").tag("tip")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                if selectedPostType == "manual" {
                    Section("Manual Post") {
                        TextField("Post Content", text: $postContent, axis: .vertical)
                            .lineLimit(5...10)
                        TextField("Image URL (optional)", text: $imageUrl)
                    }
                } else {
                    Section("AI Tip Generator") {
                        TextField("Tip Topic (e.g., 'first-time home buying')", text: $tipTopic)
                        
                        if !postContent.isEmpty {
                            Text("Generated Content:")
                                .font(.headline)
                            Text(postContent)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                
                Button(action: handlePost) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(buttonText)
                    }
                }
                .disabled(isLoading || isButtonDisabled)
                .frame(maxWidth: .infinity)
                .foregroundColor(.white)
                .padding()
                .background(isButtonDisabled ? Color.gray : Color.blue)
                .cornerRadius(8)
            }
            .navigationTitle("Quick Post")
        }
        .alert("Result", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var buttonText: String {
        if isLoading {
            return selectedPostType == "manual" ? "Posting..." : "Generating..."
        }
        return selectedPostType == "manual" ? "Post Now" : "Generate Tip"
    }
    
    private var isButtonDisabled: Bool {
        if selectedPostType == "manual" {
            return postContent.isEmpty
        } else {
            return tipTopic.isEmpty
        }
    }
    
    private func handlePost() {
        if selectedPostType == "manual" {
            postNow()
        } else {
            generateTip()
        }
    }
    
    private func postNow() {
        isLoading = true
        
        Task {
            do {
                let response = try await NetworkManager.shared.postNow(
                    content: postContent,
//                    imageUrl: imageUrl.isEmpty ? nil : imageUrl
                )
                
                await MainActor.run {
                    isLoading = false
                    alertMessage = response.success ? "Posted successfully!" : (response.error ?? "Failed to post")
                    showAlert = true
                    if response.success {
                        postContent = ""
                        imageUrl = ""
                    }
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
    
    private func generateTip() {
        isLoading = true
        
        Task {
            do {
                let response = try await NetworkManager.shared.generateTipPost(topic: tipTopic)
                
                await MainActor.run {
                    isLoading = false
                    
                    if response.success {
                        // Set the generated content to show in the UI
                        postContent = response.generatedContent ?? "Generated tip content"
                        alertMessage = "Tip generated successfully! You can now post it or edit it first."
                    } else {
                        alertMessage = response.error ?? "Failed to generate tip"
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
}
