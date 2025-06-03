import SwiftUI
import HealthKit

struct SyncDashboardView: View {
    @StateObject private var viewModel = SyncDashboardViewModel()
    @EnvironmentObject var healthDataManager: HealthDataManager
    @EnvironmentObject var backgroundSyncManager: BackgroundSyncManager
    @EnvironmentObject var networkManager: NetworkManager
    @State private var syncStatus: DashboardSyncStatus = DashboardSyncStatus()
    @State private var syncHistory: [SyncHistoryItem] = []
    @State private var isRefreshing = false
    @State private var showingSyncSettings = false
    @State private var showingConflictResolution = false
    @State private var pendingConflicts: [SyncConflict] = []
    
    // Computed property to bridge the type mismatch
    private var syncConfigurationStatus: Binding<SyncConfiguration.SyncStatus> {
        Binding(
            get: {
                // Convert DashboardSyncStatus to SyncConfiguration.SyncStatus
                if syncStatus.isActive {
                    return .syncing
                } else if syncStatus.overallHealth == .excellent {
                    return .success
                } else {
                    return .idle
                }
            },
            set: { _ in
                // Handle set if needed
            }
        )
    }
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 20) {
                    // Sync Status Overview
                    syncStatusOverview
                    
                    // Real-time Sync Indicators
                    realTimeSyncIndicators
                    
                    // Data Source Sync Status
                    dataSourceSyncStatus
                    
                    // Sync Conflicts
                    if !pendingConflicts.isEmpty {
                        syncConflictsSection
                    }
                    
                    // Sync History
                    syncHistorySection
                    
                    // Sync Controls
                    syncControlsSection
                }
                .padding()
            }
            .navigationTitle("Sync Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshSyncData()
            }
            .navigationBarBackButtonHidden(false)
            .navigationBarItems(trailing: 
                Button(action: {
                    showingSyncSettings = true
                }) {
                    Image(systemName: "gear")
                }
            )
        }
        .onAppear {
            Task {
                await loadSyncData()
            }
        }
        .sheet(isPresented: $showingSyncSettings) {
            SyncSettingsView(syncStatus: syncConfigurationStatus)
        }
        .sheet(isPresented: $showingConflictResolution) {
            SyncConflictResolutionView(conflicts: $pendingConflicts)
        }
    }
    
    private var syncStatusOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: syncStatus.isActive ? "arrow.triangle.2.circlepath" : "pause.circle")
                    .foregroundColor(syncStatus.isActive ? .blue : .orange)
                    .font(.title2)
                    .symbolEffect(.pulse, isActive: syncStatus.isActive)
                
                VStack(alignment: .leading) {
                    Text("Sync Status")
                        .font(.headline)
                    Text(syncStatus.statusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                SyncHealthIndicator(health: syncStatus.overallHealth)
            }
            
            // Sync Progress
            if syncStatus.isActive {
                VStack(spacing: 8) {
                    HStack {
                        Text("Syncing...")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(Int(syncStatus.progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: syncStatus.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
            }
            
            // Sync Statistics
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                SyncStatCard(
                    title: "Last Sync",
                    value: syncStatus.lastSyncTime,
                    icon: "clock",
                    color: .green
                )
                
                SyncStatCard(
                    title: "Data Points",
                    value: "\(syncStatus.totalDataPoints)",
                    icon: "chart.dots.scatter",
                    color: .blue
                )
                
                SyncStatCard(
                    title: "Sources",
                    value: "\(syncStatus.activeSources)",
                    icon: "app.connected.to.app.below.fill",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var realTimeSyncIndicators: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Real-time Sync")
                .font(.headline)
            
            VStack(spacing: 8) {
                RealTimeSyncRow(
                    title: "HealthKit Observer",
                    description: "Monitoring health data changes",
                    isActive: syncStatus.healthKitObserverActive,
                    lastUpdate: syncStatus.lastHealthKitUpdate
                )
                
                RealTimeSyncRow(
                    title: "Background Sync",
                    description: "Automatic sync when app is closed",
                    isActive: syncStatus.backgroundSyncEnabled,
                    lastUpdate: syncStatus.lastBackgroundSync
                )
                
                RealTimeSyncRow(
                    title: "Network Sync",
                    description: "Uploading data to secure servers",
                    isActive: syncStatus.networkSyncActive,
                    lastUpdate: syncStatus.lastNetworkSync
                )
            }
        }
    }
    
    private var dataSourceSyncStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Sources")
                .font(.headline)
            
            ForEach(syncStatus.dataSources) { source in
                DataSourceSyncRow(source: source)
            }
        }
    }
    
    private var syncConflictsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sync Conflicts")
                    .font(.headline)
                
                Spacer()
                
                Button("Resolve All") {
                    showingConflictResolution = true
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            
            ForEach(pendingConflicts.prefix(3)) { conflict in
                SyncConflictRow(conflict: conflict)
            }
            
            if pendingConflicts.count > 3 {
                Button("View All \(pendingConflicts.count) Conflicts") {
                    showingConflictResolution = true
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.top, 4)
            }
        }
    }
    
    private var syncHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sync History")
                    .font(.headline)
                
                Spacer()
                
                Button("View All") {
                    // Show full history
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            ForEach(syncHistory.prefix(5)) { item in
                SyncHistoryRow(item: item)
            }
        }
    }
    
    private var syncControlsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        await performManualSync()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Now")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(syncStatus.canManualSync ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(!syncStatus.canManualSync || syncStatus.isActive)
                
                Button(action: {
                    Task {
                        await resetSyncStatus()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Reset")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            Button(action: {
                showingSyncSettings = true
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Sync Settings")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadSyncData() async {
        await MainActor.run {
            syncStatus = createMockSyncStatus()
            syncHistory = createMockSyncHistory()
            pendingConflicts = createMockConflicts()
        }
    }
    
    private func refreshSyncData() async {
        isRefreshing = true
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await loadSyncData()
        isRefreshing = false
    }
    
    private func performManualSync() async {
        syncStatus.isActive = true
        syncStatus.progress = 0.0
        
        // Simulate sync progress
        for i in 1...20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            await MainActor.run {
                syncStatus.progress = Double(i) / 20.0
            }
        }
        
        await MainActor.run {
            syncStatus.isActive = false
            syncStatus.lastSyncTime = "Just now"
            syncStatus.totalDataPoints += 156
        }
    }
    
    private func resetSyncStatus() async {
        syncStatus.isActive = false
        syncStatus.progress = 0.0
        syncHistory.removeAll()
        pendingConflicts.removeAll()
    }
    
    private func createMockSyncStatus() -> DashboardSyncStatus {
        return DashboardSyncStatus(
            isActive: false,
            progress: 0.0,
            overallHealth: .good,
            statusDescription: "All systems operational",
            lastSyncTime: "2 minutes ago",
            totalDataPoints: 15847,
            activeSources: 6,
            healthKitObserverActive: true,
            backgroundSyncEnabled: true,
            networkSyncActive: true,
            lastHealthKitUpdate: "30 seconds ago",
            lastBackgroundSync: "5 minutes ago",
            lastNetworkSync: "2 minutes ago",
            canManualSync: true,
            dataSources: [
                DataSourceSync(name: "Apple Health", status: .synced, lastSync: "2 min ago", dataPoints: 8934),
                DataSourceSync(name: "MyFitnessPal", status: .syncing, lastSync: "Now", dataPoints: 2156),
                DataSourceSync(name: "Nike Run Club", status: .synced, lastSync: "5 min ago", dataPoints: 1847),
                DataSourceSync(name: "Sleep Cycle", status: .error, lastSync: "1 hour ago", dataPoints: 456),
                DataSourceSync(name: "Apple Watch", status: .synced, lastSync: "1 min ago", dataPoints: 2454)
            ]
        )
    }
    
    private func createMockSyncHistory() -> [SyncHistoryItem] {
        return [
            SyncHistoryItem(timestamp: Date(), type: .manual, status: .success, dataPoints: 156, duration: 12),
            SyncHistoryItem(timestamp: Date().addingTimeInterval(-300), type: .background, status: .success, dataPoints: 89, duration: 8),
            SyncHistoryItem(timestamp: Date().addingTimeInterval(-900), type: .automatic, status: .success, dataPoints: 234, duration: 15),
            SyncHistoryItem(timestamp: Date().addingTimeInterval(-1800), type: .manual, status: .failed, dataPoints: 0, duration: 5),
            SyncHistoryItem(timestamp: Date().addingTimeInterval(-3600), type: .background, status: .success, dataPoints: 178, duration: 11)
        ]
    }
    
    private func createMockConflicts() -> [SyncConflict] {
        return [
            SyncConflict(
                id: UUID(),
                dataType: "Steps",
                source1: "Apple Health",
                source2: "MyFitnessPal",
                value1: "8,456 steps",
                value2: "8,234 steps",
                timestamp: Date().addingTimeInterval(-1800),
                severity: .medium
            ),
            SyncConflict(
                id: UUID(),
                dataType: "Weight",
                source1: "Apple Health",
                source2: "Withings",
                value1: "165.2 lbs",
                value2: "165.8 lbs",
                timestamp: Date().addingTimeInterval(-3600),
                severity: .low
            )
        ]
    }
}

