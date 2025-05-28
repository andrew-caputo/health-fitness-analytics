import SwiftUI
import HealthKit

struct ConnectedAppsDetailView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var networkManager: NetworkManager
    @State private var selectedCategory: HealthCategory = .all
    @State private var showPermissionsSheet = false
    @State private var selectedApp: ConnectedHealthApp?
    @State private var refreshing = false
    
    enum HealthCategory: String, CaseIterable {
        case all = "All"
        case activity = "Activity"
        case nutrition = "Nutrition"
        case sleep = "Sleep"
        case body = "Body"
        case heart = "Heart"
        case mindfulness = "Mindfulness"
        
        var icon: String {
            switch self {
            case .all: return "apps.iphone"
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
            case .all: return .blue
            case .activity: return .green
            case .nutrition: return .orange
            case .sleep: return .purple
            case .body: return .pink
            case .heart: return .red
            case .mindfulness: return .indigo
            }
        }
    }
    
    var filteredApps: [ConnectedHealthApp] {
        let apps = healthKitManager.detailedConnectedApps
        if selectedCategory == .all {
            return apps
        }
        return apps.filter { app in
            app.categories.contains(selectedCategory.rawValue.lowercased())
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category Filter
                categoryFilterView
                
                // Apps List
                if filteredApps.isEmpty {
                    emptyStateView
                } else {
                    appsList
                }
            }
            .navigationTitle("Connected Apps")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Permissions") {
                        showPermissionsSheet = true
                    }
                }
            }
            .refreshable {
                await refreshApps()
            }
            .sheet(isPresented: $showPermissionsSheet) {
                AppPermissionsView()
            }
            .sheet(item: $selectedApp) { app in
                AppDetailSheet(app: app)
            }
        }
    }
    
    private var categoryFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(HealthCategory.allCases, id: \.self) { category in
                    CategoryFilterChip(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var appsList: some View {
        List {
            Section {
                ForEach(filteredApps) { app in
                    ConnectedAppRow(app: app) {
                        selectedApp = app
                    }
                }
            } header: {
                HStack {
                    Text("\(filteredApps.count) Connected Apps")
                    Spacer()
                    if refreshing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            } footer: {
                Text("These apps are sharing health data through HealthKit. Tap an app to see detailed information and manage its data.")
                    .font(.caption)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "apps.iphone")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Connected Apps")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Install health apps and grant them permission to write to HealthKit to see them here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Open Health App") {
                healthKitManager.openHealthApp()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private func refreshApps() async {
        refreshing = true
        healthKitManager.updateDetailedConnectedApps()
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay for UX
        refreshing = false
    }
}

// MARK: - Category Filter Chip

struct CategoryFilterChip: View {
    let category: ConnectedAppsDetailView.HealthCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                
                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? category.color : Color(.systemGray5))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Connected App Row

struct ConnectedAppRow: View {
    let app: ConnectedHealthApp
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // App Icon
                AsyncImage(url: URL(string: app.iconURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Image(systemName: "app.fill")
                        .foregroundColor(.blue)
                }
                .frame(width: 40, height: 40)
                .cornerRadius(8)
                
                // App Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(app.categoriesText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        // Data freshness indicator
                        Circle()
                            .fill(app.dataFreshnessColor)
                            .frame(width: 8, height: 8)
                        
                        Text(app.lastSyncText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(app.dataPointsCount) data points")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Status indicator
                VStack(spacing: 4) {
                    Image(systemName: app.isActive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(app.isActive ? .green : .orange)
                        .font(.title3)
                    
                    Text(app.isActive ? "Active" : "Inactive")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - App Detail Sheet

struct AppDetailSheet: View {
    let app: ConnectedHealthApp
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App Header
                    appHeaderView
                    
                    // Data Categories
                    dataCategoriesView
                    
                    // Recent Data
                    recentDataView
                    
                    // Privacy & Permissions
                    privacyPermissionsView
                }
                .padding()
            }
            .navigationTitle(app.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var appHeaderView: some View {
        VStack(spacing: 16) {
            AsyncImage(url: URL(string: app.iconURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "app.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 40))
            }
            .frame(width: 80, height: 80)
            .cornerRadius(16)
            
            VStack(spacing: 8) {
                Text(app.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(app.description ?? "Health app connected through HealthKit")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: 16) {
                    VStack {
                        Text("\(app.dataPointsCount)")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Data Points")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text(app.lastSyncText)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Last Sync")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Circle()
                            .fill(app.dataFreshnessColor)
                            .frame(width: 12, height: 12)
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var dataCategoriesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Categories")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(app.categories, id: \.self) { category in
                    HStack {
                        Image(systemName: iconForCategory(category))
                            .foregroundColor(colorForCategory(category))
                        Text(category.capitalized)
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var recentDataView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Data")
                .font(.headline)
            
            if app.recentDataPoints.isEmpty {
                Text("No recent data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                ForEach(app.recentDataPoints.prefix(5), id: \.id) { dataPoint in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(dataPoint.type)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(dataPoint.timestamp)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(dataPoint.value)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var privacyPermissionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Privacy & Permissions")
                .font(.headline)
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.blue)
                    Text("Data is shared through HealthKit")
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "eye.slash.fill")
                        .foregroundColor(.green)
                    Text("No direct access to your data")
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "gear")
                        .foregroundColor(.gray)
                    Text("Manage in Health app")
                    Spacer()
                    Button("Open") {
                        // Open Health app
                        if let url = URL(string: "x-apple-health://") {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption)
                }
            }
            .font(.subheadline)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "activity": return "figure.walk"
        case "nutrition": return "fork.knife"
        case "sleep": return "bed.double.fill"
        case "body": return "figure.arms.open"
        case "heart": return "heart.fill"
        case "mindfulness": return "brain.head.profile"
        default: return "app.fill"
        }
    }
    
    private func colorForCategory(_ category: String) -> Color {
        switch category.lowercased() {
        case "activity": return .green
        case "nutrition": return .orange
        case "sleep": return .purple
        case "body": return .pink
        case "heart": return .red
        case "mindfulness": return .indigo
        default: return .blue
        }
    }
}

// MARK: - Connected Health App Model

struct ConnectedHealthApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let iconURL: String?
    let description: String?
    let categories: [String]
    let isActive: Bool
    let lastSyncDate: Date?
    let dataPointsCount: Int
    let recentDataPoints: [DataPoint]
    
    var categoriesText: String {
        categories.map { $0.capitalized }.joined(separator: ", ")
    }
    
    var lastSyncText: String {
        guard let lastSyncDate = lastSyncDate else {
            return "Never"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastSyncDate, relativeTo: Date())
    }
    
    var dataFreshnessColor: Color {
        guard let lastSyncDate = lastSyncDate else {
            return .gray
        }
        
        let hoursSinceSync = Date().timeIntervalSince(lastSyncDate) / 3600
        
        if hoursSinceSync < 1 {
            return .green
        } else if hoursSinceSync < 24 {
            return .yellow
        } else {
            return .red
        }
    }
    
    struct DataPoint: Identifiable {
        let id = UUID()
        let type: String
        let value: String
        let timestamp: String
    }
}

// MARK: - Preview

struct ConnectedAppsDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectedAppsDetailView()
            .environmentObject(HealthKitManager())
            .environmentObject(NetworkManager.shared)
    }
} 