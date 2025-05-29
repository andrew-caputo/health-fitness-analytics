import Foundation
import SwiftUI
import Combine

@MainActor
class PersonalizedGoalsViewModel: ObservableObject {
    @Published var goalRecommendations: [GoalRecommendation] = []
    @Published var filteredRecommendations: [GoalRecommendation] = []
    @Published var activeGoals: [GoalRecommendation] = []
    @Published var goalCoordinations: [GoalCoordination] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadMockData()
    }
    
    var averageSuccessProbability: Double? {
        guard !filteredRecommendations.isEmpty else { return nil }
        let total = filteredRecommendations.reduce(into: 0.0) { $0 += $1.confidence }
        return total / Double(filteredRecommendations.count)
    }
    
    func loadInitialData() async {
        await loadRecommendations()
    }
    
    func refreshData() async {
        await loadRecommendations()
    }
    
    func loadRecommendations() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // In a real app, this would make an API call
            try await Task.sleep(nanoseconds: 1_000_000_000)
            loadMockData()
        } catch {
            errorMessage = "Failed to load recommendations: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func filterByCategory(_ category: GoalCategory) async {
        filteredRecommendations = goalRecommendations.filter { $0.category == category.rawValue }
    }
    
    func filterByDifficulty(_ difficulty: GoalDifficulty) async {
        filteredRecommendations = goalRecommendations.filter { $0.difficulty == difficulty.rawValue }
    }
    
    func refreshRecommendations() async {
        await loadRecommendations()
    }
    
    func requestGoalAdjustment(for goalId: String, newTarget: Double) async throws {
        // Simplified implementation
        isLoading = true
        try await Task.sleep(nanoseconds: 500_000_000)
        isLoading = false
    }
    
    // MARK: - Helper Methods
    
    private func loadMockData() {
        // Create mock goal recommendations
        goalRecommendations = [
            GoalRecommendation(
                id: "1",
                type: "activity",
                title: "Increase Daily Steps",
                description: "Walk 10,000 steps daily to improve cardiovascular health",
                category: GoalCategory.activity.rawValue,
                targetValue: 10000,
                currentValue: 7500,
                timeline: 30,
                difficulty: GoalDifficulty.moderate.rawValue,
                confidence: 0.85,
                reasoning: ["Based on your current activity patterns", "Achievable with moderate effort"],
                benefits: ["High cardiovascular benefits", "Improved endurance"],
                successFactors: ["Consistent daily tracking", "Morning walks", "Evening walks"],
                resources: [
                    GoalResource(
                        id: "r1",
                        type: "guide",
                        title: "Walking for Fitness",
                        description: "Complete guide to walking for health",
                        url: "https://example.com/walking-guide",
                        category: "education"
                    )
                ]
            ),
            GoalRecommendation(
                id: "2",
                type: "sleep",
                title: "Improve Sleep Quality",
                description: "Maintain 7-8 hours of quality sleep nightly",
                category: GoalCategory.sleep.rawValue,
                targetValue: 8,
                currentValue: 6.5,
                timeline: 30,
                difficulty: GoalDifficulty.easy.rawValue,
                confidence: 0.92,
                reasoning: ["Your sleep patterns show room for improvement", "Small changes yield big results"],
                benefits: ["Improved recovery and mental clarity", "Better mood regulation"],
                successFactors: ["Consistent bedtime routine", "Screen time limits", "Cool sleeping environment"],
                resources: [
                    GoalResource(
                        id: "r2",
                        type: "app",
                        title: "Sleep Tracker",
                        description: "Monitor and improve your sleep patterns",
                        url: "https://example.com/sleep-app",
                        category: "tool"
                    )
                ]
            ),
            GoalRecommendation(
                id: "3",
                type: "exercise",
                title: "Strength Training",
                description: "Complete 3 strength training sessions per week",
                category: GoalCategory.activity.rawValue,
                targetValue: 3,
                currentValue: 1,
                timeline: 84, // 12 weeks
                difficulty: GoalDifficulty.challenging.rawValue,
                confidence: 0.78,
                reasoning: ["Your muscle mass could benefit from resistance training", "Progressive overload principle"],
                benefits: ["Increased muscle strength and bone density", "Improved metabolism"],
                successFactors: ["Gym membership or home equipment", "Progressive workout plan", "Rest days for recovery"],
                resources: [
                    GoalResource(
                        id: "r3",
                        type: "program",
                        title: "Beginner Strength Training",
                        description: "12-week progressive strength program",
                        url: "https://example.com/strength-program",
                        category: "program"
                    )
                ]
            )
        ]
        
        // Create mock active goals (subset of recommendations that user has started)
        activeGoals = Array(goalRecommendations.prefix(2))
        
        // Initialize filtered recommendations with all recommendations
        filteredRecommendations = goalRecommendations
        
        // Create mock goal coordinations
        goalCoordinations = [
            GoalCoordination(
                id: "coord1",
                title: "Activity & Sleep Synergy",
                description: "Your activity and sleep goals work together to optimize recovery",
                relatedGoals: ["1", "2"],
                coordinationType: "synergy",
                priority: "high",
                synergies: ["Better sleep improves exercise performance", "Exercise improves sleep quality"],
                conflicts: [],
                recommendations: ["Schedule workouts at least 3 hours before bedtime"],
                impactScore: 0.85
            )
        ]
    }
} 