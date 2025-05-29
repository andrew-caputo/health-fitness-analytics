import SwiftUI

struct SyncDashboardView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var networkManager = NetworkManager.shared
    
    var body: some View {
        List {
            Section("Sync Status") {
                HStack {
                    Image(systemName: syncStatusIcon)
                        .foregroundColor(syncStatusColor)
                    
                    VStack(alignment: .leading) {
                        Text("Current Status")
                            .font(.headline)
                        
                        Text(syncStatusText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if case .syncing = healthKitManager.syncStatus {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                if let lastSync = healthKitManager.lastSyncDate {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Last Sync")
                                .font(.headline)
                            
                            Text(formatDate(lastSync))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section("Sync Actions") {
                Button(action: {
                    Task {
                        await healthKitManager.syncWithBackend()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.blue)
                        
                        Text("Sync Now")
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
                .disabled({
                    if case .syncing = healthKitManager.syncStatus {
                        return true
                    }
                    return false
                }())
                
                NavigationLink("Sync Settings") {
                    Text("Sync Settings - Coming Soon")
                }
                
                NavigationLink("Sync History") {
                    Text("Sync History - Coming Soon")
                }
            }
            
            Section("Data Sources") {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading) {
                        Text("HealthKit")
                            .font(.headline)
                        
                        Text(healthKitManager.isAuthorized ? "Connected" : "Not Connected")
                            .font(.caption)
                            .foregroundColor(healthKitManager.isAuthorized ? .green : .orange)
                    }
                    
                    Spacer()
                    
                    if !healthKitManager.isAuthorized {
                        Button("Connect") {
                            healthKitManager.requestHealthKitPermissions()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .navigationTitle("Sync Dashboard")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var syncStatusIcon: String {
        switch healthKitManager.syncStatus {
        case .idle:
            return "pause.circle"
        case .syncing:
            return "arrow.clockwise.circle"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var syncStatusColor: Color {
        switch healthKitManager.syncStatus {
        case .idle:
            return .gray
        case .syncing:
            return .blue
        case .success:
            return .green
        case .error:
            return .red
        }
    }
    
    private var syncStatusText: String {
        switch healthKitManager.syncStatus {
        case .idle:
            return "Ready to sync"
        case .syncing:
            return "Syncing data..."
        case .success:
            return "Last sync successful"
        case .error(let message):
            return "Sync failed: \(message)"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        SyncDashboardView()
    }
} 