import SwiftUI

struct DataSourceSelectionView: View {
    @StateObject private var viewModel = DataSourceSelectionViewModel()
    var onComplete: () -> Void
    @State private var showingContinue = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    
                    if viewModel.isLoading {
                        loadingSection
                    } else {
                        progressSection
                        categoriesSection
                        
                        if viewModel.hasValidSelections {
                            continueButton
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Data Sources")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        onComplete()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .task {
            await viewModel.loadAvailableSources()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.error ?? "An error occurred")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "apps.iphone")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                Text("Choose Your Health Data Sources")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text("Select which apps or devices you'd like to use for each type of health data. You can change these later in Settings.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            
            Text("Loading available data sources...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(minHeight: 200)
    }
    
    private var progressSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Setup Progress")
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(viewModel.completionPercentage * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: viewModel.completionPercentage)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private var categoriesSection: some View {
        LazyVStack(spacing: 16) {
            ForEach(HealthCategory.allCases, id: \.self) { category in
                CategorySelectionCard(
                    category: category,
                    selectedSource: Binding(
                        get: { viewModel.preferences[category] ?? nil },
                        set: { newValue in
                            if let newValue = newValue {
                                viewModel.selectSource(newValue, for: category)
                            }
                        }
                    ),
                    availableSources: viewModel.getSourcesForCategory(category)
                )
            }
            
            // Show linked categories help message
            if let linkedMessage = viewModel.linkedCategoriesMessage {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text(linkedMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemBlue).opacity(0.1))
                )
            }
        }
    }
    
    private var continueButton: some View {
        VStack(spacing: 12) {
            Button("Continue") {
                Task {
                    await viewModel.savePreferences()
                    
                    // Only dismiss if save was successful
                    if viewModel.error == nil {
                        onComplete()
                    } else {
                        // Error will be shown via alert
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(viewModel.isLoading)
            
            // Loading state feedback
            if viewModel.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                        .scaleEffect(0.8)
                    Text("Saving preferences...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            } else {
                Text("You've selected sources for the essential health categories. You can add more sources later in Settings.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Validation message if selections are invalid
            if let validationMessage = viewModel.validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Quick Setup Recommendations
struct QuickSetupSection: View {
    let viewModel: DataSourceSelectionViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "wand.and.rays")
                    .foregroundColor(.blue)
                
                Text("Quick Setup")
                    .font(.headline)
                
                Spacer()
            }
            
            if viewModel.availableSources.contains(where: { $0.source_name == "apple_health" }) {
                QuickSetupCard(
                    title: "Use Apple Health for Everything",
                    description: "Apple Health can provide data for all categories",
                    icon: "applelogo",
                    action: {
                        setupAppleHealthForAll()
                    }
                )
            }
            
            QuickSetupCard(
                title: "Set Up Later",
                description: "Continue with the app and configure sources when needed",
                icon: "clock",
                action: {
                    // Will be handled by skip button
                }
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2)
        )
    }
    
    private func setupAppleHealthForAll() {
        for category in HealthCategory.allCases {
            if viewModel.getSourcesForCategory(category).contains(where: { $0.source_name == "apple_health" }) {
                viewModel.selectSource("apple_health", for: category)
            }
        }
    }
}

struct QuickSetupCard: View {
    let title: String
    let description: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    DataSourceSelectionView(onComplete: {})
} 