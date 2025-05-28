import Foundation
import Combine

@MainActor
class GoalProgressViewModel: ObservableObject {
    @Published var activeGoals: [GoalProgress] = []
    @Published var progressPredictions: ProgressPredictions?
    @Published var upcomingAchievements: [UpcomingAchievement] = []
    @Published var goalRecommendations: [GoalAdjustmentRecommendation] = []
    @Published var connectedSources: [ConnectedDataSource] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTimeframe: ProgressTimeframe = .week
    
    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Computed properties for progress stats
    var totalActiveGoals: Int {
        activeGoals.count
    }
    
    var goalsOnTrack: Int {
        activeGoals.filter { $0.status == .onTrack }.count
    }
    
    var goalsAhead: Int {
        activeGoals.filter { $0.status == .ahead }.count
    }
    
    var goalsBehind: Int {
        activeGoals.filter { $0.status == .behind }.count
    }
    
    var overallProgressPercentage: Double {
        guard !activeGoals.isEmpty else { return 0.0 }
        let totalProgress = activeGoals.reduce(0.0) { $0 + $1.progressPercentage }
        return totalProgress / Double(activeGoals.count)
    }
    
    init() {
        setupMockData()
    }
    
    func loadInitialData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let goals = fetchActiveGoals()
            async let predictions = fetchProgressPredictions()
            async let achievements = fetchUpcomingAchievements()
            async let recommendations = fetchGoalRecommendations()
            async let sources = fetchConnectedSources()
            
            let (fetchedGoals, fetchedPredictions, fetchedAchievements, fetchedRecommendations, fetchedSources) = try await (goals, predictions, achievements, recommendations, sources)
            
