import SwiftUI
import Charts

struct GoalProgressView: View {
    @StateObject private var viewModel = GoalProgressViewModel()
    @State private var selectedGoal: GoalProgress?
    @State private var showingGoalDetail = false
    @State private var showingAdjustmentSheet = false
    @State private var showingPredictionDetail = false
    @State private var selectedTimeframe: ProgressTimeframe = .thirtyDays
    @State private var showingAchievementTimeline = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Progress Overview Header
                    progressOverviewHeader
                    
                    // Timeframe Selector
                    timeframeSelector
                    
                    // Active Goals Progress
                    activeGoalsSection
                    
                    // Progress Predictions
                    progressPredictionsSection
                    
                    // Achievement Timeline
                    achievementTimelineSection
                    
                    // Goal Recommendations
                    goalRecommendationsSection
                    
                    // Cross-Source Integration
                    crossSourceIntegrationSection
                }
                .padding()
            }
            .navigationTitle("Goal Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Timeline") {
                        showingAchievementTimeline = true
                    }
                }
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .sheet(isPresented: $showingGoalDetail) {
                if let goal = selectedGoal {
                    GoalProgressDetailView(goal: goal, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showingAdjustmentSheet) {
                if let goal = selectedGoal {
                    GoalAdjustmentRecommendationView(goal: goal, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showingPredictionDetail) {
                ProgressPredictionDetailView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingAchievementTimeline) {
                AchievementTimelineView(viewModel: viewModel)
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
    }
    
    private var progressOverviewHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.green)
                    .font(.title2)
                Text("Progress Overview")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Text("Track your health goals with AI-powered insights and predictions based on data from all your connected sources.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            // Progress Stats Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                ProgressStatCard(
                    title: "On Track",
                    value: "\(viewModel.goalsOnTrack)",
                    total: viewModel.totalActiveGoals,
                    icon: "target",
                    color: .green
                )
                
                ProgressStatCard(
                    title: "Ahead",
                    value: "\(viewModel.goalsAhead)",
                    total: viewModel.totalActiveGoals,
                    icon: "arrow.up.circle",
                    color: .blue
                )
                
                ProgressStatCard(
                    title: "Behind",
                    value: "\(viewModel.goalsBehind)",
                    total: viewModel.totalActiveGoals,
                    icon: "exclamationmark.triangle",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var timeframeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ProgressTimeframe.allCases, id: \.self) { timeframe in
                    TimeframeButton(
                        timeframe: timeframe,
                        isSelected: selectedTimeframe == timeframe
                    ) {
                        selectedTimeframe = timeframe
                        Task {
                            await viewModel.updateTimeframe(timeframe)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var activeGoalsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Active Goals")
                    .font(.headline)
                    .fontWeight(.semibold)
                Image(systemName: "flag.checkered")
                    .foregroundColor(.blue)
                Spacer()
                Text("\(viewModel.activeGoals.count) goals")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.activeGoals.isEmpty {
                EmptyGoalsProgressView()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.activeGoals) { goal in
                        GoalProgressCard(goal: goal) {
                            selectedGoal = goal
                            showingGoalDetail = true
                        } adjustAction: {
                            selectedGoal = goal
                            showingAdjustmentSheet = true
                        }
                    }
                }
            }
        }
    }
    
    private var progressPredictionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Progress Predictions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Image(systemName: "crystal.ball")
                    .foregroundColor(.purple)
                Spacer()
                Button("Details") {
                    showingPredictionDetail = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if let predictions = viewModel.progressPredictions {
                ProgressPredictionCard(predictions: predictions)
            } else {
                Text("Analyzing your progress patterns to generate predictions...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
    
    private var achievementTimelineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Achievement Timeline")
                    .font(.headline)
                    .fontWeight(.semibold)
                Image(systemName: "timeline.selection")
                    .foregroundColor(.green)
                Spacer()
                Button("View All") {
                    showingAchievementTimeline = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.upcomingAchievements.prefix(3)) { achievement in
                    UpcomingAchievementCard(achievement: achievement)
                }
            }
        }
    }
    
    private var goalRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("AI Recommendations")
                    .font(.headline)
                    .fontWeight(.semibold)
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Spacer()
            }
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.goalRecommendations.prefix(2)) { recommendation in
                    GoalRecommendationCard(recommendation: recommendation)
                }
            }
        }
    }
    
    private var crossSourceIntegrationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Data Sources")
                    .font(.headline)
                    .fontWeight(.semibold)
                Image(systemName: "link")
                    .foregroundColor(.blue)
                Spacer()
                Text("\(viewModel.connectedSources.count) connected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(viewModel.connectedSources) { source in
                    DataSourceCard(source: source)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ProgressStatCard: View {
    let title: String
    let value: String
    let total: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if total > 0 {
                Text("of \(total)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct TimeframeButton: View {
    let timeframe: ProgressTimeframe
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(timeframe.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct GoalProgressCard: View {
    let goal: GoalProgress
    let action: () -> Void
    let adjustAction: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(goal.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.leading)
                        
                        Text(goal.category.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(goal.category.color.opacity(0.2))
                            .foregroundColor(goal.category.color)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        ProgressStatusIndicator(status: goal.status)
                        
                        Button("Adjust") {
                            adjustAction()
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                }
                
                // Progress Visualization
                ProgressVisualization(goal: goal)
                
                // Key Metrics
                HStack {
                    MetricDisplay(
                        title: "Current",
                        value: String(format: "%.1f", goal.currentValue),
                        unit: goal.unit
                    )
                    
                    Spacer()
                    
                    MetricDisplay(
                        title: "Target",
                        value: String(format: "%.1f", goal.targetValue),
                        unit: goal.unit
                    )
                    
                    Spacer()
                    
                    MetricDisplay(
                        title: "Progress",
                        value: "\(Int(goal.progressPercentage * 100))%",
                        unit: ""
                    )
                }
                
                // Timeline and Prediction
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Timeline")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(goal.daysElapsed)/\(goal.totalDays) days")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    if let completion = goal.projectedCompletion {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Projected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(completion, style: .date)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(goal.status == .onTrack ? .green : .orange)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProgressVisualization: View {
    let goal: GoalProgress
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(goal.status.color)
                        .frame(width: geometry.size.width * goal.progressPercentage, height: 8)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 0.5), value: goal.progressPercentage)
                }
            }
            .frame(height: 8)
            
            // Mini Chart
            if !goal.progressHistory.isEmpty {
                ProgressMiniChart(history: goal.progressHistory)
                    .frame(height: 60)
            }
        }
    }
}

struct ProgressMiniChart: View {
    let history: [ProgressDataPoint]
    
    var body: some View {
        Chart(history) { dataPoint in
            LineMark(
                x: .value("Day", dataPoint.day),
                y: .value("Progress", dataPoint.value)
            )
            .foregroundStyle(.blue)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            AreaMark(
                x: .value("Day", dataPoint.day),
                y: .value("Progress", dataPoint.value)
            )
            .foregroundStyle(.blue.opacity(0.1))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

struct ProgressPredictionCard: View {
    let predictions: ProgressPredictions
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "crystal.ball")
                    .foregroundColor(.purple)
                Text("AI Predictions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(Int(predictions.confidence * 100))% confidence")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            
            Text(predictions.summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(predictions.goalPredictions.prefix(4)) { prediction in
                    PredictionCard(prediction: prediction)
                }
            }
            
            if !predictions.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommendations:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(predictions.recommendations.prefix(2), id: \.self) { recommendation in
                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(recommendation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
}

struct PredictionCard: View {
    let prediction: GoalPrediction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(prediction.goalTitle)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            HStack {
                Text(prediction.outcome)
                    .font(.caption2)
                    .foregroundColor(prediction.isPositive ? .green : .orange)
                
                Spacer()
                
                Text(prediction.timeframe)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Confidence indicator
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 2)
                        .cornerRadius(1)
                    
                    Rectangle()
                        .fill(prediction.isPositive ? Color.green : Color.orange)
                        .frame(width: geometry.size.width * prediction.confidence, height: 2)
                        .cornerRadius(1)
                }
            }
            .frame(height: 2)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
}

struct UpcomingAchievementCard: View {
    let achievement: UpcomingAchievement
    
    var body: some View {
        HStack(spacing: 12) {
            // Achievement Icon
            ZStack {
                Circle()
                    .fill(achievement.badgeLevel.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: achievement.icon)
                    .foregroundColor(achievement.badgeLevel.color)
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(achievement.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text("Progress: \(Int(achievement.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("ETA: \(achievement.estimatedDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Progress Circle
            CircularProgressView(
                progress: achievement.progress,
                color: achievement.badgeLevel.color
            )
            .frame(width: 30, height: 30)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct GoalRecommendationCard: View {
    let recommendation: GoalAdjustmentRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                Text(recommendation.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text(recommendation.priority.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(recommendation.priority.color.opacity(0.2))
                    .foregroundColor(recommendation.priority.color)
                    .cornerRadius(4)
            }
            
            Text(recommendation.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(recommendation.reasoning)
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
            
            HStack {
                Text("Impact: \(recommendation.expectedImpact)")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Spacer()
                
                Text("Confidence: \(Int(recommendation.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
}

struct DataSourceCard: View {
    let source: ConnectedDataSource
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: source.icon)
                    .foregroundColor(source.isActive ? .green : .gray)
                    .font(.title3)
                
                Spacer()
                
                Circle()
                    .fill(source.isActive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(source.name)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("Last sync: \(source.lastSync, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct MetricDisplay: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct ProgressStatusIndicator: View {
    let status: GoalStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            
            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(status.color)
        }
    }
}

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.3), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
    }
}

struct EmptyGoalsProgressView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Active Goals")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Set some goals to start tracking your progress and see AI-powered insights!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Supporting Types

// ProgressTimeframe is already defined in AdvancedAIModels.swift - removed duplicate

enum GoalStatus: String, CaseIterable {
    case onTrack = "on_track"
    case ahead = "ahead"
    case behind = "behind"
    case completed = "completed"
    case paused = "paused"
    
    var displayName: String {
        switch self {
        case .onTrack: return "On Track"
        case .ahead: return "Ahead"
        case .behind: return "Behind"
        case .completed: return "Completed"
        case .paused: return "Paused"
        }
    }
    
    var color: Color {
        switch self {
        case .onTrack: return .green
        case .ahead: return .blue
        case .behind: return .orange
        case .completed: return .purple
        case .paused: return .gray
        }
    }
}

// MARK: - Preview

struct GoalProgressView_Previews: PreviewProvider {
    static var previews: some View {
        GoalProgressView()
    }
}

// MARK: - Missing View Components

struct GoalProgressDetailView: View {
    let goal: GoalProgress
    let viewModel: GoalProgressViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Goal Progress Details")
                        .font(.title2)
                        .bold()
                    
                    Text("Goal: \(goal.title)")
                        .font(.headline)
                    
                    Text("Progress: \(Int(goal.progressPercentage * 100))%")
                        .font(.subheadline)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Goal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct GoalAdjustmentRecommendationView: View {
    let goal: GoalProgress
    let viewModel: GoalProgressViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Goal Adjustment")
                    .font(.title2)
                    .bold()
                
                Text("Adjust settings for: \(goal.title)")
                    .font(.headline)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Adjustment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ProgressPredictionDetailView: View {
    let viewModel: GoalProgressViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Progress Predictions")
                    .font(.title2)
                    .bold()
                
                Text("AI predictions for your goals")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Predictions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct AchievementTimelineView: View {
    let viewModel: GoalProgressViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Achievement Timeline")
                    .font(.title2)
                    .bold()
                
                Text("Track your upcoming achievements")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
} 