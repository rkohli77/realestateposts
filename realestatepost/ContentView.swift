// MARK: - Content View

import Foundation
import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            AddListingView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Add Listing")
                }
                .tag(0)
            
            QueueView()
                .tabItem {
                    Image(systemName: "list.dash")
                    Text("Queue")
                }
                .tag(1)
            
            QuickPostView()
                .tabItem {
                    Image(systemName: "square.and.pencil")
                    Text("Quick Post")
                }
                .tag(2)
//            
//            AnalyticsView()
//                .tabItem {
//                    Image(systemName: "chart.bar.fill")
//                    Text("Analytics")
//                }
//                .tag(3)
        }
        .accentColor(.blue)
    }
}