            self.activeGoals = fetchedGoals
            self.progressPredictions = fetchedPredictions
            self.upcomingAchievements = fetchedAchievements
            self.goalRecommendations = fetchedRecommendations
            self.connectedSources = fetchedSources
            
        } catch {
            self.errorMessage = "Failed to load goal progress data: \(error.localizedDescription)"
            print("Error loading goal progress data: \(error)")
        }
        
        isLoading = false
    }
    
    func refreshData() async {
        await loadInitialData()
    }
    
    func updateTimeframe(_ timeframe: ProgressTimeframe) async {
        selectedTimeframe = timeframe
        // In a real implementation, this would fetch data for the new timeframe
        await refreshData()
    }
    
    func adjustGoal(_ goalId: String, adjustment: GoalAdjustment) async throws {
        let endpoint = "/ai/goals/\(goalId)/adjust"
        let requestBody = [
            "adjustment_type": adjustment.adjustmentType.rawValue,
            "new_target": adjustment.newTarget,
            "new_timeline": adjustment.newTimeline?.timeIntervalSince1970,
            "reasoning": adjustment.reasoning
        ]
        
        let updatedGoal: GoalProgress = try await networkManager.request(
            endpoint: endpoint,
            method: .PUT,
            body: requestBody
        )
        
        // Update local goal
        if let index = activeGoals.firstIndex(where: { $0.id == goalId }) {
            activeGoals[index] = updatedGoal
        }
    }
    
    func pauseGoal(_ goalId: String) async throws {
        let endpoint = "/ai/goals/\(goalId)/pause"
        let _: GoalProgress = try await networkManager.request(
            endpoint: endpoint,
            method: .POST
        )
        
        // Update local goal status
        if let index = activeGoals.firstIndex(where: { $0.id == goalId }) {
            activeGoals[index].status = .paused
        }
    }
    
    func resumeGoal(_ goalId: String) async throws {
        let endpoint = "/ai/goals/\(goalId)/resume"
        let _: GoalProgress = try await networkManager.request(
            endpoint: endpoint,
            method: .POST
        )
        
        // Update local goal status
        if let index = activeGoals.firstIndex(where: { $0.id == goalId }) {
            activeGoals[index].status = .onTrack
        }
    }
    
    // MARK: - API Calls
    
    private func fetchActiveGoals() async throws -> [GoalProgress] {
        let endpoint = "/ai/goals/progress"
        let response: GoalProgressResponse = try await networkManager.request(
            endpoint: endpoint,
            method: .GET
        )
        return response.goals
    }
    
    private func fetchProgressPredictions() async throws -> ProgressPredictions {
        let endpoint = "/ai/goals/predictions"
        let predictions: ProgressPredictions = try await networkManager.request(
            endpoint: endpoint,
            method: .GET
        )
        return predictions
    }
    
    private func fetchUpcomingAchievements() async throws -> [UpcomingAchievement] {
        let endpoint = "/ai/achievements/upcoming"
        let response: [UpcomingAchievement] = try await networkManager.request(
            endpoint: endpoint,
            method: .GET
        )
        return response
    }
    
    private func fetchGoalRecommendations() async throws -> [GoalAdjustmentRecommendation] {
        let endpoint = "/ai/goals/recommendations"
        let response: [GoalAdjustmentRecommendation] = try await networkManager.request(
            endpoint: endpoint,
            method: .GET
        )
        return response
    }
    
    private func fetchConnectedSources() async throws -> [ConnectedDataSource] {
        let endpoint = "/data-sources/connected"
        let response: [ConnectedDataSource] = try await networkManager.request(
            endpoint: endpoint,
            method: .GET
        )
        return response
    }
    
    // MARK: - Mock Data Setup
    
    private func setupMockData() {
        activeGoals = createMockActiveGoals()
        progressPredictions = createMockProgressPredictions()
        upcomingAchievements = createMockUpcomingAchievements()
        goalRecommendations = createMockGoalRecommendations()
        connectedSources = createMockConnectedSources()
    }
    
    private func createMockActiveGoals() -> [GoalProgress] {
        return [
            GoalProgress(
                id: "goal_1",
                title: "Daily Steps Goal",
                description: "Walk 10,000 steps every day",
                category: .activity,
                currentValue: 8750,
                targetValue: 10000,
                unit: "steps",
                startDate: Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 16, to: Date()) ?? Date(),
                status: .onTrack,
                progressHistory: generateProgressHistory(days: 14, trend: .improving),
                dataSources: ["Apple Health", "Strava"],
                projectedCompletion: Calendar.current.date(byAdding: .day, value: 15, to: Date())
            ),
            
            GoalProgress(
                id: "goal_2",
                title: "Sleep Duration",
                description: "Get 8 hours of sleep nightly",
                category: .sleep,
                currentValue: 7.2,
                targetValue: 8.0,
                unit: "hours",
                startDate: Calendar.current.date(byAdding: .day, value: -21, to: Date()) ?? Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 9, to: Date()) ?? Date(),
                status: .behind,
                progressHistory: generateProgressHistory(days: 21, trend: .declining),
                dataSources: ["Oura Ring", "Apple Health"],
                projectedCompletion: Calendar.current.date(byAdding: .day, value: 18, to: Date())
            ),
            
            GoalProgress(
                id: "goal_3",
                title: "Water Intake",
                description: "Drink 2.5L of water daily",
                category: .nutrition,
                currentValue: 2.8,
                targetValue: 2.5,
                unit: "L",
                startDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 20, to: Date()) ?? Date(),
                status: .ahead,
                progressHistory: generateProgressHistory(days: 10, trend: .improving),
                dataSources: ["Manual Entry", "Apple Health"],
                projectedCompletion: Calendar.current.date(byAdding: .day, value: 12, to: Date())
            ),
            
            GoalProgress(
                id: "goal_4",
                title: "Weight Loss",
                description: "Lose 5kg in 3 months",
                category: .bodyComposition,
                currentValue: 2.3,
                targetValue: 5.0,
                unit: "kg",
                startDate: Calendar.current.date(byAdding: .day, value: -45, to: Date()) ?? Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 45, to: Date()) ?? Date(),
                status: .onTrack,
                progressHistory: generateProgressHistory(days: 45, trend: .steady),
                dataSources: ["Withings Scale", "Apple Health"],
                projectedCompletion: Calendar.current.date(byAdding: .day, value: 48, to: Date())
            ),
            
            GoalProgress(
                id: "goal_5",
                title: "Resting Heart Rate",
                description: "Lower RHR to 55 bpm",
                category: .activity,
                currentValue: 58,
                targetValue: 55,
                unit: "bpm",
                startDate: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date(),
                status: .onTrack,
                progressHistory: generateProgressHistory(days: 30, trend: .improving),
                dataSources: ["WHOOP", "Apple Health"],
                projectedCompletion: Calendar.current.date(byAdding: .day, value: 25, to: Date())
            )
        ]
    }
    
    private func createMockProgressPredictions() -> ProgressPredictions {
        return ProgressPredictions(
            id: "pred_1",
            generatedDate: Date(),
            timeframe: "Next 30 days",
            summary: "Based on your current patterns, you're likely to achieve 4 out of 5 active goals. Your sleep goal needs attention to stay on track.",
            confidence: 0.87,
            goalPredictions: [
                GoalPrediction(
                    id: "pred_goal_1",
                    goalId: "goal_1",
                    goalTitle: "Daily Steps",
                    outcome: "Will achieve",
                    confidence: 0.92,
                    timeframe: "15 days",
                    isPositive: true,
                    reasoning: "Consistent daily progress with improving trend"
                ),
                GoalPrediction(
                    id: "pred_goal_2",
                    goalId: "goal_2",
                    goalTitle: "Sleep Duration",
                    outcome: "At risk",
                    confidence: 0.68,
                    timeframe: "18 days",
                    isPositive: false,
                    reasoning: "Declining sleep quality and inconsistent bedtime"
                ),
                GoalPrediction(
                    id: "pred_goal_3",
                    goalId: "goal_3",
                    goalTitle: "Water Intake",
                    outcome: "Will exceed",
                    confidence: 0.95,
                    timeframe: "12 days",
                    isPositive: true,
                    reasoning: "Already exceeding target with strong habit formation"
                ),
                GoalPrediction(
                    id: "pred_goal_4",
                    goalId: "goal_4",
                    goalTitle: "Weight Loss",
                    outcome: "On track",
                    confidence: 0.81,
                    timeframe: "48 days",
                    isPositive: true,
                    reasoning: "Steady progress with sustainable rate of loss"
                )
            ],
            recommendations: [
                "Focus on sleep optimization to improve overall health outcomes",
                "Consider increasing step goal as current target is being consistently exceeded",
                "Maintain current hydration habits - they're working well",
                "Weight loss is progressing well, continue current approach"
            ],
            riskFactors: [
                "Sleep inconsistency may impact recovery and other goals",
                "Weekend activity levels tend to drop significantly"
            ]
        )
    }
    
    private func createMockUpcomingAchievements() -> [UpcomingAchievement] {
        return [
            UpcomingAchievement(
                id: "ach_1",
                title: "Step Streak Master",
                description: "Reach 10,000 steps for 30 consecutive days",
                badgeLevel: .gold,
                icon: "figure.walk",
                progress: 0.73,
                estimatedDate: Calendar.current.date(byAdding: .day, value: 8, to: Date()) ?? Date(),
                category: .activity,
                requirements: "8 more days of 10K+ steps"
            ),
            
            UpcomingAchievement(
                id: "ach_2",
                title: "Hydration Hero",
                description: "Meet daily water intake goal for 21 days",
                badgeLevel: .silver,
                icon: "drop.fill",
                progress: 0.86,
                estimatedDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
                category: .nutrition,
                requirements: "3 more days of 2.5L+ water"
            ),
            
            UpcomingAchievement(
                id: "ach_3",
                title: "Weight Loss Milestone",
                description: "Lose 5kg through healthy habits",
                badgeLevel: .platinum,
                icon: "scalemass",
                progress: 0.46,
                estimatedDate: Calendar.current.date(byAdding: .day, value: 48, to: Date()) ?? Date(),
                category: .bodyComposition,
                requirements: "2.7kg more to reach target"
            ),
            
            UpcomingAchievement(
                id: "ach_4",
                title: "Heart Health Champion",
                description: "Improve resting heart rate by 10 bpm",
                badgeLevel: .gold,
                icon: "heart.fill",
                progress: 0.70,
                estimatedDate: Calendar.current.date(byAdding: .day, value: 25, to: Date()) ?? Date(),
                category: .activity,
                requirements: "3 more bpm improvement needed"
            ),
            
            UpcomingAchievement(
                id: "ach_5",
                title: "Sleep Quality Expert",
                description: "Achieve 85%+ sleep efficiency for 14 days",
                badgeLevel: .bronze,
                icon: "bed.double.fill",
                progress: 0.29,
                estimatedDate: Calendar.current.date(byAdding: .day, value: 35, to: Date()) ?? Date(),
                category: .sleep,
                requirements: "10 more nights of quality sleep"
            )
        ]
    }
    
    private func createMockGoalRecommendations() -> [GoalAdjustmentRecommendation] {
        return [
            GoalAdjustmentRecommendation(
                id: "rec_1",
                goalId: "goal_2",
                title: "Optimize Sleep Goal Timeline",
                description: "Extend your sleep goal timeline by 2 weeks to allow for gradual habit formation and better success probability.",
                adjustmentType: .extendTimeline,
                currentTarget: 8.0,
                recommendedTarget: 8.0,
                currentTimeline: Calendar.current.date(byAdding: .day, value: 9, to: Date()),
                recommendedTimeline: Calendar.current.date(byAdding: .day, value: 23, to: Date()),
                reasoning: "Your current sleep patterns show improvement but need more time to stabilize. Extending the timeline reduces pressure and increases success likelihood.",
                expectedImpact: "Improved sleep quality and goal achievement probability",
                confidence: 0.84,
                priority: .high,
                dataSources: ["Oura Ring", "Apple Health"]
            ),
            
            GoalAdjustmentRecommendation(
                id: "rec_2",
                goalId: "goal_1",
                title: "Increase Step Target",
                description: "You're consistently exceeding your current step goal. Consider increasing to 12,000 steps for continued challenge and improvement.",
                adjustmentType: .increaseTarget,
                currentTarget: 10000,
                recommendedTarget: 12000,
                currentTimeline: Calendar.current.date(byAdding: .day, value: 16, to: Date()),
                recommendedTimeline: Calendar.current.date(byAdding: .day, value: 16, to: Date()),
                reasoning: "Your average daily steps (8,750) plus weekend activity suggests you can handle a higher target. This will maintain motivation and drive further improvement.",
                expectedImpact: "Enhanced cardiovascular fitness and continued progress",
                confidence: 0.91,
                priority: .medium,
                dataSources: ["Apple Health", "Strava"]
            ),
            
            GoalAdjustmentRecommendation(
                id: "rec_3",
                goalId: "goal_4",
                title: "Maintain Current Approach",
                description: "Your weight loss is progressing at an optimal rate. No adjustments needed - continue current strategy.",
                adjustmentType: .maintainCurrent,
                currentTarget: 5.0,
                recommendedTarget: 5.0,
                currentTimeline: Calendar.current.date(byAdding: .day, value: 45, to: Date()),
                recommendedTimeline: Calendar.current.date(byAdding: .day, value: 45, to: Date()),
                reasoning: "Losing 2.3kg in 45 days represents a healthy, sustainable rate. Maintaining this approach will lead to long-term success.",
                expectedImpact: "Sustainable weight loss and habit formation",
                confidence: 0.88,
                priority: .low,
                dataSources: ["Withings Scale", "Apple Health"]
            )
        ]
    }
    
    private func createMockConnectedSources() -> [ConnectedDataSource] {
        return [
            ConnectedDataSource(
                id: "source_1",
                name: "Apple Health",
                icon: "heart.fill",
                isActive: true,
                lastSync: Calendar.current.date(byAdding: .minute, value: -15, to: Date()) ?? Date(),
                dataTypes: ["Steps", "Heart Rate", "Sleep", "Weight"],
                syncFrequency: "Real-time"
            ),
            
            ConnectedDataSource(
                id: "source_2",
                name: "Oura Ring",
                icon: "circle",
                isActive: true,
                lastSync: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
                dataTypes: ["Sleep", "HRV", "Temperature", "Activity"],
                syncFrequency: "Hourly"
            ),
            
            ConnectedDataSource(
                id: "source_3",
                name: "Withings Scale",
                icon: "scalemass",
                isActive: true,
                lastSync: Calendar.current.date(byAdding: .hour, value: -8, to: Date()) ?? Date(),
                dataTypes: ["Weight", "Body Fat", "Muscle Mass", "BMI"],
                syncFrequency: "Daily"
            ),
            
            ConnectedDataSource(
                id: "source_4",
                name: "Strava",
                icon: "figure.run",
                isActive: true,
                lastSync: Calendar.current.date(byAdding: .hour, value: -4, to: Date()) ?? Date(),
                dataTypes: ["Activities", "Distance", "Pace", "Elevation"],
                syncFrequency: "After workouts"
            ),
            
            ConnectedDataSource(
                id: "source_5",
                name: "WHOOP",
                icon: "waveform.path.ecg",
                isActive: false,
                lastSync: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                dataTypes: ["HRV", "Strain", "Recovery", "Sleep"],
                syncFrequency: "Continuous"
            ),
            
            ConnectedDataSource(
                id: "source_6",
                name: "FatSecret",
                icon: "fork.knife",
                isActive: true,
                lastSync: Calendar.current.date(byAdding: .hour, value: -6, to: Date()) ?? Date(),
                dataTypes: ["Calories", "Macros", "Food Log", "Nutrition"],
                syncFrequency: "Manual"
            )
        ]
    }
    
    private func generateProgressHistory(days: Int, trend: ProgressTrend) -> [ProgressDataPoint] {
        var history: [ProgressDataPoint] = []
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        for i in 0..<days {
            let date = Calendar.current.date(byAdding: .day, value: i, to: startDate) ?? Date()
            let day = i + 1
            
            var value: Double
            switch trend {
            case .improving:
                value = Double(i) / Double(days) * 0.8 + 0.1 + Double.random(in: -0.1...0.1)
            case .declining:
                value = 0.9 - (Double(i) / Double(days) * 0.4) + Double.random(in: -0.1...0.1)
            case .steady:
                value = 0.5 + Double.random(in: -0.2...0.2)
            }
            
            value = max(0.0, min(1.0, value)) // Clamp between 0 and 1
            
            history.append(ProgressDataPoint(
                id: "point_\(i)",
                day: day,
                date: date,
                value: value
            ))
        }
        
        return history
    }
}

