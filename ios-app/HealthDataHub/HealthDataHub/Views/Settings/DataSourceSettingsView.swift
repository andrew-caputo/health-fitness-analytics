import SwiftUI

struct DataSourceSettingsView: View {
    @StateObject private var viewModel = DataSourceSettingsViewModel()
    @State private var showingCategoryDetail: HealthCategory?
    
    var body: some View {
        List {
            // Overview Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "apps.iphone")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Data Source Preferences")
                                .font(.headline)
                            
                            Text("Choose which apps provide your health data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    if viewModel.isLoading {
                        ProgressView("Loading preferences...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
            }
            
            // Data Source Preferences
            Section("Your Preferences") {
                ForEach(HealthCategory.allCases, id: \.self) { category in
                    NavigationLink(destination: CategorySourceDetailView(category: category)) {
                        HStack {
                            CategoryIcon(category: category)
                                .frame(width: 30, height: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.displayName)
                                    .font(.body)
                                
                                Text(viewModel.currentSourceName(for: category) ?? "Not set")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if viewModel.isConnected(category: category) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else if viewModel.currentSourceName(for: category) != nil {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            
            // Available Sources
            Section("All Available Sources") {
                ForEach(viewModel.availableSources, id: \.source_name) { source in
                    AvailableDataSourceRow(source: source)
                }
            }
            
            // Reset Options
            Section {
                Button("Reset All Preferences") {
                    Task {
                        await viewModel.resetAllPreferences()
                    }
                }
                .foregroundColor(.red)
                .disabled(viewModel.isLoading)
            } footer: {
                Text("This will remove all your data source preferences. You can set them up again anytime.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Data Sources")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadData()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.error ?? "An error occurred")
        }
    }
}

// MARK: - Supporting Views

struct AvailableDataSourceRow: View {
    let source: PreferenceDataSource
    
    var body: some View {
        HStack(spacing: 12) {
            if source.isSFSymbol {
                Image(systemName: source.iconName)
                    .font(.title3)
                    .foregroundColor(source.brandColor)
                    .frame(width: 30)
            } else {
                Image(source.iconName) // Custom asset
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30) // Adjust size as needed
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(source.display_name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(source.integrationTypeDisplayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if source.is_active {
                    Text("Available")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Inactive")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Show supported categories count
                let supportedCount = source.supportedCategoriesCount
                Text("\(supportedCount) categories")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct CategorySourceDetailView: View {
    let category: HealthCategory
    @StateObject private var viewModel = DataSourceSettingsViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            // Category Info
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        CategoryIcon(category: category)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.displayName)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Choose your preferred data source")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Available Sources for Category
            Section("Available Sources") {
                let availableSources = viewModel.availableSources.filter { $0.supports(category: category) }
                
                if availableSources.isEmpty {
                    Text("No sources available for this category")
                        .foregroundColor(.secondary)
                        .font(.body)
                        .padding()
                } else {
                    ForEach(availableSources, id: \.source_name) { source in
                        Button(action: {
                            Task {
                                await viewModel.changeSource(for: category, to: source.source_name)
                            }
                        }) {
                            HStack {
                                if source.isSFSymbol {
                                    Image(systemName: source.iconName)
                                        .font(.title3)
                                        .foregroundColor(source.brandColor)
                                        .frame(width: 30)
                                } else {
                                    Image(source.iconName) // Custom asset
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 30, height: 30) // Adjust size as needed
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(source.display_name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Text(source.integrationTypeDisplayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if viewModel.currentPreferences.preferredSource(for: category) == source.source_name {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(viewModel.isLoading)
                    }
                }
            }
            
            // Clear Selection
            if viewModel.currentPreferences.preferredSource(for: category) != nil {
                Section {
                    Button("Clear Selection") {
                        Task {
                            await viewModel.clearCategoryPreference(category)
                        }
                    }
                    .foregroundColor(.red)
                    .disabled(viewModel.isLoading)
                }
            }
        }
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadData()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.error ?? "An error occurred")
        }
    }
}

// MARK: - Extensions

extension HealthCategory {
    var color: Color {
        switch self {
        case .activity: return .blue
        case .bodyComposition: return .purple
        case .nutrition: return .green
        case .sleep: return .indigo
        case .heartHealth: return .red
        case .workouts: return .orange
        }
    }
}

extension PreferenceDataSource {
    var supportedCategoriesCount: Int {
        var count = 0
        if supports_activity { count += 1 }
        if supports_sleep { count += 1 }
        if supports_nutrition { count += 1 }
        if supports_body_composition { count += 1 }
        if supports_heart_health { count += 1 }
        return count
    }
}

#Preview {
    NavigationView {
        DataSourceSettingsView()
    }
} 