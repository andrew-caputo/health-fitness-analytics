import SwiftUI

struct SyncSettingsView: View {
    @Binding var syncStatus: SyncConfiguration.SyncStatus
    @Environment(\.dismiss) private var dismiss
    @State private var syncSettings = SyncSettings()
    @State private var hasChanges = false
    
    var body: some View {
        NavigationView {
            List {
                // Sync Preferences
                Section {
                    Toggle("Automatic Sync", isOn: $syncSettings.automaticSyncEnabled)
                        .onChange(of: syncSettings.automaticSyncEnabled) { _ in
                            hasChanges = true
                        }
                    
                    Toggle("Background Sync", isOn: $syncSettings.backgroundSyncEnabled)
                        .onChange(of: syncSettings.backgroundSyncEnabled) { _ in
                            hasChanges = true
                        }
                    
                    Toggle("WiFi Only", isOn: $syncSettings.wifiOnlySync)
                        .onChange(of: syncSettings.wifiOnlySync) { _ in
                            hasChanges = true
                        }
                } header: {
                    Text("Sync Preferences")
                } footer: {
                    Text("Automatic sync keeps your data up to date. Background sync works when the app is closed. WiFi only saves cellular data.")
                }
                
                // Sync Frequency
                Section {
                    Picker("Sync Frequency", selection: $syncSettings.syncFrequency) {
                        ForEach(SyncFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    .onChange(of: syncSettings.syncFrequency) { _ in
                        hasChanges = true
                    }
                    
                    if syncSettings.syncFrequency == .custom {
                        Stepper("Every \(syncSettings.customIntervalMinutes) minutes", 
                               value: $syncSettings.customIntervalMinutes, 
                               in: 5...120, 
                               step: 5)
                        .onChange(of: syncSettings.customIntervalMinutes) { _ in
                            hasChanges = true
                        }
                    }
                } header: {
                    Text("Sync Frequency")
                } footer: {
                    Text("More frequent syncing provides real-time data but may impact battery life.")
                }
                
                // Data Source Priorities
                Section {
                    ForEach(syncSettings.dataSourcePriorities.indices, id: \.self) { index in
                        DataSourcePriorityRow(
                            priority: $syncSettings.dataSourcePriorities[index],
                            onMove: { from, to in
                                syncSettings.dataSourcePriorities.move(fromOffsets: IndexSet([from]), toOffset: to)
                                hasChanges = true
                            }
                        )
                    }
                    .onMove { from, to in
                        syncSettings.dataSourcePriorities.move(fromOffsets: from, toOffset: to)
                        hasChanges = true
                    }
                } header: {
                    Text("Data Source Priority")
                } footer: {
                    Text("Higher priority sources are preferred when resolving data conflicts. Drag to reorder.")
                }
                
                // Conflict Resolution
                Section {
                    Picker("Default Resolution", selection: $syncSettings.defaultConflictResolution) {
                        ForEach(DefaultConflictResolution.allCases, id: \.self) { resolution in
                            Text(resolution.displayName).tag(resolution)
                        }
                    }
                    .onChange(of: syncSettings.defaultConflictResolution) { _ in
                        hasChanges = true
                    }
                    
                    Toggle("Auto-resolve Minor Conflicts", isOn: $syncSettings.autoResolveMinorConflicts)
                        .onChange(of: syncSettings.autoResolveMinorConflicts) { _ in
                            hasChanges = true
                        }
                } header: {
                    Text("Conflict Resolution")
                } footer: {
                    Text("Choose how to handle data conflicts between sources. Auto-resolve applies to conflicts with less than 5% difference.")
                }
                
                // Advanced Settings
                Section {
                    Toggle("Detailed Sync Logs", isOn: $syncSettings.detailedLogging)
                        .onChange(of: syncSettings.detailedLogging) { _ in
                            hasChanges = true
                        }
                    
                    Stepper("Retry Attempts: \(syncSettings.maxRetryAttempts)", 
                           value: $syncSettings.maxRetryAttempts, 
                           in: 1...5)
                    .onChange(of: syncSettings.maxRetryAttempts) { _ in
                        hasChanges = true
                    }
                    
                    Picker("Batch Size", selection: $syncSettings.batchSize) {
                        ForEach([50, 100, 200, 500], id: \.self) { size in
                            Text("\(size) records").tag(size)
                        }
                    }
                    .onChange(of: syncSettings.batchSize) { _ in
                        hasChanges = true
                    }
                } header: {
                    Text("Advanced Settings")
                } footer: {
                    Text("These settings affect sync performance and debugging. Only change if you experience sync issues.")
                }
                
                // Reset Section
                Section {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(.orange)
                    
                    Button("Clear Sync Cache") {
                        clearSyncCache()
                    }
                    .foregroundColor(.red)
                } header: {
                    Text("Reset Options")
                }
            }
            .navigationTitle("Sync Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                    .disabled(!hasChanges)
                    .fontWeight(hasChanges ? .semibold : .regular)
                }
            }
        }
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentSettings() {
        // Load current sync settings
        syncSettings = SyncSettings()
        syncSettings.dataSourcePriorities = mockDataSources
    }
    
    private func saveSettings() {
        // Save settings to UserDefaults or backend
        hasChanges = false
        dismiss()
    }
    
    private func resetToDefaults() {
        syncSettings = SyncSettings()
        hasChanges = true
    }
    
    private func clearSyncCache() {
        // Clear sync cache and reset sync status
    }
    
    private func loadMockData() {
        // Mock data for testing purposes
        syncSettings.automaticSyncEnabled = true
        syncSettings.backgroundSyncEnabled = true
        syncSettings.wifiOnlySync = true
        syncSettings.syncFrequency = .realTime
        syncSettings.dataSourcePriorities = mockDataSources
        
        syncStatus = .success
    }
    
    private let mockDataSources: [DataSourcePriority] = [
        DataSourcePriority(sourceName: "Apple Health", dataType: "health_data", priority: 1, isEnabled: true, conflictResolution: .useFirst),
        DataSourcePriority(sourceName: "MyFitnessPal", dataType: "nutrition", priority: 2, isEnabled: true, conflictResolution: .useFirst),
        DataSourcePriority(sourceName: "Nike Run Club", dataType: "activity", priority: 3, isEnabled: true, conflictResolution: .merge),
        DataSourcePriority(sourceName: "Sleep Cycle", dataType: "sleep", priority: 4, isEnabled: true, conflictResolution: .useFirst),
    ]
}

// MARK: - Supporting Views

struct DataSourcePriorityRow: View {
    @Binding var priority: DataSourcePriority
    let onMove: (Int, Int) -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "app.fill")
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(priority.sourceName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(priority.dataType)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: .constant(priority.isEnabled))
                .labelsHidden()
                .disabled(true)
        }
    }
}