// MARK: - Supporting Data Models

struct GoalProgress: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let category: GoalCategory
    let currentValue: Double
    let targetValue: Double
    let unit: String
    let startDate: Date
    let endDate: Date
    var status: GoalStatus
    let progressHistory: [ProgressDataPoint]
    let dataSources: [String]
    let projectedCompletion: Date?
    
    var progressPercentage: Double {
        guard targetValue > 0 else { return 0.0 }
        return min(1.0, max(0.0, currentValue / targetValue))
    }
    
    var daysElapsed: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
    }
    
    var totalDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, category, unit, status
        case currentValue = "current_value"
        case targetValue = "target_value"
        case startDate = "start_date"
        case endDate = "end_date"
        case progressHistory = "progress_history"
        case dataSources = "data_sources"
        case projectedCompletion = "projected_completion"
    }
}

struct ProgressDataPoint: Identifiable, Codable {
    let id: String
    let day: Int
    let date: Date
    let value: Double
}

struct ProgressPredictions: Identifiable, Codable {
    let id: String
    let generatedDate: Date
    let timeframe: String
    let summary: String
    let confidence: Double
    let goalPredictions: [GoalPrediction]
    let recommendations: [String]
    let riskFactors: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, timeframe, summary, confidence, recommendations
        case generatedDate = "generated_date"
        case goalPredictions = "goal_predictions"
        case riskFactors = "risk_factors"
    }
}

