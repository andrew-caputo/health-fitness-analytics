import SwiftUI
import Charts

struct AIInsightsDashboardView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @StateObject private var viewModel = AIInsightsViewModel()
    @State private var selectedTimeframe: TimeFrame = .month
    @State private var showingInsightDetail = false
    @State private var selectedInsight: HealthInsight?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header with timeframe selector
                    headerSection
                    
                    // Health Score Card
                    if let healthScore = viewModel.healthScore {
                        healthScoreCard(healthScore)
                    }
                    
                    // Quick Insights Summary
                    insightsSummaryCard
                    
                    // Priority Insights
                    priorityInsightsSection
                    
                    // Recommendations
                    recommendationsSection
                    
                    // Recent Anomalies
                    anomaliesSection
                }
                .padding()
            }
            .navigationTitle("AI Insights")
            .refreshable {
                await viewModel.refreshData(timeframe: selectedTimeframe)
            }
            .task {
                // Initialize ViewModel with NetworkManager
                viewModel.setNetworkManager(networkManager)
                await viewModel.loadData(timeframe: selectedTimeframe)
            }
            .sheet(isPresented: $showingInsightDetail) {
                if let insight = selectedInsight {
                    InsightDetailView(insight: insight)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your Health Intelligence")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await viewModel.refreshData(timeframe: selectedTimeframe)
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
            }
            
            // Timeframe Selector
            Picker("Timeframe", selection: $selectedTimeframe) {
                ForEach(TimeFrame.allCases, id: \.self) { timeframe in
                    Text(timeframe.displayName).tag(timeframe)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedTimeframe) { newValue in
                Task {
                    await viewModel.loadData(timeframe: newValue)
                }
            }
        }
    }
    
    private func healthScoreCard(_ healthScore: HealthScore) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Health Score")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(Int(healthScore.overallScore))")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor(healthScore.overallScore))
            }
            
            // Score breakdown chart
            Chart {
                ForEach(healthScore.componentScores, id: \.category) { component in
                    BarMark(
                        x: .value("Score", component.score),
                        y: .value("Category", component.category)
                    )
                    .foregroundStyle(componentColor(component.category))
                    .cornerRadius(4)
                }
            }
            .frame(height: 200)
            .chartXScale(domain: 0...100)
            
            // Component scores grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(healthScore.componentScores, id: \.category) { component in
                    VStack(spacing: 4) {
                        Text(component.category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(component.score))")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(scoreColor(component.score))
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var insightsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let summary = viewModel.insightsSummary {
                HStack(spacing: 20) {
                    InsightCountView(
                        count: summary.totalInsights,
                        label: "Total",
                        color: .blue
                    )
                    
                    InsightCountView(
                        count: summary.highPriorityCount,
                        label: "High Priority",
                        color: .red
                    )
                    
                    InsightCountView(
                        count: summary.mediumPriorityCount,
                        label: "Medium",
                        color: .orange
                    )
                    
                    InsightCountView(
                        count: summary.lowPriorityCount,
                        label: "Low",
                        color: .green
                    )
                }
                
                // Categories breakdown
                if !summary.categories.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("By Category")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        ForEach(Array(summary.categories.keys.sorted()), id: \.self) { category in
                            HStack {
                                Text(category.capitalized)
                                    .font(.caption)
                                
                                Spacer()
                                
                                Text("\(summary.categories[category] ?? 0)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            } else {
                Text("Loading insights...")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var priorityInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Priority Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink("View All") {
                    AllInsightsView()
                        .tag(1)
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if viewModel.priorityInsights.isEmpty {
                Text("No priority insights at this time")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(viewModel.priorityInsights.prefix(3), id: \.id) { insight in
                    InsightRowView(insight: insight) {
                        selectedInsight = insight
                        showingInsightDetail = true
                    }
                }
            }
        }
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Personalized Recommendations")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink("View All") {
                    RecommendationsView()
                        .tag(2)
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if viewModel.recommendations.isEmpty {
                Text("Loading recommendations...")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(viewModel.recommendations.prefix(2), id: \.title) { recommendation in
                    RecommendationRowView(recommendation: recommendation)
                }
            }
        }
    }
    
    private var anomaliesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Anomalies")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink("View All") {
                    AnomaliesView()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if viewModel.anomalies.isEmpty {
                Text("No anomalies detected")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(viewModel.anomalies.prefix(2), id: \.metric) { anomaly in
                    AnomalyRowView(anomaly: anomaly)
                }
            }
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
    
    private func componentColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "activity": return .blue
        case "sleep": return .purple
        case "nutrition": return .green
        case "heart health": return .red
        case "consistency": return .orange
        case "trend": return .cyan
        default: return .gray
        }
    }
}

