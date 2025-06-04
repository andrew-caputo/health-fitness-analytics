import SwiftUI

struct DataSourcePriorityView: View {
    @EnvironmentObject var healthDataManager: HealthDataManager
    @EnvironmentObject var networkManager: NetworkManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var priorities: [HealthCategory: [DataSource]] = [:]
    @State private var isLoading = true
    @State private var hasChanges = false
    @State private var showingSaveAlert = false
    
    enum HealthCategory: String, CaseIterable {
        case activity = "Activity"
        case nutrition = "Nutrition"
        case sleep = "Sleep"
        case body = "Body Composition"
        case heart = "Heart Health"
        case mindfulness = "Mindfulness"
        
        var icon: String {
            switch self {
            case .activity: return "figure.walk"
            case .nutrition: return "fork.knife"
            case .sleep: return "bed.double.fill"
            case .body: return "figure.arms.open"
            case .heart: return "heart.fill"
            case .mindfulness: return "brain.head.profile"
            }
        }
        
        var color: Color {
            switch self {
            case .activity: return .green
            case .nutrition: return .orange
            case .sleep: return .purple
            case .body: return .pink
            case .heart: return .red
            case .mindfulness: return .indigo
            }
        }
        
        var description: String {
            switch self {
            case .activity: return "Steps, workouts, active energy, and exercise data"
            case .nutrition: return "Calories, macronutrients, and dietary information"
            case .sleep: return "Sleep duration, quality, and sleep stage analysis"
            case .body: return "Weight, height, BMI, and body composition metrics"
            case .heart: return "Heart rate, HRV, and cardiovascular health data"
            case .mindfulness: return "Meditation sessions and mindfulness activities"
            }
        }
    }
    
    struct DataSource: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let type: DataSourceType
        let isAvailable: Bool
        let lastSyncDate: Date?
        
        enum DataSourceType: Equatable {
            case healthKit
            case oauth2(String) // OAuth2 with service name
            case fileImport
        }
        
        var icon: String {
            switch type {
            case .healthKit:
                return "heart.fill"
            case .oauth2(let service):
                switch service.lowercased() {
                case "withings": return "scale.3d"
                case "oura": return "circle.fill"
                case "fitbit": return "figure.walk.circle"
                case "whoop": return "waveform.path.ecg"
                case "strava": return "bicycle"
                case "fatsecret": return "fork.knife"
                default: return "link"
                }
            case .fileImport:
                return "doc.fill"
            }
        }
        
        var statusColor: Color {
            guard isAvailable else { return .gray }
            
            guard let lastSync = lastSyncDate else {
                return .orange
            }
            
            let hoursSinceSync = Date().timeIntervalSince(lastSync) / 3600
            if hoursSinceSync < 1 {
                return .green
            } else if hoursSinceSync < 24 {
                return .yellow
            } else {
                return .red
            }
        }
        