struct GoalPrediction: Identifiable, Codable {
    let id: String
    let goalId: String
    let goalTitle: String
    let outcome: String
    let confidence: Double
    let timeframe: String
    let isPositive: Bool
    let reasoning: String
    
    enum CodingKeys: String, CodingKey {
        case id, outcome, confidence, timeframe, reasoning
        case goalId = "goal_id"
        case goalTitle = "goal_title"
        case isPositive = "is_positive"
    }
}

struct UpcomingAchievement: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let badgeLevel: BadgeLevel
    let icon: String
    let progress: Double
    let estimatedDate: Date
    let category: GoalCategory
    let requirements: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, icon, progress, category, requirements
        case badgeLevel = "badge_level"
        case estimatedDate = "estimated_date"
    }
}

struct GoalAdjustmentRecommendation: Identifiable, Codable {
    let id: String
    let goalId: String
    let title: String
    let description: String
    let adjustmentType: GoalAdjustmentType
    let currentTarget: Double
    let recommendedTarget: Double
    let currentTimeline: Date?
    let recommendedTimeline: Date?
    let reasoning: String
    let expectedImpact: String
    let confidence: Double
    let priority: RecommendationPriority
    let dataSources: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, reasoning, confidence, priority
        case goalId = "goal_id"
        case adjustmentType = "adjustment_type"
        case currentTarget = "current_target"
        case recommendedTarget = "recommended_target"
        case currentTimeline = "current_timeline"
        case recommendedTimeline = "recommended_timeline"
        case expectedImpact = "expected_impact"
        case dataSources = "data_sources"
    }
}

