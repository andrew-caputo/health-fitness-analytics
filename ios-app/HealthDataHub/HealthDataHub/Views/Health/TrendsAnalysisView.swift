import SwiftUI
import Charts

struct TrendsAnalysisView: View {
    @StateObject private var viewModel = TrendsAnalysisViewModel()
    @EnvironmentObject var healthDataManager: HealthDataManager
    @EnvironmentObject var networkManager: NetworkManager
    @State private var selectedPeriod: TrendPeriod = .month
    @State private var trendData: [TrendDataPoint] = []
    @State private var insights: [HealthInsight] = []
    @State private var isLoading = true
    @State private var selectedTrendType: TrendType = .overall
    
    enum TrendPeriod: String, CaseIterable {
        case week = "7 Days"
        case month = "30 Days"
        case quarter = "3 Months"
        case year = "1 Year"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            }
        }
        
        var icon: String {
            switch self {
            case .week: return "calendar"
            case .month: return "calendar.badge.clock"
            case .quarter: return "calendar.badge.plus"
            case .year: return "calendar.badge.exclamationmark"
            }
        }
    }
    
    enum TrendType: String, CaseIterable {
        case overall = "Overall Health"
        case activity = "Activity Trends"
        case sleep = "Sleep Patterns"
        case nutrition = "Nutrition Trends"
        case heart = "Heart Health"
        
        var color: Color {
            switch self {
            case .overall: return .blue
            case .activity: return .green
            case .sleep: return .purple
            case .nutrition: return .orange
            case .heart: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .overall: return "chart.line.uptrend.xyaxis"
            case .activity: return "figure.walk"
            case .sleep: return "bed.double.fill"
            case .nutrition: return "fork.knife"
            case .heart: return "heart.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Period Selector
                    periodSelector
                    
                    // Trend Type Selector
                    trendTypeSelector
                    
                    // Main Trend Chart
                    mainTrendChart
                    
                    // Health Insights
                    healthInsights
                    
                    // Trend Patterns
                    trendPatterns
                }
                .padding()
            }
            .navigationTitle("Trends Analysis")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadTrendData()
            }
        }
        .onAppear {
            Task {
                await loadTrendData()
            }
        }
    }
    
    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TrendPeriod.allCases, id: \.self) { period in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedPeriod = period
                        }
                        Task {
                            await loadTrendData()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: period.icon)
                                .font(.caption)
                            
                            Text(period.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedPeriod == period ? selectedTrendType.color : Color(.systemGray5))
                        )
                        .foregroundColor(selectedPeriod == period ? .white : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var trendTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend Category")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TrendType.allCases, id: \.self) { type in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedTrendType = type
                            }
                            Task {
                                await loadTrendData()
                            }
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.title2)
                                    .foregroundColor(selectedTrendType == type ? .white : type.color)
                                
                                Text(type.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(selectedTrendType == type ? .white : .primary)
                            }
                            .frame(width: 80, height: 70)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedTrendType == type ? type.color : Color(.systemGray6))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var mainTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trend Analysis")
                    .font(.headline)
                
                Spacer()
                
                if !trendData.isEmpty {
                    TrendIndicator(trend: calculateOverallTrend())
                }
            }
            
            if isLoading {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 300)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.2)
                    )
            } else if trendData.isEmpty {
                emptyStateView
            } else {
                Chart(trendData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(selectedTrendType.color)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [selectedTrendType.color.opacity(0.3), selectedTrendType.color.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Trend line
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Trend", dataPoint.trendValue)
                    )
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                }
                .frame(height: 300)
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
    
    private var emptyStateView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemGray6))
            .frame(height: 300)
            .overlay(
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No Trend Data")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Connect health apps and sync data to see trend analysis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            )
    }
    
    private var healthInsights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Insights")
                .font(.headline)
            
            if insights.isEmpty {
                Text("No insights available yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                ForEach(insights) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
    }
    
    private var trendPatterns: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pattern Recognition")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                PatternCard(
                    title: "Weekly Pattern",
                    description: "Most active on weekends",
                    icon: "calendar.badge.clock",
                    color: .blue
                )
                
                PatternCard(
                    title: "Sleep Quality",
                    description: "Improving over time",
                    icon: "bed.double.fill",
                    color: .purple
                )
                
                PatternCard(
                    title: "Heart Rate",
                    description: "Stable resting HR",
                    icon: "heart.fill",
                    color: .red
                )
                
                PatternCard(
                    title: "Activity Trend",
                    description: "15% increase this month",
                    icon: "figure.walk",
                    color: .green
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadTrendData() async {
        isLoading = true
        
        // Simulate loading trend data
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        await MainActor.run {
            trendData = generateTrendData()
            insights = generateInsights()
            isLoading = false
        }
    }
    
    private func generateTrendData() -> [TrendDataPoint] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedPeriod.days, to: endDate) ?? endDate
        
        var data: [TrendDataPoint] = []
        let baseValue: Double = 100
        var currentValue = baseValue
        
        for i in 0..<selectedPeriod.days {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                // Add some trend and randomness
                let trendFactor = Double(i) / Double(selectedPeriod.days) * 20 // 20% trend over period
                let randomVariation = Double.random(in: -10...10)
                currentValue = baseValue + trendFactor + randomVariation
                
                // Calculate trend line value
                let trendValue = baseValue + (Double(i) / Double(selectedPeriod.days)) * 15
                
                data.append(TrendDataPoint(
                    date: date,
                    value: max(0, currentValue),
                    trendValue: trendValue,
                    category: selectedTrendType.rawValue
                ))
            }
        }
        
        return data
    }
    
    private func generateInsights() -> [HealthInsight] {
        return [
            HealthInsight(
                id: "insight_1",
                insightType: "trend",
                priority: "high",
                title: "Activity Improvement",
                description: "Your daily step count has increased by 15% over the past month. Keep up the great work!",
                dataSources: ["Apple Health"],
                metricsInvolved: ["activity_steps"],
                confidenceScore: 0.85,
                actionableRecommendations: ["Continue current routine", "Set progressive goals"],
                createdAt: Date()
            ),
            HealthInsight(
                id: "insight_2",
                insightType: "pattern",
                priority: "medium",
                title: "Sleep Pattern",
                description: "You're getting more consistent sleep. Your average sleep duration improved by 30 minutes.",
                dataSources: ["Apple Health"],
                metricsInvolved: ["sleep_duration"],
                confidenceScore: 0.78,
                actionableRecommendations: ["Maintain consistent bedtime", "Track sleep quality"],
                createdAt: Date().addingTimeInterval(-86400)
            ),
            HealthInsight(
                id: "insight_3",
                insightType: "correlation",
                priority: "low",
                title: "Heart Rate Variability",
                description: "Your HRV shows good recovery patterns. Consider maintaining your current exercise routine.",
                dataSources: ["Apple Health"],
                metricsInvolved: ["heart_rate_variability"],
                confidenceScore: 0.72,
                actionableRecommendations: ["Continue current exercise routine", "Monitor recovery"],
                createdAt: Date().addingTimeInterval(-172800)
            )
        ]
    }
    
    private func calculateOverallTrend() -> TrendDirection {
        guard trendData.count >= 2 else { return .stable }
        
        let firstValue = trendData.prefix(trendData.count / 3).map { $0.value }.reduce(0, +) / Double(trendData.count / 3)
        let lastValue = trendData.suffix(trendData.count / 3).map { $0.value }.reduce(0, +) / Double(trendData.count / 3)
        
        let percentChange = ((lastValue - firstValue) / firstValue) * 100
        
        if percentChange > 5 {
            return .improving
        } else if percentChange < -5 {
            return .declining
        } else {
            return .stable
        }
    }
}