        var statusText: String {
            guard isAvailable else { return "Not Connected" }
            
            guard let lastSync = lastSyncDate else {
                return "Never Synced"
            }
            
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: lastSync, relativeTo: Date())
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    loadingView
                } else {
                    priorityContent
                }
            }
            .navigationTitle("Data Source Priority")
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
                        saveChanges()
                    }
                    .disabled(!hasChanges)
                    .fontWeight(hasChanges ? .semibold : .regular)
                }
            }
            .onAppear {
                loadPriorities()
            }
            .alert("Unsaved Changes", isPresented: $showingSaveAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Save") {
                    saveChanges()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You have unsaved changes. Would you like to save them before leaving?")
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading Data Sources...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var priorityContent: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "arrow.up.arrow.down")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text("Data Source Priority")
                                .font(.headline)
                            Text("Set which data sources to prioritize for each health category")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    Text("When multiple sources provide the same type of data, the app will use the source with the highest priority. Drag to reorder sources within each category.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.vertical, 8)
            }
            
            ForEach(HealthCategory.allCases, id: \.self) { category in
                Section {
                    if let sources = priorities[category], !sources.isEmpty {
                        ForEach(sources.indices, id: \.self) { index in
                            DataSourceRow(
                                source: sources[index],
                                priority: index + 1,
                                totalSources: sources.count
                            )
                        }
                        .onMove { from, to in
                            moveSource(in: category, from: from, to: to)
                        }
                    } else {
                        Text("No data sources available for this category")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                } header: {
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(category.color)
                        Text(category.rawValue)
                        Spacer()
                        if let sources = priorities[category] {
                            Text("\(sources.filter { $0.isAvailable }.count) sources")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    Text(category.description)
                        .font(.caption)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .environment(\.editMode, .constant(.active))
    }
    
    private func loadPriorities() {
        Task {
            // Simulate loading from backend/preferences
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            await MainActor.run {
                priorities = createDefaultPriorities()
                isLoading = false
            }
        }
    }
    
    private func createDefaultPriorities() -> [HealthCategory: [DataSource]] {
        let now = Date()
        
        return [
            .activity: [
                DataSource(
                    name: "Apple Watch",
                    type: .healthKit,
                    isAvailable: true,
                    lastSyncDate: now.addingTimeInterval(-300)
                ),
                DataSource(
                    name: "Strava",
                    type: .oauth2("strava"),
                    isAvailable: true,
                    lastSyncDate: now.addingTimeInterval(-1800)
                ),
                DataSource(
                    name: "Fitbit",
                    type: .oauth2("fitbit"),
                    isAvailable: true,
                    lastSyncDate: now.addingTimeInterval(-3600)
                ),
                DataSource(
                    name: "WHOOP",
                    type: .oauth2("whoop"),
                    isAvailable: false,
                    lastSyncDate: nil
                )
            ],
            
            .nutrition: [
                DataSource(
                    name: "MyFitnessPal",
                    type: .healthKit,
                    isAvailable: true,
                    lastSyncDate: now.addingTimeInterval(-7200)
                ),
                DataSource(
                    name: "FatSecret",
                    type: .oauth2("fatsecret"),
                    isAvailable: true,
                    lastSyncDate: now.addingTimeInterval(-1800)
                ),
                DataSource(
                    name: "Cronometer",
                    type: .healthKit,
                    isAvailable: false,
                    lastSyncDate: nil
                ),
                DataSource(
                    name: "CSV Import",
                    type: .fileImport,
                    isAvailable: true,
                    lastSyncDate: now.addingTimeInterval(-86400)
                )
            ],
            
            .sleep: [
                DataSource(
                    name: "Sleep Cycle",
                    type: .healthKit,
                    isAvailable: true,
                    lastSyncDate: now.addingTimeInterval(-28800)
                ),
                DataSource(
                    name: "Apple Watch",
                    type: .healthKit,
                    isAvailable: true,
                    lastSyncDate: now.addingTimeInterval(-300)
                ),
                DataSource(
                    name: "Oura Ring",
                    type: .oauth2("oura"),
                    isAvailable: true,
                    lastSyncDate: now.addingTimeInterval(-3600)
                ),
                DataSource(
                    name: "WHOOP",
                    type: .oauth2("whoop"),
                    isAvailable: false,
                    lastSyncDate: nil
                )
            ],
            
            .body: [
                DataSource(
                    name: "Withings Scale",
                    type: .oauth2("withings"),
                    isAvailable: true,
                    lastSyncDate: now.addingTimeInterval(-86400)
                ),
                DataSource(
                    name: "Apple Health",
                    type: .healthKit,
                    isAvailable: true,
                    lastSyncDate: now.addingTimeInterval(-300)
                ),
                DataSource(
                    name: "Fitbit",
                    type: .oauth2("fitbit"),
                    isAvailable: true,
                    lastSyncDate: now.addingTimeInterval(-3600)
                )
            ],
            
            .heart: [
                DataSource(
                    name: "Apple Watch",
                    type: .healthKit,
                    isAvailable: true,
                    lastSyncDate: now.addingTimeInterval(-300)
                ),
                DataSource(
                    name: "Oura Ring",
                    type: .oauth2("oura"),
                    isAvailable: true,
                    lastSyncDate: now.addingTimeInterval(-3600)
                ),
                DataSource(
                    name: "WHOOP",
                    type: .oauth2("whoop"),
                    isAvailable: false,
                    lastSyncDate: nil
                )
            ],
            
            .mindfulness: [
                DataSource(
                    name: "Headspace",
                    type: .healthKit,
                    isAvailable: true,
                    lastSyncDate: now.addingTimeInterval(-7200)
                ),
                DataSource(
                    name: "Apple Watch",
                    type: .healthKit,
                    isAvailable: true,
                    lastSyncDate: now.addingTimeInterval(-300)
                )
            ]
        ]
    }
    
    private func moveSource(in category: HealthCategory, from: IndexSet, to: Int) {
        guard var sources = priorities[category] else { return }
        
        sources.move(fromOffsets: from, toOffset: to)
        priorities[category] = sources
        hasChanges = true
    }
    
    private func saveChanges() {
        // In a real implementation, this would save to backend/preferences
        Task {
            // Simulate API call
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                hasChanges = false
                dismiss()
            }
        }
    }
}

// MARK: - Data Source Row

struct DataSourceRow: View {
    let source: DataSourcePriorityView.DataSource
    let priority: Int
    let totalSources: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            ZStack {
                Circle()
                    .fill(priorityColor)
                    .frame(width: 24, height: 24)
                
                Text("\(priority)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // Source icon
            Image(systemName: source.icon)
                .foregroundColor(source.statusColor)
                .font(.title3)
                .frame(width: 24)
            
            // Source info
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(source.isAvailable ? .primary : .secondary)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(source.statusColor)
                        .frame(width: 6, height: 6)
                    
                    Text(source.statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Drag indicator
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
        .opacity(source.isAvailable ? 1.0 : 0.6)
    }
    
    private var priorityColor: Color {
        switch priority {
        case 1:
            return .green
        case 2:
            return .blue
        case 3:
            return .orange
        default:
            return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    DataSourcePriorityView()
        .environmentObject(HealthDataManager.shared)
} 