import Foundation
import Combine

@MainActor
class PersonalizedGoalsViewModel: ObservableObject {
    @Published var goalRecommendations: [GoalRecommendation] = []
    @Published var filteredRecommendations: [GoalRecommendation] = []
    @Published var activeGoals: [GoalRecommendation] = []
    @Published var goalCoordinations: [GoalCoordination] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Computed properties
    var averageSuccessProbability: Double? {
        guard !filteredRecommendations.isEmpty else { return nil }
        let total = filteredRecommendations.reduce(0) { $0 + $1.successProbability }
        return total / Double(filteredRecommendations.count)
    }
    
    init() {
        setupMockData()
    }
    
    func loadInitialData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let recommendations = fetchGoalRecommendations()
            async let coordinations = fetchGoalCoordinations()
            
            let (fetchedRecommendations, fetchedCoordinations) = try await (recommendations, coordinations)
            
            self.goalRecommendations = fetchedRecommendations
            self.filteredRecommendations = fetchedRecommendations
            self.goalCoordinations = fetchedCoordinations
            
            // Simulate some active goals
            self.activeGoals = Array(fetchedRecommendations.prefix(2))
            
        } catch {
            self.errorMessage = "Failed to load goal data: \(error.localizedDescription)"
            print("Error loading goals: \(error)")
        }
        
        isLoading = false
    }
    
    func refreshData() async {
        await loadInitialData()
    }
    
    func filterByCategory(_ category: GoalCategory) async {
        filteredRecommendations = goalRecommendations.filter { $0.category == category }
    }
    
    func filterByDifficulty(_ difficulty: GoalDifficulty) async {
        filteredRecommendations = goalRecommendations.filter { $0.difficulty == difficulty }
    }
    
    func resetFilters() {
        filteredRecommendations = goalRecommendations
    }
    
    func activateGoal(_ goal: GoalRecommendation) {
        if !activeGoals.contains(where: { $0.id == goal.id }) {
            activeGoals.append(goal)
        }
    }
    
    func deactivateGoal(_ goalId: String) {
        activeGoals.removeAll { $0.id == goalId }
    }
    
    // MARK: - API Calls
    
    private func fetchGoalRecommendations() async throws -> [GoalRecommendation] {
        let endpoint = "/ai/goals/recommendations"
        let response: GoalRecommendationsResponse = try await networkManager.request(
            endpoint: endpoint,
            method: .GET
        )
        return response.recommendations
    }
    
    private func fetchGoalCoordinations() async throws -> [GoalCoordination] {
        let endpoint = "/ai/goals/coordinate"
        let response: [GoalCoordination] = try await networkManager.request(
            endpoint: endpoint,
            method: .GET
        )
        return response
    }
    
    func adjustGoal(_ goalId: String, newTarget: Double, reasoning: String) async throws -> GoalAdjustment {
        let endpoint = "/ai/goals/\(goalId)/adjust"
        let requestBody = [
            "new_target": newTarget,
            "reasoning": reasoning
        ]
        
        let adjustment: GoalAdjustment = try await networkManager.request(
            endpoint: endpoint,
            method: .POST,
            body: requestBody
        )
        
        // Update local goal if needed
        if let index = activeGoals.firstIndex(where: { $0.id == goalId }) {
            var updatedGoal = activeGoals[index]
            // Create a new goal with updated target (this would need proper model update)
            // For now, we'll just refresh the data
            await refreshData()
        }
        
        return adjustment
    }
    
    // MARK: - Mock Data Setup
    
    private func setupMockData() {
        goalRecommendations = createMockGoalRecommendations()
        filteredRecommendations = goalRecommendations
        activeGoals = Array(goalRecommendations.prefix(2))
        goalCoordinations = createMockGoalCoordinations()
    }
    
    private func createMockGoalRecommendations() -> [GoalRecommendation] {
        return [
            GoalRecommendation(
                id: "goal_1",
                category: .activity,
                goalType: .increase,
                title: "Increase Daily Steps",
                description: "Gradually increase your daily step count to improve cardiovascular health and energy levels.",
                targetValue: 10000,
                currentValue: 7500,
                unit: "steps",
                difficulty: .moderate,
                timelineDays: 30,
                confidenceScore: 0.85,
                reasoning: "Based on your current activity patterns and gradual improvement trend, this goal is achievable with consistent effort.",
                expectedBenefits: [
                    "Improved cardiovascular health",
                    "Increased energy levels",
                    "Better mood and mental clarity",
                    "Enhanced sleep quality"
                ],
                successProbability: 0.78,
                requiredActions: [
                    "Take stairs instead of elevators",
                    "Park further from destinations",
                    "Take walking breaks every hour",
                    "Use a step tracking app"
                ],
                relatedMetrics: ["heart_rate", "calories_burned", "active_minutes"],
                adjustmentTriggers: ["plateau_detected", "stress_increase", "schedule_change"]
            ),
            
            GoalRecommendation(
                id: "goal_2",
                category: .sleep,
                goalType: .achieve,
                title: "Optimize Sleep Duration",
                description: "Achieve consistent 7-8 hours of quality sleep to enhance recovery and cognitive performance.",
                targetValue: 8.0,
                currentValue: 6.5,
                unit: "hours",
                difficulty: .challenging,
                timelineDays: 21,
                confidenceScore: 0.72,
                reasoning: "Your sleep patterns show room for improvement. Consistent sleep schedule will significantly impact your health metrics.",
                expectedBenefits: [
                    "Enhanced cognitive performance",
                    "Better immune function",
                    "Improved mood stability",
                    "Faster muscle recovery"
                ],
                successProbability: 0.65,
                requiredActions: [
                    "Set consistent bedtime routine",
                    "Limit screen time before bed",
                    "Create optimal sleep environment",
                    "Track sleep quality metrics"
                ],
                relatedMetrics: ["sleep_quality", "resting_heart_rate", "hrv"],
                adjustmentTriggers: ["work_schedule_change", "stress_levels", "caffeine_intake"]
            ),
            
            GoalRecommendation(
                id: "goal_3",
                category: .nutrition,
                goalType: .increase,
                title: "Increase Water Intake",
                description: "Boost daily hydration to support metabolism, skin health, and cognitive function.",
                targetValue: 2.5,
                currentValue: 1.8,
                unit: "liters",
                difficulty: .easy,
                timelineDays: 14,
                confidenceScore: 0.92,
                reasoning: "Simple habit change with immediate benefits. Your current intake is below optimal levels.",
                expectedBenefits: [
                    "Improved skin health",
                    "Better digestion",
                    "Enhanced mental clarity",
                    "Increased energy levels"
                ],
                successProbability: 0.88,
                requiredActions: [
                    "Carry water bottle everywhere",
                    "Set hourly hydration reminders",
                    "Drink water before meals",
                    "Track intake with app"
                ],
                relatedMetrics: ["energy_levels", "skin_quality", "cognitive_performance"],
                adjustmentTriggers: ["exercise_increase", "climate_change", "illness"]
            ),
            
            GoalRecommendation(
                id: "goal_4",
                category: .heartHealth,
                goalType: .decrease,
                title: "Lower Resting Heart Rate",
                description: "Improve cardiovascular fitness by reducing resting heart rate through consistent training.",
                targetValue: 60,
                currentValue: 72,
                unit: "bpm",
                difficulty: .ambitious,
                timelineDays: 60,
                confidenceScore: 0.68,
                reasoning: "Requires consistent cardiovascular training but achievable with your current fitness level.",
                expectedBenefits: [
                    "Improved cardiovascular efficiency",
                    "Better exercise performance",
                    "Enhanced recovery capacity",
                    "Reduced health risks"
                ],
                successProbability: 0.58,
                requiredActions: [
                    "Regular cardio exercise",
                    "Monitor heart rate zones",
                    "Progressive training intensity",
                    "Adequate recovery time"
                ],
                relatedMetrics: ["exercise_intensity", "recovery_time", "hrv"],
                adjustmentTriggers: ["training_plateau", "overtraining", "lifestyle_stress"]
            ),
            
            GoalRecommendation(
                id: "goal_5",
                category: .bodyComposition,
                goalType: .decrease,
                title: "Reduce Body Fat Percentage",
                description: "Achieve healthier body composition through balanced nutrition and exercise.",
                targetValue: 15.0,
                currentValue: 18.5,
                unit: "%",
                difficulty: .challenging,
                timelineDays: 90,
                confidenceScore: 0.75,
                reasoning: "Sustainable fat loss requires consistent effort but your current habits show good foundation.",
                expectedBenefits: [
                    "Improved metabolic health",
                    "Enhanced physical performance",
                    "Better self-confidence",
                    "Reduced disease risk"
                ],
                successProbability: 0.62,
                requiredActions: [
                    "Maintain caloric deficit",
                    "Strength training routine",
                    "Track macronutrients",
                    "Regular body composition monitoring"
                ],
                relatedMetrics: ["weight", "muscle_mass", "metabolic_rate"],
                adjustmentTriggers: ["plateau_reached", "muscle_loss", "metabolic_adaptation"]
            ),
            
            GoalRecommendation(
                id: "goal_6",
                category: .wellness,
                goalType: .achieve,
                title: "Daily Mindfulness Practice",
                description: "Establish consistent meditation practice to reduce stress and improve mental well-being.",
                targetValue: 15,
                currentValue: 0,
                unit: "minutes",
                difficulty: .moderate,
                timelineDays: 28,
                confidenceScore: 0.80,
                reasoning: "Starting small with mindfulness can have significant impact on stress levels and overall well-being.",
                expectedBenefits: [
                    "Reduced stress levels",
                    "Improved emotional regulation",
                    "Better focus and concentration",
                    "Enhanced sleep quality"
                ],
                successProbability: 0.72,
                requiredActions: [
                    "Download meditation app",
                    "Set daily reminder",
                    "Start with 5-minute sessions",
                    "Track consistency"
                ],
                relatedMetrics: ["stress_levels", "mood", "sleep_quality"],
                adjustmentTriggers: ["time_constraints", "motivation_drop", "life_events"]
            )
        ]
    }
    
    private func createMockGoalCoordinations() -> [GoalCoordination] {
        return [
            GoalCoordination(
                primaryGoalId: "goal_1",
                relatedGoalIds: ["goal_2", "goal_6"],
                coordinationType: "synergistic",
                impactDescription: "Increasing daily steps works synergistically with better sleep and mindfulness practice. More activity improves sleep quality, while mindfulness reduces stress that can interfere with both exercise motivation and sleep.",
                optimizationSuggestions: [
                    "Schedule walks during natural energy peaks",
                    "Use walking as moving meditation",
                    "Avoid intense exercise 3 hours before bedtime",
                    "Track how activity affects sleep quality"
                ]
            ),
            
            GoalCoordination(
                primaryGoalId: "goal_4",
                relatedGoalIds: ["goal_1", "goal_5"],
                coordinationType: "complementary",
                impactDescription: "Cardiovascular improvements from increased steps and body composition changes work together to lower resting heart rate. Fat loss reduces cardiac workload while aerobic exercise strengthens the heart.",
                optimizationSuggestions: [
                    "Combine cardio with strength training",
                    "Monitor heart rate during activities",
                    "Ensure adequate protein for muscle preservation",
                    "Track progress across all three metrics"
                ]
            ),
            
            GoalCoordination(
                primaryGoalId: "goal_3",
                relatedGoalIds: ["goal_5", "goal_1"],
                coordinationType: "supportive",
                impactDescription: "Proper hydration supports both fat loss and exercise performance. Water intake aids metabolism and helps maintain energy levels during increased physical activity.",
                optimizationSuggestions: [
                    "Drink water before and after workouts",
                    "Monitor hydration during fat loss phases",
                    "Adjust intake based on activity levels",
                    "Use hydration to support appetite control"
                ]
            )
        ]
    }
}

// MARK: - Network Extensions

extension NetworkManager {
    func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod,
        body: [String: Any]? = nil
    ) async throws -> T {
        // This would integrate with the actual NetworkManager implementation
        // For now, we'll simulate network delay and return mock data
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // In a real implementation, this would make the actual network request
        // and decode the response into the expected type T
        
        throw NetworkError.notImplemented
    }
}

enum NetworkError: Error {
    case notImplemented
    case invalidResponse
    case decodingError
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
} 