struct InsightCountView: View {
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct InsightRowView: View {
    let insight: HealthInsight
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(insight.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    PriorityBadge(priority: insight.priority)
                }
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                HStack {
                    Text("Confidence: \(Int(insight.confidenceScore * 100))%")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text(insight.insightType.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecommendationRowView: View {
    let recommendation: Recommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(recommendation.category.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(4)
            }
            
            Text(recommendation.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if !recommendation.actions.isEmpty {
                Text("• \(recommendation.actions.first ?? "")")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct AnomalyRowView: View {
    let anomaly: Anomaly
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(anomaly.metric.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                SeverityIndicator(severity: anomaly.severity)
            }
            
            Text(anomaly.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text("Date: \(anomaly.date)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Value: \(anomaly.value, specifier: "%.1f")")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct PriorityBadge: View {
    let priority: String
    
    var body: some View {
        Text(priority.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(priorityColor.opacity(0.1))
            .foregroundColor(priorityColor)
            .cornerRadius(4)
    }
    
    private var priorityColor: Color {
        switch priority.lowercased() {
        case "critical": return .red
        case "high": return .orange
        case "medium": return .yellow
        case "low": return .green
        default: return .gray
        }
    }
}

struct SeverityIndicator: View {
    let severity: Double
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(index < severityLevel ? severityColor : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
    
    private var severityLevel: Int {
        switch severity {
        case 0.0..<0.33: return 1
        case 0.33..<0.66: return 2
        default: return 3
        }
    }
    
    private var severityColor: Color {
        switch severityLevel {
        case 1: return .yellow
        case 2: return .orange
        default: return .red
        }
    }
}

// MARK: - Data Models

struct HealthScore {
    let overallScore: Double
    let componentScores: [ComponentScore]
    let lastUpdated: Date
}

struct ComponentScore {
    let category: String
    let score: Double
}


struct InsightsSummary {
    let totalInsights: Int
    let highPriorityCount: Int
    let mediumPriorityCount: Int
    let lowPriorityCount: Int
    let categories: [String: Int]
}

struct Recommendation {
    let category: String
    let title: String
    let description: String
    let metrics: [String]
    let confidence: Double
    let priority: String
    let actions: [String]
    let expectedBenefit: String
    let timeframe: String
}

struct Anomaly {
    let metric: String
    let date: String
    let value: Double
    let severity: Double
    let confidence: Double
    let type: String
    let description: String
    let recommendations: [String]
}

enum TimeFrame: String, CaseIterable {
    case week = "7"
    case month = "30"
    case quarter = "90"
    case year = "365"
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "3 Months"
        case .year: return "Year"
        }
    }
}

// MARK: - View Model

@MainActor
class AIInsightsViewModel: ObservableObject {
    @Published var healthScore: HealthScore?
    @Published var insightsSummary: InsightsSummary?
    @Published var priorityInsights: [HealthInsight] = []
    @Published var recommendations: [Recommendation] = []
    @Published var anomalies: [Anomaly] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var networkManager: NetworkManager = NetworkManager.shared
    
    func setNetworkManager(_ networkManager: NetworkManager) {
        self.networkManager = networkManager
    }
    
    func loadData(timeframe: TimeFrame) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load all data concurrently
            async let healthScoreTask = loadHealthScore(timeframe: timeframe)
            async let insightsSummaryTask = loadInsightsSummary(timeframe: timeframe)
            async let priorityInsightsTask = loadPriorityInsights(timeframe: timeframe)
            async let recommendationsTask = loadRecommendations(timeframe: timeframe)
            async let anomaliesTask = loadAnomalies(timeframe: timeframe)
            
            let (healthScore, summary, insights, recs, anomalies) = try await (
                healthScoreTask,
                insightsSummaryTask,
                priorityInsightsTask,
                recommendationsTask,
                anomaliesTask
            )
            
            self.healthScore = healthScore
            self.insightsSummary = summary
            self.priorityInsights = insights
            self.recommendations = recs
            self.anomalies = anomalies
            
        } catch {
            errorMessage = "Failed to load AI insights: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func refreshData(timeframe: TimeFrame) async {
        await loadData(timeframe: timeframe)
    }
    
    private func loadHealthScore(timeframe: TimeFrame) async throws -> HealthScore {
        // Real backend integration - replace mock data
        let daysBack = timeframeToDays(timeframe)
        print("🏥 Fetching real health score from backend API for \(daysBack) days...")
        do {
            let response = try await withTimeout(seconds: 10) { [self] in
                try await self.networkManager.fetchHealthScore(daysBack: daysBack)
            }
            
            let componentScores = response.component_scores.map { component in
                ComponentScore(
                    category: component.category,
                    score: component.score
                )
            }
            
            print("✅ Fetched real health score: \(response.overall_score)")
            return HealthScore(
                overallScore: response.overall_score,
                componentScores: componentScores,
                lastUpdated: Date()
            )
        } catch {
            print("❌ Error fetching health score: \(error)")
            print("📱 Using fallback health score")
            // Fallback to basic health score
            return HealthScore(
                overallScore: 0.0,
                componentScores: [],
                lastUpdated: Date()
            )
        }
    }
    
    private func loadInsightsSummary(timeframe: TimeFrame) async throws -> InsightsSummary {
        // Real backend integration - replace mock data
        print("🧠 Fetching real insights summary from backend API...")
        do {
            let response = try await withTimeout(seconds: 10) { [self] in
                try await self.networkManager.fetchAIInsights()
            }
            
            print("✅ Fetched real insights: \(response.total_count) insights")
            return InsightsSummary(
                totalInsights: response.total_count,
                highPriorityCount: response.high_priority_count,
                mediumPriorityCount: response.medium_priority_count,
                lowPriorityCount: response.low_priority_count,
                categories: response.categories ?? [:]
            )
        } catch {
            print("❌ Error fetching insights summary: \(error)")
            print("📱 Using fallback insights summary")
            // Fallback to empty insights
            return InsightsSummary(
                totalInsights: 0,
                highPriorityCount: 0,
                mediumPriorityCount: 0,
                lowPriorityCount: 0,
                categories: [:]
            )
        }
    }
    
    private func loadPriorityInsights(timeframe: TimeFrame) async throws -> [HealthInsight] {
        // Real backend integration - replace mock data
        print("🎯 Fetching real priority insights from backend API...")
        do {
            let response = try await withTimeout(seconds: 10) { [self] in
                try await self.networkManager.fetchAIInsights()
            }
            
            // Convert backend insights to app model and filter by priority
            let allInsights = response.insights.map { insight in
                HealthInsight(
                    id: insight.id,
                    insightType: insight.insight_type,
                    priority: insight.priority,
                    title: insight.title,
                    description: insight.description,
                    dataSources: insight.data_sources,
                    metricsInvolved: insight.metrics_involved,
                    confidenceScore: insight.confidence_score,
                    actionableRecommendations: insight.actionable_recommendations,
                    createdAt: Date() // Convert from string if needed
                )
            }
            
            // Filter for high and medium priority insights
            let priorityInsights = allInsights.filter { insight in
                insight.priority.lowercased() == "high" || insight.priority.lowercased() == "medium"
            }
            
            print("✅ Fetched \(priorityInsights.count) priority insights")
            return Array(priorityInsights.prefix(10)) // Limit to top 10
        } catch {
            print("❌ Error fetching priority insights: \(error)")
            print("📱 Using fallback: No insights available")
            return []
        }
    }
    
    private func loadRecommendations(timeframe: TimeFrame) async throws -> [Recommendation] {
        // Real backend integration - replace mock data
        print("💡 Fetching real recommendations from backend API...")
        do {
            let response = try await withTimeout(seconds: 10) { [self] in
                try await self.networkManager.fetchAIRecommendations()
            }
            
            // Convert backend recommendations to app model
            let recommendations = response.recommendations.map { rec in
                Recommendation(
                    category: rec.category,
                    title: rec.title,
                    description: rec.description,
                    metrics: rec.metrics,
                    confidence: rec.confidence,
                    priority: rec.priority,
                    actions: rec.actions,
                    expectedBenefit: rec.expected_benefit,
                    timeframe: rec.timeframe
                )
            }
            
            print("✅ Fetched \(recommendations.count) real recommendations")
            return recommendations
        } catch {
            print("❌ Error fetching recommendations: \(error)")
            print("📱 Using fallback: No recommendations available")
            return []
        }
    }
    
    private func loadAnomalies(timeframe: TimeFrame) async throws -> [Anomaly] {
        // Real backend integration - replace mock data
        print("⚠️ Fetching real anomalies from backend API...")
        do {
            let response = try await withTimeout(seconds: 10) { [self] in
                try await self.networkManager.fetchAIAnomalies()
            }
            
            // Convert backend anomalies to app model
            let anomalies = response.anomalies.map { anomaly in
                Anomaly(
                    metric: anomaly.metric,
                    date: anomaly.date,
                    value: anomaly.value,
                    severity: anomaly.severity,
                    confidence: anomaly.confidence,
                    type: anomaly.type,
                    description: anomaly.description,
                    recommendations: anomaly.recommendations
                )
            }
            
            print("✅ Fetched \(anomalies.count) real anomalies")
            return anomalies
        } catch {
            print("❌ Error fetching anomalies: \(error)")
            print("📱 Using fallback: No anomalies detected")
            return []
        }
    }
    
    private func timeframeToDays(_ timeframe: TimeFrame) -> Int {
        switch timeframe {
        case .week:
            return 7
        case .month:
            return 30
        case .quarter:
            return 90
        case .year:
            return 365
        }
    }
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Missing Views

struct AllInsightsView: View {
    var body: some View {
        Text("All Insights")
            .navigationTitle("All Insights")
    }
}

struct RecommendationsView: View {
    var body: some View {
        Text("Recommendations")
            .navigationTitle("Recommendations")
    }
}

struct AnomaliesView: View {
    var body: some View {
        Text("Anomalies")
            .navigationTitle("Anomalies")
    }
}

#Preview {
    AIInsightsDashboardView()
} 