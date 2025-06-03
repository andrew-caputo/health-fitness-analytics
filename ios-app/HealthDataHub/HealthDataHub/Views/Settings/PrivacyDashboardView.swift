import SwiftUI
import HealthKit

struct PrivacyDashboardView: View {
    @StateObject private var viewModel = PrivacyDashboardViewModel()
    @EnvironmentObject var healthDataManager: HealthDataManager
    @EnvironmentObject var networkManager: NetworkManager
    @State private var privacySettings: PrivacySettings = PrivacySettings()
    @State private var auditLogs: [PrivacyAuditLog] = []
    @State private var isLoading = true
    @State private var showingDataSharingSheet = false
    @State private var showingRetentionSheet = false
    @State private var showingExportSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Privacy Overview
                    privacyOverview
                    
                    // Data Sharing Controls
                    dataSharingControls
                    
                    // Data Retention Settings
                    dataRetentionSettings
                    
                    // Privacy Audit Log
                    privacyAuditLog
                    
                    // Data Export & Management
                    dataExportManagement
                }
                .padding()
            }
            .navigationTitle("Privacy & Data")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadPrivacyData()
            }
        }
        .onAppear {
            Task {
                await loadPrivacyData()
            }
        }
        .sheet(isPresented: $showingDataSharingSheet) {
            DataSharingSettingsView(settings: $privacySettings)
        }
        .sheet(isPresented: $showingRetentionSheet) {
            DataRetentionView(settings: $privacySettings)
        }
        .sheet(isPresented: $showingExportSheet) {
            DataExportView()
        }
    }
    
    private var privacyOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text("Privacy Overview")
                    .font(.headline)
                
                Spacer()
                
                PrivacyScoreIndicator(score: privacySettings.privacyScore)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                PrivacyStatCard(
                    title: "Data Types",
                    value: "\(privacySettings.enabledDataTypes.count)",
                    subtitle: "Shared",
                    color: .blue,
                    icon: "doc.text"
                )
                
                PrivacyStatCard(
                    title: "Retention",
                    value: "\(privacySettings.dataRetentionDays)",
                    subtitle: "Days",
                    color: .orange,
                    icon: "clock"
                )
                
                PrivacyStatCard(
                    title: "Access Log",
                    value: "\(auditLogs.count)",
                    subtitle: "Entries",
                    color: .green,
                    icon: "list.bullet"
                )
            }
            
            // Privacy Level Indicator
            HStack {
                Text("Privacy Level:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(privacySettings.privacyLevel.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(privacySettings.privacyLevel.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(privacySettings.privacyLevel.color.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var dataSharingControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Sharing")
                .font(.headline)
            
            VStack(spacing: 12) {
                DataSharingToggle(
                    title: "Share with Backend",
                    description: "Allow syncing health data to our secure servers",
                    isEnabled: $privacySettings.shareWithBackend,
                    icon: "icloud.and.arrow.up"
                )
                
                DataSharingToggle(
                    title: "Anonymous Analytics",
                    description: "Help improve the app with anonymous usage data",
                    isEnabled: $privacySettings.anonymousAnalytics,
                    icon: "chart.bar"
                )
                
                DataSharingToggle(
                    title: "Research Participation",
                    description: "Contribute to health research studies (optional)",
                    isEnabled: $privacySettings.researchParticipation,
                    icon: "flask"
                )
            }
            
            Button(action: {
                showingDataSharingSheet = true
            }) {
                HStack {
                    Text("Advanced Sharing Settings")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var dataRetentionSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Retention")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Local Storage")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Data stored on this device")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("Unlimited")
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Cloud Storage")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Data synced to our servers")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(privacySettings.dataRetentionDays) days")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            Button(action: {
                showingRetentionSheet = true
            }) {
                HStack {
                    Text("Manage Retention Settings")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var privacyAuditLog: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Privacy Audit Log")
                    .font(.headline)
                
                Spacer()
                
                Button("View All") {
                    // Show full audit log
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if auditLogs.isEmpty {
                Text("No recent activity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                ForEach(auditLogs.prefix(3)) { log in
                    AuditLogRow(log: log)
                }
            }
        }
    }
    
    private var dataExportManagement: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Management")
                .font(.headline)
            
            VStack(spacing: 8) {
                Button(action: {
                    showingExportSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Export Your Data")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Download all your health data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    // Clear local data
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading) {
                            Text("Clear Local Data")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Remove data stored on this device")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    // Delete account
                }) {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.minus")
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading) {
                            Text("Delete Account")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                            
                            Text("Permanently delete your account and all data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadPrivacyData() async {
        isLoading = true
        
        // Simulate loading privacy data
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            privacySettings = createMockPrivacySettings()
            auditLogs = createMockAuditLogs()
            isLoading = false
        }
    }
    
    private func createMockPrivacySettings() -> PrivacySettings {
        return PrivacySettings(
            shareWithBackend: true,
            anonymousAnalytics: false,
            researchParticipation: false,
            privacyLevel: .standard,
            dataRetentionDays: 365,
            enabledDataTypes: [.steps, .heartRate, .sleep, .weight]
        )
    }
    
    private func createMockAuditLogs() -> [PrivacyAuditLog] {
        return [
            PrivacyAuditLog(
                action: "Data Sync",
                description: "Health data synced to backend",
                timestamp: Date(),
                dataTypes: ["Steps", "Heart Rate"]
            ),
            PrivacyAuditLog(
                action: "Permission Change",
                description: "Enabled sleep data sharing",
                timestamp: Date().addingTimeInterval(-3600),
                dataTypes: ["Sleep"]
            ),
            PrivacyAuditLog(
                action: "Data Export",
                description: "Exported health data to JSON",
                timestamp: Date().addingTimeInterval(-86400),
                dataTypes: ["All Data"]
            )
        ]
    }
}

// MARK: - Supporting Views

struct PrivacyScoreIndicator: View {
    let score: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(score)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(scoreColor)
            
            Text("Privacy Score")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(scoreColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var scoreColor: Color {
        switch score {
        case 80...100: return .green
        case 60...79: return .orange
        default: return .red
        }
    }
}

struct PrivacyStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            VStack(spacing: 2) {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct DataSharingToggle: View {
    let title: String
    let description: String
    @Binding var isEnabled: Bool
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isEnabled ? .blue : .gray)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct AuditLogRow: View {
    let log: PrivacyAuditLog
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: log.icon)
                .foregroundColor(log.actionColor)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(log.action)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(log.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(log.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                ForEach(log.dataTypes.prefix(2), id: \.self) { dataType in
                    Text(dataType)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Data Models

struct PrivacySettings {
    var shareWithBackend: Bool = true
    var anonymousAnalytics: Bool = false
    var researchParticipation: Bool = false
    var privacyLevel: PrivacyLevel = .standard
    var dataRetentionDays: Int = 365
    var enabledDataTypes: Set<HealthDataType> = []
    
    var privacyScore: Int {
        var score = 100
        if shareWithBackend { score -= 10 }
        if anonymousAnalytics { score -= 5 }
        if researchParticipation { score -= 15 }
        if dataRetentionDays > 365 { score -= 10 }
        return max(0, score)
    }
    
    enum PrivacyLevel: String, CaseIterable {
        case minimal = "Minimal"
        case standard = "Standard"
        case detailed = "Detailed"
        
        var displayName: String { rawValue }
        
        var color: Color {
            switch self {
            case .minimal: return .green
            case .standard: return .blue
            case .detailed: return .orange
            }
        }
    }
    
    enum HealthDataType: String, CaseIterable {
        case steps = "Steps"
        case heartRate = "Heart Rate"
        case sleep = "Sleep"
        case weight = "Weight"
        case nutrition = "Nutrition"
        case workouts = "Workouts"
    }
}

struct PrivacyAuditLog: Identifiable {
    let id = UUID()
    let action: String
    let description: String
    let timestamp: Date
    let dataTypes: [String]
    
    var icon: String {
        switch action {
        case "Data Sync": return "icloud.and.arrow.up"
        case "Permission Change": return "gear"
        case "Data Export": return "square.and.arrow.up"
        case "Data Access": return "eye"
        default: return "doc"
        }
    }
    
    var actionColor: Color {
        switch action {
        case "Data Sync": return .blue
        case "Permission Change": return .orange
        case "Data Export": return .green
        case "Data Access": return .purple
        default: return .gray
        }
    }
}

// MARK: - Preview

struct PrivacyDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyDashboardView()
            .environmentObject(HealthDataManager())
            .environmentObject(NetworkManager.shared)
    }
} 