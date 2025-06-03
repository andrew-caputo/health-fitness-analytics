import Foundation
import SwiftUI

@MainActor
class SyncDashboardViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var dataSources: [DataSourceSync] = []
    
    init() {
        loadSyncStatus()
    }
    
    func loadSyncStatus() {
        // Stub implementation - load sample sync data
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.dataSources = [
                DataSourceSync(name: "Apple Health", status: .synced, lastSync: "3 min ago", dataPoints: 1000),
                DataSourceSync(name: "Withings", status: .syncing, lastSync: "Now", dataPoints: 500),
                DataSourceSync(name: "Oura", status: .error, lastSync: "1 hour ago", dataPoints: 200)
            ]
            self.lastSyncDate = Date().addingTimeInterval(-1800)
            self.syncStatus = .success
            self.isLoading = false
        }
    }
    
    func refreshSyncStatus() {
        loadSyncStatus()
    }
    
    func syncAllSources() {
        syncStatus = .syncing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.syncStatus = .success
            self.lastSyncDate = Date()
        }
    }
}

enum SyncStatus {
    case idle
    case syncing
    case success
    case error(String)
} 