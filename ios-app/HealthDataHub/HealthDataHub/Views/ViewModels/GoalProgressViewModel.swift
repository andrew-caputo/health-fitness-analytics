import Foundation
import SwiftUI
import Combine

@MainActor
class GoalProgressViewModel: ObservableObject {
    @Published var goals: [GoalProgress] = []
    @Published var predictions: ProgressPredictions?
    @Published var upcomingAchievements: [UpcomingAchievement] = []
    @Published var adjustmentRecommendations: [GoalAdjustmentRecommendation] = []
    @Published var connectedDataSources: [ConnectedDataSource] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTimeframe: String = "30_days"
    @Published var selectedGoalCategory: GoalCategory = .all
    @Published var showingGoalDetail = false
    @Published var selectedGoal: GoalProgress?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadMockData()
    }
    
    // MARK: - Missing Computed Properties (mapped to existing data)
    
    var activeGoals: [GoalProgress] {
        return goals.filter { !["completed", "paused"].contains($0.recentTrend) }
    }
    
    var goalsOnTrack: Int {
        return goals.filter { $0.onTrack }.count
    }
    
    var totalActiveGoals: Int {
        return activeGoals.count
    }
    
    var goalsAhead: Int {
        return goals.filter { $0.progressPercentage > 1.0 }.count
    }
    
    var goalsBehind: Int {
        return goals.filter { !$0.onTrack && $0.progressPercentage < 1.0 }.count
    }
    
    var progressPredictions: ProgressPredictions? {
        return predictions
    }
    
    var goalRecommendations: [GoalAdjustmentRecommendation] {
        return adjustmentRecommendations
    }
    
    var connectedSources: [ConnectedDataSource] {
        return connectedDataSources
    }
    
    // MARK: - Missing Methods
    
    func loadInitialData() async {
        await MainActor.run {
            isLoading = true
        }
        
        // Simulate async loading
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            loadMockData()
            isLoading = false
        }
    }
    
    func refreshData() async {
        await loadInitialData()
    }
    
    func updateTimeframe(_ timeframe: ProgressTimeframe) async {
        await MainActor.run {
            selectedTimeframe = timeframe.rawValue
            // In a real app, this would filter/reload data based on timeframe
        }
    }
    
    // MARK: - Existing Methods
    
    func loadGoalData() {
        isLoading = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            // Data would be loaded from API here
        }
    }
    
    func filterGoals(by category: GoalCategory) {
        selectedGoalCategory = category
    }
    
    func updateGoalProgress(_ goalId: String, newValue: Double) {
        if let index = goals.firstIndex(where: { $0.goalId == goalId }) {
            var updatedGoal = goals[index]
            updatedGoal = GoalProgress(
                goalId: updatedGoal.goalId,
                currentValue: newValue,
                targetValue: updatedGoal.targetValue,
                progressPercentage: min(1.0, newValue / updatedGoal.targetValue),
                daysElapsed: updatedGoal.daysElapsed,
                totalTimeline: updatedGoal.totalTimeline,
                onTrack: newValue >= (updatedGoal.targetValue * 0.8),
                projectedCompletion: updatedGoal.projectedCompletion,
                recentTrend: newValue > updatedGoal.currentValue ? "improving" : "declining",
                motivationLevel: updatedGoal.motivationLevel
            )
            goals[index] = updatedGoal
        }
    }
    
    func getFilteredGoals() -> [GoalProgress] {
        return goals
    }
    
    var activeGoalsCount: Int {
        goals.filter { !["completed", "paused"].contains($0.recentTrend) }.count
    }
    
    var completedGoalsCount: Int {
        goals.filter { $0.progressPercentage >= 1.0 }.count
    }
    
    var averageProgress: Double {
        guard !goals.isEmpty else { return 0.0 }
        let total = goals.reduce(0.0) { $0 + $1.progressPercentage }
        return total / Double(goals.count)
    }
    
    // MARK: - Mock Data
    
    private func loadMockData() {
        // Mock goals data
        goals = [
            GoalProgress(
                goalId: "goal_1",
                currentValue: 8500,
                targetValue: 10000,
                progressPercentage: 0.85,
                daysElapsed: 15,
                totalTimeline: 30,
                onTrack: true,
                projectedCompletion: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
                recentTrend: "improving",
                motivationLevel: "high"
            ),
            GoalProgress(
                goalId: "goal_2",
                currentValue: 6.8,
                targetValue: 8.0,
                progressPercentage: 0.85,
                daysElapsed: 12,
                totalTimeline: 21,
                onTrack: true,
                projectedCompletion: Calendar.current.date(byAdding: .day, value: 4, to: Date()),
                recentTrend: "steady",
                motivationLevel: "medium"
            ),
            GoalProgress(
                goalId: "goal_3",
                currentValue: 145.2,
                targetValue: 140.0,
                progressPercentage: 1.04,
                daysElapsed: 28,
                totalTimeline: 60,
                onTrack: true,
                projectedCompletion: nil,
                recentTrend: "completed",
                motivationLevel: "high"
            )
        ]
        
        // Mock upcoming achievements
        upcomingAchievements = [
            UpcomingAchievement(
                id: "ach_1",
                title: "Step Master",
                description: "Complete 10,000 steps daily for 7 consecutive days",
                badgeLevel: .silver,
                icon: "figure.walk",
                progress: 0.86,
                estimatedDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date(),
                category: .activity,
                requirements: "2 more days of 10K+ steps"
            ),
            UpcomingAchievement(
                id: "ach_2",
                title: "Sleep Champion",
                description: "Achieve optimal sleep duration for 30 days",
                badgeLevel: .gold,
                icon: "bed.double",
                progress: 0.73,
                estimatedDate: Calendar.current.date(byAdding: .day, value: 8, to: Date()) ?? Date(),
                category: .sleep,
                requirements: "8 more nights of quality sleep"
            )
        ]
        
        // Mock adjustment recommendations
        adjustmentRecommendations = [
            GoalAdjustmentRecommendation(
                id: "rec_1",
                goalId: "goal_1",
                title: "Increase Step Target",
                description: "You're consistently exceeding your step goal. Consider raising the target for continued growth.",
                adjustmentType: .increaseTarget,
                currentTarget: 10000,
                recommendedTarget: 12000,
                currentTimeline: nil,
                recommendedTimeline: nil,
                reasoning: "Your recent performance shows 15% above target consistently",
                expectedImpact: "Improved cardiovascular fitness and calorie burn",
                confidence: 0.85,
                priority: .medium,
                dataSources: ["Apple Health", "Strava"]
            )
        ]
        
        // Mock connected data sources
        connectedDataSources = [
            ConnectedDataSource(
                id: "src_1",
                name: "Apple Health",
                icon: "heart.fill",
                isActive: true,
                lastSync: Date(),
                dataTypes: ["Steps", "Heart Rate", "Sleep"],
                syncFrequency: "Real-time"
            ),
            ConnectedDataSource(
                id: "src_2",
                name: "Strava",
                icon: "figure.run",
                isActive: true,
                lastSync: Calendar.current.date(byAdding: .minute, value: -15, to: Date()) ?? Date(),
                dataTypes: ["Workouts", "Distance", "Pace"],
                syncFrequency: "Every 15 minutes"
            )
        ]
        
        // Mock predictions
        predictions = ProgressPredictions(
            id: "pred_1",
            generatedDate: Date(),
            timeframe: "Next 30 days",
            summary: "Based on current trends, you're likely to exceed your step goal and sleep target.",
            confidence: 0.82,
            goalPredictions: [
                GoalPrediction(
                    id: "gpred_1",
                    goalId: "goal_1",
                    goalTitle: "Daily Steps",
                    outcome: "likely_success",
                    confidence: 0.88,
                    timeframe: "Next 7 days",
                    isPositive: true,
                    reasoning: "Your current pace is 15% above target with consistent daily activity"
                )
            ],
            recommendations: ["Continue your current pace", "Consider increasing target"],
            riskFactors: []
        )
    }
    
    // Additional helper methods
    func createProgressHistory(for goal: GoalProgress) -> [ProgressDataPoint] {
        var history: [ProgressDataPoint] = []
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        for i in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                let baseValue = goal.currentValue * 0.7
                let variation = Double.random(in: 0.8...1.2)
                let trendFactor = Double(i) / 30.0 * 0.3 // Gradual improvement
                let value = baseValue * variation + (goal.currentValue * trendFactor)
                
                history.append(ProgressDataPoint(
                    id: "point_\(i)",
                    day: i + 1,
                    date: date,
                    value: value
                ))
            }
        }
        
        return history
    }
} 