// MARK: - Supporting Views

struct SyncHealthIndicator: View {
    let health: SyncHealth
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(health.color)
                .frame(width: 8, height: 8)
            
            Text(health.displayName)
                .font(.caption)
                .foregroundColor(health.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(health.color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct SyncStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct RealTimeSyncRow: View {
    let title: String
    let description: String
    let isActive: Bool
    let lastUpdate: String
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isActive ? Color.green : Color.gray)
                .frame(width: 12, height: 12)
                .symbolEffect(.pulse, isActive: isActive)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(lastUpdate)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct DataSourceSyncRow: View {
    let source: DataSourceSync
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: source.status.icon)
                .foregroundColor(source.status.color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(source.dataPoints) data points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(source.status.displayName)
                    .font(.caption)
                    .foregroundColor(source.status.color)
                    .fontWeight(.medium)
                
                Text(source.lastSync)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct SyncConflictRow: View {
    let conflict: SyncConflict
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(conflict.severity.color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(conflict.dataType) Conflict")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(conflict.source1): \(conflict.value1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(conflict.source2): \(conflict.value2)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(conflict.timestamp, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct SyncHistoryRow: View {
    let item: SyncHistoryItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.status.icon)
                .foregroundColor(item.status.color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(item.type.displayName) Sync")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(item.dataPoints) data points • \(item.duration)s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(item.timestamp, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Data Models

struct DashboardSyncStatus {
    var isActive: Bool = false
    var progress: Double = 0.0
    var overallHealth: SyncHealth = .good
    var statusDescription: String = "All systems operational"
    var lastSyncTime: String = "Never"
    var totalDataPoints: Int = 0
    var activeSources: Int = 0
    var healthKitObserverActive: Bool = false
    var backgroundSyncEnabled: Bool = false
    var networkSyncActive: Bool = false
    var lastHealthKitUpdate: String = "Never"
    var lastBackgroundSync: String = "Never"
    var lastNetworkSync: String = "Never"
    var canManualSync: Bool = true
    var dataSources: [DataSourceSync] = []
}

enum SyncHealth: String, CaseIterable {
    case excellent = "Excellent"
    case good = "Good"
    case warning = "Warning"
    case error = "Error"
    
    var displayName: String { rawValue }
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct DataSourceSync: Identifiable {
    let id = UUID()
    let name: String
    let status: SyncDataStatus
    let lastSync: String
    let dataPoints: Int
}

enum SyncDataStatus: String, CaseIterable {
    case synced = "Synced"
    case syncing = "Syncing"
    case error = "Error"
    case paused = "Paused"
    
    var displayName: String { rawValue }
    
    var color: Color {
        switch self {
        case .synced: return .green
        case .syncing: return .blue
        case .error: return .red
        case .paused: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .synced: return "checkmark.circle.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        case .error: return "exclamationmark.triangle.fill"
        case .paused: return "pause.circle.fill"
        }
    }
}

struct SyncHistoryItem: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: SyncType
    let status: SyncResultStatus
    let dataPoints: Int
    let duration: Int
}

enum SyncType: String, CaseIterable {
    case manual = "Manual"
    case background = "Background"
    case automatic = "Automatic"
    
    var displayName: String { rawValue }
}

enum SyncResultStatus: String, CaseIterable {
    case success = "Success"
    case failed = "Failed"
    case partial = "Partial"
    
    var displayName: String { rawValue }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .failed: return .red
        case .partial: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .partial: return "exclamationmark.circle.fill"
        }
    }
}

struct SyncConflict: Identifiable {
    let id: UUID
    let dataType: String
    let source1: String
    let source2: String
    let value1: String
    let value2: String
    let timestamp: Date
    let severity: ConflictSeverity
}

enum ConflictSeverity: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var displayName: String { rawValue }
    
    var color: Color {
        switch self {
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        }
    }
}

// MARK: - Preview

struct SyncDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        SyncDashboardView()
            .environmentObject(HealthDataManager())
            .environmentObject(BackgroundSyncManager())
            .environmentObject(NetworkManager.shared)
    }
} 