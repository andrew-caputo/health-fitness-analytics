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
        // Real data will be loaded via loadInitialData() call from view
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
        // Real backend integration - replace mock data
        print("🎯 Loading real goal recommendations from backend API...")
        isLoading = true
        errorMessage = nil
        
        do {
            // Load goal recommendations and coordinations concurrently
            async let recommendationsTask = loadRealGoalRecommendations()
            async let coordinationsTask = loadRealGoalCoordinations()
            
            let (realRecommendations, realCoordinations) = try await (recommendationsTask, coordinationsTask)
            
            self.goalRecommendations = realRecommendations
            self.filteredRecommendations = realRecommendations
            self.goalCoordinations = realCoordinations
            
            // Set active goals as subset of recommendations (those user has started)
            self.activeGoals = realRecommendations.filter { $0.currentValue > 0 }
            
            print("✅ Loaded \(realRecommendations.count) real goal recommendations and \(realCoordinations.count) coordinations")
        } catch {
            print("❌ Error loading real goal recommendations: \(error)")
            print("📱 Using fallback: Empty goals")
            errorMessage = "Failed to load recommendations: \(error.localizedDescription)"
            
            // Fallback to empty state
            self.goalRecommendations = []
            self.filteredRecommendations = []
            self.activeGoals = []
            self.goalCoordinations = []
        }
        
        isLoading = false
    }
    
    private func loadRealGoalRecommendations() async throws -> [GoalRecommendation] {
        print("🎯 Fetching real goal recommendations from backend API...")
        do {
            let response = try await withTimeout(seconds: 10) {
                try await NetworkManager.shared.fetchGoalRecommendations()
            }
            
            // Convert backend recommendations to app model
            let recommendations = response.recommendations.map { recommendation in
                return GoalRecommendation(
                    id: recommendation.id,
                    type: "goal", // Default type since not provided by backend
                    title: recommendation.title,
                    description: recommendation.description,
                    category: recommendation.category,
                    targetValue: recommendation.target_value,
                    currentValue: recommendation.current_value ?? 0,
                    timeline: recommendation.timeline_weeks * 7, // Convert weeks to days
                    difficulty: recommendation.difficulty,
                    confidence: recommendation.confidence,
                    reasoning: recommendation.prerequisites ?? [],
                    benefits: recommendation.expected_benefits,
                    successFactors: [], // Not provided by backend
                    resources: [] // Not provided by backend
                )
            }
            
            print("✅ Converted \(recommendations.count) backend goal recommendations to app model")
            return recommendations
        } catch {
            print("❌ Error fetching real goal recommendations: \(error)")
            throw error
        }
    }
    
    private func loadRealGoalCoordinations() async throws -> [GoalCoordination] {
        print("🔗 Fetching real goal coordinations from backend API...")
        do {
            let response = try await withTimeout(seconds: 10) {
                try await NetworkManager.shared.fetchGoalCoordination()
            }
            
            // Convert backend coordinations to app model
            let coordinations = response.coordinated_goals.map { coordination in
                GoalCoordination(
                    id: coordination.id,
                    title: coordination.title,
                    description: "Goal coordination for \(coordination.title)",
                    relatedGoals: [coordination.id], // Single goal for now
                    coordinationType: coordination.interaction_type,
                    priority: coordination.priority == 1 ? "high" : coordination.priority == 2 ? "medium" : "low",
                    synergies: response.synergies?.map { $0.description } ?? [],
                    conflicts: response.conflicts?.map { $0.resolution_suggestion } ?? [],
                    recommendations: [], // Not directly provided
                    impactScore: response.synergies?.first?.benefit_multiplier ?? 0.5
                )
            }
            
            print("✅ Converted \(coordinations.count) backend goal coordinations to app model")
            return coordinations
        } catch {
            print("❌ Error fetching real goal coordinations: \(error)")
            throw error
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
    
    // MARK: - Helper Methods (Note: Mock data methods removed - using real backend integration)
} 