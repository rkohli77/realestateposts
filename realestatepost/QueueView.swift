import SwiftUI

// MARK: - Queue View
struct QueueView: View {
    @State private var queueItems: [QueueItem] = []
    @State private var dailyPostCount = 0
    @State private var remainingPosts = 0
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Stats Header
                HStack {
                    VStack {
                        Text("\(dailyPostCount)")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Posted Today")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Text("\(remainingPosts)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        Text("Remaining")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Text("\(queueItems.filter { $0.status == "pending" }.count)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("In Queue")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding()
                
                // Queue List
                List(queueItems) { item in
                    QueueItemRow(item: item)
                }
                .refreshable {
                    await loadQueue()
                }
            }
            .navigationTitle("Post Queue")
            .toolbar {
                Button("Refresh") {
                    Task { await loadQueue() }
                }
            }
        }
        .task {
            await loadQueue()
        }
    }
    
    private func loadQueue() async {
        do {
            let response = try await NetworkManager.shared.getQueue()
            await MainActor.run {
                self.queueItems = response.queue
                self.dailyPostCount = response.dailyPostCount
                self.remainingPosts = response.remainingPostsToday
            }
        } catch {
            print("Failed to load queue: \(error)")
        }
    }
}

// MARK: - Queue Item Row
struct QueueItemRow: View {
    let item: QueueItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.type.capitalized)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(statusText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(8)
            }
            
            Text(item.content)
                .font(.body)
                .lineLimit(3)
                .foregroundColor(.secondary)
            
            Text("Priority: \(item.priority) • Created: \(formatDate(item.createdAt))")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
    
    private var statusText: String {
        switch item.status {
        case "pending": return "Pending"
        case "posted": return "Posted"
        default: return "Unknown"
        }
    }
    
    private var statusColor: Color {
        switch item.status {
        case "pending": return .orange
        case "posted": return .green
        default: return .gray
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Simple date formatting - you can improve this
        return String(dateString.prefix(10))
    }
}