// MARK: - Supporting Views

struct TrendIndicator: View {
    let trend: TrendDirection
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: trend.icon)
                .foregroundColor(trend.color)
                .font(.caption)
            
            Text(trend.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(trend.color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(trend.color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct InsightCard: View {
    let insight: HealthInsight
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: getInsightIcon(insight.insightType))
                .foregroundColor(getInsightColor(insight.priority))
                .font(.title2)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(insight.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(insight.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func getInsightIcon(_ type: String) -> String {
        switch type.lowercased() {
        case "trend": return "chart.line.uptrend.xyaxis"
        case "pattern": return "waveform.path.ecg"
        case "correlation": return "link"
        case "anomaly": return "exclamationmark.triangle"
        default: return "info.circle"
        }
    }
    
    private func getInsightColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high", "critical": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .blue
        }
    }
}

struct PatternCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
            }
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Data Models

struct TrendDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let trendValue: Double
    let category: String
}


enum TrendDirection: String {
    case improving = "Improving"
    case stable = "Stable"
    case declining = "Declining"
    
    var icon: String {
        switch self {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        }
    }
    
    var color: Color {
        switch self {
        case .improving: return .green
        case .stable: return .blue
        case .declining: return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    TrendsAnalysisView()
        .environmentObject(HealthDataManager.shared)
} 