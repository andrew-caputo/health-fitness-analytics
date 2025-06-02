import SwiftUI

struct CategorySelectionCard: View {
    let category: HealthCategory
    @Binding var selectedSource: String?
    let availableSources: [PreferenceDataSource]
    @State private var showingSourcePicker = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Category Header
            HStack {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(category.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if selectedSource != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
            }
            
            // Source Selection
            if availableSources.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("No sources available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                Button(action: {
                    showingSourcePicker = true
                }) {
                    HStack {
                        if let sourceName = selectedSource,
                           let source = availableSources.first(where: { $0.source_name == sourceName }) {
                            // Selected source display
                            if source.isSFSymbol {
                                Image(systemName: source.iconName)
                                    .foregroundColor(source.brandColor)
                            } else {
                                Image(source.iconName) // Custom asset
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24) // Adjust size as needed
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.display_name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Text(source.integrationTypeDisplayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            // No selection state
                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                            
                            Text("Choose source")
                                .font(.body)
                                .foregroundColor(.blue)
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
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .sheet(isPresented: $showingSourcePicker) {
            SourcePickerView(
                category: category,
                sources: availableSources,
                selectedSource: $selectedSource
            )
        }
    }
}

struct SourcePickerView: View {
    let category: HealthCategory
    let sources: [PreferenceDataSource]
    @Binding var selectedSource: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(sources) { source in
                        SourceRow(
                            source: source,
                            isSelected: selectedSource == source.source_name
                        ) {
                            selectedSource = source.source_name
                            dismiss()
                        }
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Choose \(category.displayName) Source")
                            .font(.headline)
                        Text(category.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if selectedSource != nil {
                    Section {
                        Button("Remove Selection") {
                            selectedSource = nil
                            dismiss()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Data Source")
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
}

struct SourceRow: View {
    let source: PreferenceDataSource
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: 12) {
                // Source icon
                if source.isSFSymbol {
                    Image(systemName: source.iconName)
                        .font(.title2)
                        .foregroundColor(source.brandColor)
                        .frame(width: 30)
                } else {
                    Image(source.iconName) // Custom asset
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30) // Adjust size as needed
                }
                
                // Source info
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.display_name)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text(source.integrationTypeDisplayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if source.is_active {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Available")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Coming Soon")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!source.is_active)
        .opacity(source.is_active ? 1.0 : 0.6)
    }
}

// MARK: - Category Icon Component
struct CategoryIcon: View {
    let category: HealthCategory
    var size: CGFloat = 24
    
    var body: some View {
        Image(systemName: category.icon)
            .font(.system(size: size))
            .foregroundColor(.blue)
    }
}

#Preview {
    VStack(spacing: 16) {
        CategorySelectionCard(
            category: .activity,
            selectedSource: .constant("apple_health"),
            availableSources: [
                PreferenceDataSource(
                    source_name: "apple_health",
                    display_name: "Apple Health",
                    supports_activity: true,
                    supports_sleep: true,
                    supports_nutrition: true,
                    supports_body_composition: true,
                    integration_type: "api",
                    is_active: true
                ),
                PreferenceDataSource(
                    source_name: "fitbit",
                    display_name: "Fitbit",
                    supports_activity: true,
                    supports_sleep: true,
                    supports_nutrition: false,
                    supports_body_composition: true,
                    integration_type: "oauth2",
                    is_active: true
                )
            ]
        )
        
        CategorySelectionCard(
            category: .nutrition,
            selectedSource: .constant(nil),
            availableSources: []
        )
    }
    .padding()
    .background(Color(.systemGray6))
} 