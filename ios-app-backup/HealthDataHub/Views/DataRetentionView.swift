import SwiftUI

struct DataRetentionView: View {
    @Binding var settings: PrivacySettings
    @Environment(\.dismiss) private var dismiss
    @State private var hasChanges = false
    @State private var showingDeleteAlert = false
    @State private var selectedRetentionPeriod: RetentionPeriod = .oneYear
    
    enum RetentionPeriod: Int, CaseIterable {
        case oneMonth = 30
        case threeMonths = 90
        case sixMonths = 180
        case oneYear = 365
        case twoYears = 730
        case indefinite = -1
        
        var displayName: String {
            switch self {
            case .oneMonth: return "1 Month"
            case .threeMonths: return "3 Months"
            case .sixMonths: return "6 Months"
            case .oneYear: return "1 Year"
            case .twoYears: return "2 Years"
            case .indefinite: return "Indefinite"
            }
        }
        
        var description: String {
            switch self {
            case .oneMonth: return "Data older than 30 days will be deleted"
            case .threeMonths: return "Data older than 90 days will be deleted"
            case .sixMonths: return "Data older than 180 days will be deleted"
            case .oneYear: return "Data older than 1 year will be deleted"
            case .twoYears: return "Data older than 2 years will be deleted"
            case .indefinite: return "Data will be kept indefinitely"
            }
        }
        
        var isRecommended: Bool {
            return self == .oneYear
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                // Overview Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.orange)
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text("Data Retention")
                                    .font(.headline)
                                Text("Manage how long your data is stored")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Storage Overview
                        storageOverview
                    }
                    .padding(.vertical, 8)
                }
                
                // Local Storage Settings
                Section {
                    HStack {
                        Image(systemName: "iphone")
                            .foregroundColor(.blue)
                            .font(.title3)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
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
                    .padding(.vertical, 4)
                    
                    Text("Health data from HealthKit is stored locally on your device and managed by iOS. This app does not control local data retention.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } header: {
                    Text("Device Storage")
                } footer: {
                    Text("Local data is managed by iOS and HealthKit. You can manage this data through the Health app.")
                }
                
                // Cloud Storage Settings
                Section {
                    // Retention Period Selector
                    ForEach(RetentionPeriod.allCases, id: \.self) { period in
                        RetentionPeriodRow(
                            period: period,
                            isSelected: selectedRetentionPeriod == period,
                            onSelect: {
                                selectedRetentionPeriod = period
                                settings.dataRetentionDays = period.rawValue
                                hasChanges = true
                            }
                        )
                    }
                } header: {
                    Text("Cloud Storage Retention")
                } footer: {
                    Text("Choose how long your health data is stored on our secure servers. Shorter retention periods provide better privacy.")
                }
                
                // Data Categories
                Section {
                    DataCategoryRetention(
                        title: "Activity Data",
                        description: "Steps, workouts, active energy",
                        icon: "figure.walk",
                        color: .blue,
                        retentionDays: settings.dataRetentionDays
                    )
                    
                    DataCategoryRetention(
                        title: "Health Metrics",
                        description: "Heart rate, weight, sleep",
                        icon: "heart.fill",
                        color: .red,
                        retentionDays: settings.dataRetentionDays
                    )
                    
                    DataCategoryRetention(
                        title: "Nutrition Data",
                        description: "Calories, macronutrients",
                        icon: "fork.knife",
                        color: .green,
                        retentionDays: settings.dataRetentionDays
                    )
                } header: {
                    Text("Data Categories")
                } footer: {
                    Text("All data categories follow the same retention policy. Individual category settings may be available in future updates.")
                }
                
                // Data Management Actions
                Section {
                    Button(action: {
                        // Download data
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text("Download My Data")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("Export all cloud data before deletion")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            
                            VStack(alignment: .leading) {
                                Text("Delete All Cloud Data")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                                
                                Text("Permanently remove all data from servers")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                } header: {
                    Text("Data Management")
                }
            }
            .navigationTitle("Data Retention")
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
            .alert("Delete All Data", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAllCloudData()
                }
            } message: {
                Text("This will permanently delete all your health data from our servers. This action cannot be undone. Local data on your device will not be affected.")
            }
        }
        .onAppear {
            selectedRetentionPeriod = RetentionPeriod(rawValue: settings.dataRetentionDays) ?? .oneYear
        }
    }
    
    private var storageOverview: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Storage Overview")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                StorageIndicator(
                    title: "Local",
                    amount: "2.3 GB",
                    color: .blue,
                    icon: "iphone"
                )
                
                StorageIndicator(
                    title: "Cloud",
                    amount: "156 MB",
                    color: .orange,
                    icon: "icloud"
                )
                
                StorageIndicator(
                    title: "Backup",
                    amount: "89 MB",
                    color: .green,
                    icon: "externaldrive"
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveSettings() {
        // In a real implementation, this would save to backend/preferences
        hasChanges = false
        dismiss()
    }
    
    private func deleteAllCloudData() {
        // In a real implementation, this would delete all cloud data
        // Show confirmation and progress
    }
}

// MARK: - Supporting Views

struct RetentionPeriodRow: View {
    let period: DataRetentionView.RetentionPeriod
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(period.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if period.isRecommended {
                            Text("RECOMMENDED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(period.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DataCategoryRetention: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let retentionDays: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(retentionText)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
    
    private var retentionText: String {
        if retentionDays == -1 {
            return "Indefinite"
        } else if retentionDays >= 365 {
            let years = retentionDays / 365
            return "\(years) year\(years > 1 ? "s" : "")"
        } else if retentionDays >= 30 {
            let months = retentionDays / 30
            return "\(months) month\(months > 1 ? "s" : "")"
        } else {
            return "\(retentionDays) days"
        }
    }
}

struct StorageIndicator: View {
    let title: String
    let amount: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(amount)
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

// MARK: - Preview

struct DataRetentionView_Previews: PreviewProvider {
    static var previews: some View {
        DataRetentionView(settings: .constant(PrivacySettings()))
    }
} 