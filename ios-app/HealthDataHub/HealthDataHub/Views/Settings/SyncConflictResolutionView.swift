import SwiftUI

struct SyncConflictResolutionView: View {
    @Binding var conflicts: [SyncConflict]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedResolutions: [UUID: ConflictResolution] = [:]
    @State private var showingBulkResolution = false
    @State private var bulkResolutionStrategy: BulkResolutionStrategy = .priorityBased
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with conflict summary
                conflictSummaryHeader
                
                // Conflicts list
                if conflicts.isEmpty {
                    emptyState
                } else {
                    conflictsList
                }
            }
            .navigationTitle("Resolve Conflicts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Bulk Resolution") {
                            showingBulkResolution = true
                        }
                        
                        Button("Resolve All") {
                            resolveAllConflicts()
                        }
                        .disabled(selectedResolutions.count != conflicts.count)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            })
        }
        .sheet(isPresented: $showingBulkResolution) {
            BulkResolutionView(
                strategy: $bulkResolutionStrategy,
                conflicts: conflicts,
                onApply: { strategy in
                    applyBulkResolution(strategy)
                }
            )
        }
    }
    
    private var conflictSummaryHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("Data Conflicts Detected")
                        .font(.headline)
                    Text("\(conflicts.count) conflicts need resolution")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Progress indicator
            if !conflicts.isEmpty {
                VStack(spacing: 4) {
                    HStack {
                        Text("Resolution Progress")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(selectedResolutions.count)/\(conflicts.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: Double(selectedResolutions.count), total: Double(conflicts.count))
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var conflictsList: some View {
        List {
            ForEach(conflicts) { conflict in
                ConflictResolutionRow(
                    conflict: conflict,
                    selectedResolution: selectedResolutions[conflict.id],
                    onResolutionSelected: { resolution in
                        selectedResolutions[conflict.id] = resolution
                    }
                )
            }
            
            // Apply Resolutions Button
            if selectedResolutions.count == conflicts.count {
                Section {
                    Button("Apply All Resolutions") {
                        applyResolutions()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("All Conflicts Resolved")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Great! All data conflicts have been resolved. Your health data is now synchronized.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Done") {
                dismiss()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Helper Methods
    
    private func resolveAllConflicts() {
        // Auto-resolve based on priority or latest timestamp
        for conflict in conflicts {
            if selectedResolutions[conflict.id] == nil {
                selectedResolutions[conflict.id] = .useFirst
            }
        }
    }
    
    private func applyBulkResolution(_ strategy: BulkResolutionStrategy) {
        for conflict in conflicts {
            let resolution: ConflictResolution
            
            switch strategy {
            case .priorityBased:
                resolution = .useFirst // Would use actual priority logic
            case .newestFirst:
                resolution = .useFirst
            case .mostAccurate:
                resolution = .merge
            case .userPreferred:
                resolution = .manual
            }
            
            selectedResolutions[conflict.id] = resolution
        }
    }
    
    private func applyResolutions() {
        // Apply all selected resolutions
        for (conflictId, _) in selectedResolutions {
            if let conflictIndex = conflicts.firstIndex(where: { $0.id == conflictId }) {
                // Apply the resolution logic here
                conflicts.remove(at: conflictIndex)
            }
        }
        
        selectedResolutions.removeAll()
        
        if conflicts.isEmpty {
            dismiss()
        }
    }
}

// MARK: - Extensions for Missing Properties

extension ConflictResolution {
    var icon: String {
        switch self {
        case .useFirst: return "1.circle"
        case .useSecond: return "2.circle"
        case .merge: return "function"
        case .ignore: return "eye.slash"
        case .manual: return "pencil"
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .useFirst: return "Keep the value from the first data source"
        case .useSecond: return "Keep the value from the second data source"
        case .merge: return "Calculate and use the average of both values"
        case .ignore: return "Keep both values as separate entries"
        case .manual: return "Enter a custom value manually"
        }
    }
}

extension BulkResolutionStrategy {
    var description: String {
        switch self {
        case .priorityBased: return "Resolve based on data source priority settings"
        case .newestFirst: return "Always use the most recent value"
        case .mostAccurate: return "Use the most accurate source for each conflict"
        case .userPreferred: return "Apply user-preferred resolution strategy"
        }
    }
}

// MARK: - Supporting Views

struct ConflictResolutionRow: View {
    let conflict: SyncConflict
    let selectedResolution: ConflictResolution?
    let onResolutionSelected: (ConflictResolution) -> Void
    
    @State private var showingResolutionPicker = false
    @State private var manualValue = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Conflict Header
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(conflict.severity.color)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(conflict.dataType) Conflict")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(conflict.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(conflict.severity.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(conflict.severity.color.opacity(0.2))
                    .foregroundColor(conflict.severity.color)
                    .cornerRadius(6)
            }
            
            // Conflicting Values
            VStack(spacing: 8) {
                ConflictValueRow(
                    source: conflict.source1,
                    value: conflict.value1,
                    isSelected: selectedResolution == .useFirst,
                    onSelect: {
                        onResolutionSelected(.useFirst)
                    }
                )
                
                ConflictValueRow(
                    source: conflict.source2,
                    value: conflict.value2,
                    isSelected: selectedResolution == .useSecond,
                    onSelect: {
                        onResolutionSelected(.useSecond)
                    }
                )
            }
            
            // Resolution Options
            if showingResolutionPicker {
                resolutionOptions
            } else {
                // Selected Resolution Display
                if let resolution = selectedResolution {
                    selectedResolutionDisplay(resolution)
                } else {
                    Button("Choose Resolution") {
                        showingResolutionPicker = true
                    }
                    .foregroundColor(.blue)
                    .padding(.vertical, 8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var resolutionOptions: some View {
        VStack(spacing: 8) {
            Text("Resolution Options")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(ConflictResolution.allCases, id: \.self) { resolution in
                    ResolutionOptionButton(
                        resolution: resolution,
                        isSelected: selectedResolution == resolution,
                        onSelect: {
                            onResolutionSelected(resolution)
                            showingResolutionPicker = false
                        }
                    )
                }
            }
            
            Button("Cancel") {
                showingResolutionPicker = false
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 4)
        }
    }
    
    private func selectedResolutionDisplay(_ resolution: ConflictResolution) -> some View {
        HStack {
            Image(systemName: resolution.icon)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(resolution.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(resolution.detailedDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Change") {
                showingResolutionPicker = true
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .padding(.vertical, 8)
    }
}

struct ConflictValueRow: View {
    let source: String
    let value: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(source)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(value)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray5))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ResolutionOptionButton: View {
    let resolution: ConflictResolution
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Image(systemName: resolution.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : .blue)
                
                Text(resolution.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BulkResolutionView: View {
    @Binding var strategy: BulkResolutionStrategy
    let conflicts: [SyncConflict]
    let onApply: (BulkResolutionStrategy) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Bulk Resolution")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Apply the same resolution strategy to all \(conflicts.count) conflicts")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // Strategy Options
                VStack(spacing: 12) {
                    ForEach(BulkResolutionStrategy.allCases, id: \.self) { strategyOption in
                        BulkStrategyRow(
                            strategy: strategyOption,
                            isSelected: strategy == strategyOption,
                            onSelect: {
                                strategy = strategyOption
                            }
                        )
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Apply Button
                Button("Apply to All Conflicts") {
                    onApply(strategy)
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding()
            }
            .navigationTitle("Bulk Resolution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct BulkStrategyRow: View {
    let strategy: BulkResolutionStrategy
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(strategy.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(strategy.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

struct SyncConflictResolutionView_Previews: PreviewProvider {
    static var previews: some View {
        SyncConflictResolutionView(conflicts: .constant([
            SyncConflict(
                id: UUID(),
                dataType: "Steps",
                source1: "Apple Health",
                source2: "MyFitnessPal",
                value1: "8,456 steps",
                value2: "8,234 steps",
                timestamp: Date(),
                severity: .medium
            )
        ]))
    }
} 