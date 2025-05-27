import SwiftUI
import UniformTypeIdentifiers

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormats: Set<ExportFormat> = [.json]
    @State private var selectedDateRange: DateRange = .allTime
    @State private var selectedDataTypes: Set<PrivacySettings.HealthDataType> = Set(PrivacySettings.HealthDataType.allCases)
    @State private var isExporting = false
    @State private var exportProgress: Double = 0.0
    @State private var exportedFiles: [ExportedFile] = []
    @State private var showingShareSheet = false
    @State private var showingSuccessAlert = false
    
    enum ExportFormat: String, CaseIterable {
        case json = "JSON"
        case csv = "CSV"
        case xml = "XML"
        case pdf = "PDF Report"
        
        var fileExtension: String {
            switch self {
            case .json: return "json"
            case .csv: return "csv"
            case .xml: return "xml"
            case .pdf: return "pdf"
            }
        }
        
        var icon: String {
            switch self {
            case .json: return "doc.text"
            case .csv: return "tablecells"
            case .xml: return "doc.richtext"
            case .pdf: return "doc.text.image"
            }
        }
        
        var description: String {
            switch self {
            case .json: return "Machine-readable format for developers"
            case .csv: return "Spreadsheet format for analysis"
            case .xml: return "Apple Health compatible format"
            case .pdf: return "Human-readable health report"
            }
        }
        
        var color: Color {
            switch self {
            case .json: return .blue
            case .csv: return .green
            case .xml: return .orange
            case .pdf: return .red
            }
        }
    }
    
    enum DateRange: String, CaseIterable {
        case lastWeek = "Last 7 Days"
        case lastMonth = "Last 30 Days"
        case lastThreeMonths = "Last 3 Months"
        case lastYear = "Last Year"
        case allTime = "All Time"
        
        var description: String {
            switch self {
            case .lastWeek: return "Data from the past week"
            case .lastMonth: return "Data from the past month"
            case .lastThreeMonths: return "Data from the past 3 months"
            case .lastYear: return "Data from the past year"
            case .allTime: return "All available data"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Export Overview
                    exportOverview
                    
                    // Format Selection
                    formatSelection
                    
                    // Date Range Selection
                    dateRangeSelection
                    
                    // Data Type Selection
                    dataTypeSelection
                    
                    // Export Progress
                    if isExporting {
                        exportProgressView
                    }
                    
                    // Exported Files
                    if !exportedFiles.isEmpty {
                        exportedFilesView
                    }
                    
                    // Export Button
                    exportButton
                }
                .padding()
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: exportedFiles.map { $0.url })
        }
        .alert("Export Complete", isPresented: $showingSuccessAlert) {
            Button("Share Files") {
                showingShareSheet = true
            }
            Button("OK") { }
        } message: {
            Text("Your health data has been successfully exported to \(exportedFiles.count) file\(exportedFiles.count > 1 ? "s" : "").")
        }
    }
    
    private var exportOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("Export Your Health Data")
                        .font(.headline)
                    Text("Download your data in multiple formats")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Export Summary
            VStack(spacing: 8) {
                HStack {
                    Text("Export Summary")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                
                HStack {
                    ExportSummaryItem(
                        title: "Formats",
                        value: "\(selectedFormats.count)",
                        icon: "doc.text",
                        color: .blue
                    )
                    
                    ExportSummaryItem(
                        title: "Data Types",
                        value: "\(selectedDataTypes.count)",
                        icon: "heart.fill",
                        color: .red
                    )
                    
                    ExportSummaryItem(
                        title: "Time Range",
                        value: selectedDateRange.rawValue,
                        icon: "calendar",
                        color: .green
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    private var formatSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Formats")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    FormatSelectionCard(
                        format: format,
                        isSelected: selectedFormats.contains(format),
                        onToggle: {
                            if selectedFormats.contains(format) {
                                selectedFormats.remove(format)
                            } else {
                                selectedFormats.insert(format)
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var dateRangeSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Date Range")
                .font(.headline)
            
            ForEach(DateRange.allCases, id: \.self) { range in
                DateRangeRow(
                    range: range,
                    isSelected: selectedDateRange == range,
                    onSelect: {
                        selectedDateRange = range
                    }
                )
            }
        }
    }
    
    private var dataTypeSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Data Types")
                    .font(.headline)
                
                Spacer()
                
                Button(selectedDataTypes.count == PrivacySettings.HealthDataType.allCases.count ? "Deselect All" : "Select All") {
                    if selectedDataTypes.count == PrivacySettings.HealthDataType.allCases.count {
                        selectedDataTypes.removeAll()
                    } else {
                        selectedDataTypes = Set(PrivacySettings.HealthDataType.allCases)
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(PrivacySettings.HealthDataType.allCases, id: \.self) { dataType in
                    DataTypeToggle(
                        dataType: dataType,
                        isSelected: selectedDataTypes.contains(dataType),
                        onToggle: {
                            if selectedDataTypes.contains(dataType) {
                                selectedDataTypes.remove(dataType)
                            } else {
                                selectedDataTypes.insert(dataType)
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var exportProgressView: some View {
        VStack(spacing: 16) {
            Text("Exporting Data...")
                .font(.headline)
            
            ProgressView(value: exportProgress)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text("\(Int(exportProgress * 100))% Complete")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var exportedFilesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exported Files")
                .font(.headline)
            
            ForEach(exportedFiles) { file in
                ExportedFileRow(file: file)
            }
            
            Button(action: {
                showingShareSheet = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share All Files")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
    }
    
    private var exportButton: some View {
        Button(action: {
            startExport()
        }) {
            HStack {
                if isExporting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                
                Text(isExporting ? "Exporting..." : "Start Export")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canExport ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canExport || isExporting)
    }
    
    private var canExport: Bool {
        !selectedFormats.isEmpty && !selectedDataTypes.isEmpty
    }
    
    // MARK: - Helper Methods
    
    private func startExport() {
        isExporting = true
        exportProgress = 0.0
        exportedFiles.removeAll()
        
        // Simulate export process
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            exportProgress += 0.05
            
            if exportProgress >= 1.0 {
                timer.invalidate()
                completeExport()
            }
        }
    }
    
    private func completeExport() {
        isExporting = false
        exportProgress = 1.0
        
        // Create mock exported files
        for format in selectedFormats {
            let file = ExportedFile(
                name: "health_data_\(Date().timeIntervalSince1970).\(format.fileExtension)",
                format: format,
                size: "2.3 MB",
                url: URL(string: "file://mock")!
            )
            exportedFiles.append(file)
        }
        
        showingSuccessAlert = true
    }
}

// MARK: - Supporting Views

struct FormatSelectionCard: View {
    let format: DataExportView.ExportFormat
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 8) {
                Image(systemName: format.icon)
                    .foregroundColor(isSelected ? .white : format.color)
                    .font(.title2)
                
                Text(format.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(format.description)
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(isSelected ? format.color : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DateRangeRow: View {
    let range: DataExportView.DateRange
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(range.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(range.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DataTypeToggle: View {
    let dataType: PrivacySettings.HealthDataType
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.caption)
                
                Text(dataType.rawValue)
                    .font(.caption)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ExportSummaryItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .cornerRadius(6)
    }
}

struct ExportedFileRow: View {
    let file: ExportedFile
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: file.format.icon)
                .foregroundColor(file.format.color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(file.format.rawValue) • \(file.size)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                // Share individual file
            }) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Data Models

struct ExportedFile: Identifiable {
    let id = UUID()
    let name: String
    let format: DataExportView.ExportFormat
    let size: String
    let url: URL
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

struct DataExportView_Previews: PreviewProvider {
    static var previews: some View {
        DataExportView()
    }
} 