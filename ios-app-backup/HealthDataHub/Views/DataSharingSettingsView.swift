import SwiftUI
import HealthKit

struct DataSharingSettingsView: View {
    @Binding var settings: PrivacySettings
    @Environment(\.dismiss) private var dismiss
    @State private var hasChanges = false
    @State private var showingSaveAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // Overview Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "shield.lefthalf.filled")
                                .foregroundColor(.blue)
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text("Data Sharing Controls")
                                    .font(.headline)
                                Text("Choose what health data to share")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Privacy Level Selector
                        privacyLevelSelector
                    }
                    .padding(.vertical, 8)
                }
                
                // Health Data Types
                Section {
                    ForEach(PrivacySettings.HealthDataType.allCases, id: \.self) { dataType in
                        HealthDataToggleRow(
                            dataType: dataType,
                            isEnabled: Binding(
                                get: { settings.enabledDataTypes.contains(dataType) },
                                set: { isEnabled in
                                    if isEnabled {
                                        settings.enabledDataTypes.insert(dataType)
                                    } else {
                                        settings.enabledDataTypes.remove(dataType)
                                    }
                                    hasChanges = true
                                }
                            )
                        )
                    }
                } header: {
                    Text("Health Data Types")
                } footer: {
                    Text("Select which types of health data you want to share with our secure backend servers. You can change these settings at any time.")
                }
                
                // Sharing Destinations
                Section {
                    SharingDestinationRow(
                        title: "Backend Servers",
                        description: "Secure cloud storage for data sync and backup",
                        isEnabled: $settings.shareWithBackend,
                        icon: "icloud.and.arrow.up",
                        color: .blue
                    )
                    .onChange(of: settings.shareWithBackend) { _ in
                        hasChanges = true
                    }
                    
                    SharingDestinationRow(
                        title: "Anonymous Analytics",
                        description: "Help improve the app with usage patterns",
                        isEnabled: $settings.anonymousAnalytics,
                        icon: "chart.bar",
                        color: .green
                    )
                    .onChange(of: settings.anonymousAnalytics) { _ in
                        hasChanges = true
                    }
                    
                    SharingDestinationRow(
                        title: "Research Studies",
                        description: "Contribute to health research (optional)",
                        isEnabled: $settings.researchParticipation,
                        icon: "flask",
                        color: .purple
                    )
                    .onChange(of: settings.researchParticipation) { _ in
                        hasChanges = true
                    }
                } header: {
                    Text("Sharing Destinations")
                } footer: {
                    Text("Choose where your health data can be shared. All sharing is encrypted and follows strict privacy guidelines.")
                }
                
                // Data Processing Options
                Section {
                    DataProcessingOption(
                        title: "Data Anonymization",
                        description: "Remove personally identifiable information",
                        isRecommended: true,
                        isEnabled: .constant(true)
                    )
                    
                    DataProcessingOption(
                        title: "Aggregation Only",
                        description: "Share only statistical summaries",
                        isRecommended: true,
                        isEnabled: .constant(false)
                    )
                    
                    DataProcessingOption(
                        title: "Real-time Sync",
                        description: "Sync data immediately when available",
                        isRecommended: false,
                        isEnabled: .constant(true)
                    )
                } header: {
                    Text("Data Processing")
                } footer: {
                    Text("These options control how your data is processed before sharing. Recommended settings provide the best balance of functionality and privacy.")
                }
                
                // Quick Actions
                Section {
                    Button(action: {
                        enableAllDataTypes()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                            Text("Enable All Data Types")
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        disableAllDataTypes()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.red)
                            Text("Disable All Data Types")
                            Spacer()
                        }
                    }
                    
                    Button(action: {
                        resetToDefaults()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                            Text("Reset to Defaults")
                            Spacer()
                        }
                    }
                } header: {
                    Text("Quick Actions")
                }
            }
            .navigationTitle("Data Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasChanges {
                            showingSaveAlert = true
                        } else {
                            dismiss()
                        }
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
            .alert("Unsaved Changes", isPresented: $showingSaveAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Save") {
                    saveSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Would you like to save them before leaving?")
            }
        }
    }
    
    private var privacyLevelSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Privacy Level")
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack(spacing: 12) {
                ForEach(PrivacySettings.PrivacyLevel.allCases, id: \.self) { level in
                    Button(action: {
                        settings.privacyLevel = level
                        hasChanges = true
                    }) {
                        VStack(spacing: 4) {
                            Text(level.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(settings.privacyLevel == level ? .white : level.color)
                            
                            Circle()
                                .fill(settings.privacyLevel == level ? level.color : Color(.systemGray5))
                                .frame(width: 12, height: 12)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(settings.privacyLevel == level ? level.color : Color(.systemGray6))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func enableAllDataTypes() {
        settings.enabledDataTypes = Set(PrivacySettings.HealthDataType.allCases)
        hasChanges = true
    }
    
    private func disableAllDataTypes() {
        settings.enabledDataTypes.removeAll()
        hasChanges = true
    }
    
    private func resetToDefaults() {
        settings.enabledDataTypes = [.steps, .heartRate, .sleep, .weight]
        settings.shareWithBackend = true
        settings.anonymousAnalytics = false
        settings.researchParticipation = false
        settings.privacyLevel = .standard
        hasChanges = true
    }
    
    private func saveSettings() {
        // In a real implementation, this would save to backend/preferences
        hasChanges = false
        dismiss()
    }
}

// MARK: - Supporting Views

struct HealthDataToggleRow: View {
    let dataType: PrivacySettings.HealthDataType
    @Binding var isEnabled: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForDataType(dataType))
                .foregroundColor(isEnabled ? colorForDataType(dataType) : .gray)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(dataType.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(descriptionForDataType(dataType))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
    
    private func iconForDataType(_ dataType: PrivacySettings.HealthDataType) -> String {
        switch dataType {
        case .steps: return "figure.walk"
        case .heartRate: return "heart.fill"
        case .sleep: return "bed.double.fill"
        case .weight: return "scalemass.fill"
        case .nutrition: return "fork.knife"
        case .workouts: return "figure.strengthtraining.traditional"
        }
    }
    
    private func colorForDataType(_ dataType: PrivacySettings.HealthDataType) -> Color {
        switch dataType {
        case .steps: return .blue
        case .heartRate: return .red
        case .sleep: return .purple
        case .weight: return .pink
        case .nutrition: return .green
        case .workouts: return .orange
        }
    }
    
    private func descriptionForDataType(_ dataType: PrivacySettings.HealthDataType) -> String {
        switch dataType {
        case .steps: return "Daily step count and walking distance"
        case .heartRate: return "Heart rate measurements and variability"
        case .sleep: return "Sleep duration, quality, and patterns"
        case .weight: return "Body weight and BMI measurements"
        case .nutrition: return "Calorie intake and nutritional information"
        case .workouts: return "Exercise sessions and fitness activities"
        }
    }
}

struct SharingDestinationRow: View {
    let title: String
    let description: String
    @Binding var isEnabled: Bool
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isEnabled ? color : .gray)
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
        .padding(.vertical, 4)
    }
}

struct DataProcessingOption: View {
    let title: String
    let description: String
    let isRecommended: Bool
    @Binding var isEnabled: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isEnabled ? .green : .gray)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if isRecommended {
                        Text("RECOMMENDED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(4)
                    }
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            isEnabled.toggle()
        }
    }
}

// MARK: - Preview

struct DataSharingSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        DataSharingSettingsView(settings: .constant(PrivacySettings()))
    }
} 