// MARK: - Data Models

struct SyncSettings {
    var automaticSyncEnabled: Bool = true
    var backgroundSyncEnabled: Bool = true
    var wifiOnlySync: Bool = false
    var syncFrequency: SyncFrequency = .every15Minutes
    var customIntervalMinutes: Int = 15
    var defaultConflictResolution: DefaultConflictResolution = .useLatest
    var autoResolveMinorConflicts: Bool = true
    var detailedLogging: Bool = false
    var maxRetryAttempts: Int = 3
    var batchSize: Int = 100
    var dataSourcePriorities: [DataSourcePriority] = []
}

enum SyncFrequency: String, CaseIterable {
    case realTime = "Real-time"
    case every5Minutes = "Every 5 minutes"
    case every15Minutes = "Every 15 minutes"
    case every30Minutes = "Every 30 minutes"
    case hourly = "Hourly"
    case custom = "Custom"
    
    var displayName: String { rawValue }
}

enum DefaultConflictResolution: String, CaseIterable {
    case useLatest = "Use Latest"
    case usePriority = "Use Priority Source"
    case useAverage = "Use Average"
    case askUser = "Ask User"
    
    var displayName: String { rawValue }
}

// MARK: - Notification Settings

struct NotificationSettings {
    var insightsEnabled: Bool = true
    var goalsEnabled: Bool = true
    var alertsEnabled: Bool = true
    var syncEnabled: Bool = true
    var quietHoursEnabled: Bool = false
    var quietStartTime: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var quietEndTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date()
    var priorityFilter: NotificationPriority = .medium
}

enum NotificationPriority: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

// MARK: - Notification Settings View

struct NotificationSettingsView: View {
    @Binding var settings: NotificationSettings
    @Environment(\.dismiss) private var dismiss
    @State private var hasChanges = false
    
    var body: some View {
        NavigationView {
            List {
                // Notification Types
                Section {
                    Toggle("Health Insights", isOn: $settings.insightsEnabled)
                        .onChange(of: settings.insightsEnabled) { _ in hasChanges = true }
                    
                    Toggle("Goal Achievements", isOn: $settings.goalsEnabled)
                        .onChange(of: settings.goalsEnabled) { _ in hasChanges = true }
                    
                    Toggle("Health Alerts", isOn: $settings.alertsEnabled)
                        .onChange(of: settings.alertsEnabled) { _ in hasChanges = true }
                    
                    Toggle("Sync Updates", isOn: $settings.syncEnabled)
                        .onChange(of: settings.syncEnabled) { _ in hasChanges = true }
                } header: {
                    Text("Notification Types")
                } footer: {
                    Text("Choose which types of notifications you want to receive.")
                }
                
                // Quiet Hours
                Section {
                    Toggle("Enable Quiet Hours", isOn: $settings.quietHoursEnabled)
                        .onChange(of: settings.quietHoursEnabled) { _ in hasChanges = true }
                    
                    if settings.quietHoursEnabled {
                        DatePicker("Start Time", selection: $settings.quietStartTime, displayedComponents: .hourAndMinute)
                            .onChange(of: settings.quietStartTime) { _ in hasChanges = true }
                        
                        DatePicker("End Time", selection: $settings.quietEndTime, displayedComponents: .hourAndMinute)
                            .onChange(of: settings.quietEndTime) { _ in hasChanges = true }
                    }
                } header: {
                    Text("Quiet Hours")
                } footer: {
                    Text("No notifications will be sent during quiet hours except for high-priority health alerts.")
                }
                
                // Priority Filter
                Section {
                    Picker("Minimum Priority", selection: $settings.priorityFilter) {
                        ForEach(NotificationPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                    .onChange(of: settings.priorityFilter) { _ in hasChanges = true }
                } header: {
                    Text("Priority Filter")
                } footer: {
                    Text("Only show notifications at or above the selected priority level.")
                }
            }
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                    .disabled(!hasChanges)
                    .fontWeight(hasChanges ? .semibold : .regular)
                }
            }
        }
    }
    
    private func saveSettings() {
        // Save notification settings
        hasChanges = false
        dismiss()
    }
}

// MARK: - Preview

struct SyncSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SyncSettingsView(syncStatus: .constant(.idle))
    }
} 