struct ConnectedDataSource: Identifiable, Codable {
    let id: String
    let name: String
    let icon: String
    let isActive: Bool
    let lastSync: Date
    let dataTypes: [String]
    let syncFrequency: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, icon, syncFrequency
        case isActive = "is_active"
        case lastSync = "last_sync"
        case dataTypes = "data_types"
    }
}

enum ProgressTrend {
    case improving
    case declining
    case steady
}

enum GoalAdjustmentType: String, Codable {
    case increaseTarget = "increase_target"
    case decreaseTarget = "decrease_target"
    case extendTimeline = "extend_timeline"
    case shortenTimeline = "shorten_timeline"
    case maintainCurrent = "maintain_current"
    
    var displayName: String {
        switch self {
        case .increaseTarget: return "Increase Target"
        case .decreaseTarget: return "Decrease Target"
        case .extendTimeline: return "Extend Timeline"
        case .shortenTimeline: return "Shorten Timeline"
        case .maintainCurrent: return "Maintain Current"
        }
    }
}

enum RecommendationPriority: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Response Models

struct GoalProgressResponse: Codable {
    let goals: [GoalProgress]
    let totalCount: Int
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case goals
        case totalCount = "total_count"
        case lastUpdated = "last_updated"
    }
}

struct CoachingMessagesResponse: Codable {
    let messages: [CoachingMessage]
    let totalCount: Int
    let unreadCount: Int
    
    enum CodingKeys: String, CodingKey {
        case messages
        case totalCount = "total_count"
        case unreadCount = "unread_count"
    }
}

// MARK: - Extensions

extension Color {
    static let systemGray6 = Color(.systemGray6)
    static let systemBackground = Color(.systemBackground)
} 