import SwiftUI
import Charts
import HealthKit

struct HealthChartsView: View {
    @StateObject private var viewModel = HealthChartsViewModel()
    @EnvironmentObject var networkManager: NetworkManager
    @EnvironmentObject var healthDataManager: HealthDataManager
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedMetric: HealthMetric = .steps
    @State private var chartData: [ChartDataPoint] = []
    @State private var isLoading = true
    @State private var showingMetricPicker = false
    
    enum TimeRange: String, CaseIterable {
        case day = "24H"
        case week = "7D"
        case month = "30D"
        case quarter = "3M"
        case year = "1Y"
        
        var displayName: String {
            switch self {
            case .day: return "24 Hours"
            case .week: return "7 Days"
            case .month: return "30 Days"
            case .quarter: return "3 Months"
            case .year: return "1 Year"
            }
        }
        
        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            }
        }
    }
    
    enum HealthMetric: String, CaseIterable {
        case steps = "Steps"
        case heartRate = "Heart Rate"
        case activeEnergy = "Active Energy"
        case sleep = "Sleep"
        case weight = "Weight"
        case nutrition = "Calories"
        
        var unit: String {
            switch self {
            case .steps: return "steps"
            case .heartRate: return "bpm"
            case .activeEnergy: return "cal"
            case .sleep: return "hours"
            case .weight: return "lbs"
            case .nutrition: return "cal"
            }
        }
        
        var color: Color {
            switch self {
            case .steps: return .blue
            case .heartRate: return .red
            case .activeEnergy: return .orange
            case .sleep: return .purple
            case .weight: return .pink
            case .nutrition: return .green
            }
        }
        
        var icon: String {
            switch self {
            case .steps: return "figure.walk"
            case .heartRate: return "heart.fill"
            case .activeEnergy: return "flame.fill"
            case .sleep: return "bed.double.fill"
            case .weight: return "scalemass.fill"
            case .nutrition: return "fork.knife"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Time Range Selector
                    timeRangeSelector
                    
                    // Metric Selector
                    metricSelector
                    
                    // Main Chart
                    mainChart
                    
                    // Chart Statistics
                    chartStatistics
                    
                    // Data Sources Attribution
                    dataSourcesAttribution
                }
                .padding()
            }
            .navigationTitle("Health Charts")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadChartData()
            }
        }
        .onAppear {
            Task {
                await loadChartData()
            }
        }
        .sheet(isPresented: $showingMetricPicker) {
            MetricPickerSheet(selectedMetric: $selectedMetric) {
                Task {
                    await loadChartData()
                }
            }
        }
    }
    
    private var timeRangeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTimeRange = range
                        }
                        Task {
                            await loadChartData()
                        }
                    }) {
                        Text(range.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedTimeRange == range ? selectedMetric.color : Color(.systemGray5))
                            )
                            .foregroundColor(selectedTimeRange == range ? .white : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var metricSelector: some View {
        Button(action: {
            showingMetricPicker = true
        }) {
            HStack {
                Image(systemName: selectedMetric.icon)
                    .foregroundColor(selectedMetric.color)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text(selectedMetric.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(selectedTimeRange.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var mainChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend Analysis")
                .font(.headline)
            
            if isLoading {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 250)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.2)
                    )
            } else if chartData.isEmpty {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 250)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            Text("No Data Available")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Connect health apps to see your data")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            } else {
                Chart(chartData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value(selectedMetric.rawValue, dataPoint.value)
                    )
                    .foregroundStyle(selectedMetric.color)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value(selectedMetric.rawValue, dataPoint.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [selectedMetric.color.opacity(0.3), selectedMetric.color.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    if let source = dataPoint.source {
                        PointMark(
                            x: .value("Date", dataPoint.date),
                            y: .value(selectedMetric.rawValue, dataPoint.value)
                        )
                        .foregroundStyle(colorForSource(source))
                        .symbolSize(30)
                    }
                }
                .frame(height: 250)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    private var chartStatistics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatisticCard(
                    title: "Average",
                    value: formatValue(averageValue),
                    unit: selectedMetric.unit,
                    color: .blue
                )
                
                StatisticCard(
                    title: "Maximum",
                    value: formatValue(maxValue),
                    unit: selectedMetric.unit,
                    color: .green
                )
                
                StatisticCard(
                    title: "Minimum",
                    value: formatValue(minValue),
                    unit: selectedMetric.unit,
                    color: .orange
                )
            }
        }
    }
    
    private var dataSourcesAttribution: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Sources")
                .font(.headline)
            
            if chartData.isEmpty {
                Text("No data sources available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                let sources = Set(chartData.compactMap { $0.source })
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(Array(sources), id: \.self) { source in
                        HStack {
                            Circle()
                                .fill(colorForSource(source))
                                .frame(width: 12, height: 12)
                            
                            Text(source)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var averageValue: Double {
        guard !chartData.isEmpty else { return 0 }
        return chartData.map { $0.value }.reduce(0, +) / Double(chartData.count)
    }
    
    private var maxValue: Double {
        chartData.map { $0.value }.max() ?? 0
    }
    
    private var minValue: Double {
        chartData.map { $0.value }.min() ?? 0
    }
    
    // MARK: - Helper Methods
    
    private func loadChartData() async {
        isLoading = true
        
        // Simulate loading data from HealthKit and backend
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            chartData = generateMockData()
            isLoading = false
        }
    }
    
    private func generateMockData() -> [ChartDataPoint] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: endDate) ?? endDate
        
        var data: [ChartDataPoint] = []
        let sources = ["Apple Watch", "MyFitnessPal", "Strava", "Sleep Cycle"]
        
        for i in 0..<selectedTimeRange.days {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                let baseValue: Double
                let variation = Double.random(in: 0.8...1.2)
                
                switch selectedMetric {
                case .steps:
                    baseValue = Double.random(in: 6000...12000) * variation
                case .heartRate:
                    baseValue = Double.random(in: 60...85) * variation
                case .activeEnergy:
                    baseValue = Double.random(in: 300...800) * variation
                case .sleep:
                    baseValue = Double.random(in: 6.5...8.5) * variation
                case .weight:
                    baseValue = Double.random(in: 150...180) * variation
                case .nutrition:
                    baseValue = Double.random(in: 1800...2500) * variation
                }
                
                data.append(ChartDataPoint(
                    date: date,
                    value: baseValue,
                    source: sources.randomElement()
                ))
            }
        }
        
        return data.sorted { $0.date < $1.date }
    }
    
    private func colorForSource(_ source: String) -> Color {
        switch source.lowercased() {
        case "apple watch": return .blue
        case "myfitnesspal": return .orange
        case "strava": return .red
        case "sleep cycle": return .purple
        case "oura": return .green
        case "fitbit": return .cyan
        default: return .gray
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        switch selectedMetric {
        case .steps:
            return String(format: "%.0f", value)
        case .heartRate:
            return String(format: "%.0f", value)
        case .activeEnergy:
            return String(format: "%.0f", value)
        case .sleep:
            return String(format: "%.1f", value)
        case .weight:
            return String(format: "%.1f", value)
        case .nutrition:
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Supporting Views

struct StatisticCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct MetricPickerSheet: View {
    @Binding var selectedMetric: HealthChartsView.HealthMetric
    let onSelection: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(HealthChartsView.HealthMetric.allCases, id: \.self) { metric in
                    Button(action: {
                        selectedMetric = metric
                        onSelection()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: metric.icon)
                                .foregroundColor(metric.color)
                                .font(.title2)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text(metric.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Measured in \(metric.unit)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedMetric == metric {
                                Image(systemName: "checkmark")
                                    .foregroundColor(metric.color)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Metric")
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

// MARK: - Data Models

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let source: String?
}

// MARK: - Preview

struct HealthChartsView_Previews: PreviewProvider {
    static var previews: some View {
        HealthChartsView()
            .environmentObject(HealthDataManager())
            .environmentObject(NetworkManager.shared)
    }
} 