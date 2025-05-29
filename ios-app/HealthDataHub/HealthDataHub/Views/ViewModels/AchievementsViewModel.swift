import Foundation
import SwiftUI
import Combine

@MainActor
class AchievementsViewModel: ObservableObject {
    @Published var achievements: [Achievement] = []
    @Published var streaks: [Streak] = []
    @Published var categories: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFilter: String = "all"
    @Published var showingCelebration = false
    @Published var newAchievement: Achievement?
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadMockData()
    }
    
    // MARK: - Missing Properties
    
    var recentAchievements: [Achievement] {
        achievements.filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? Date.distantPast) > ($1.completedAt ?? Date.distantPast) }
            .prefix(5)
            .map { $0 }
    }
    
    var totalAchievements: Int {
        achievements.count
    }
    
    var longestActiveStreak: Streak? {
        activeStreaks.max { $0.currentCount < $1.currentCount }
    }
    
    var upcomingMilestones: [StreakMilestone] {
        streaks.flatMap { $0.milestones.filter { !$0.isCompleted } }
            .sorted { $0.count < $1.count }
    }
    
    // MARK: - Missing Methods
    
    func refreshData() async {
        await MainActor.run {
            isLoading = true
        }
        
        // Simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            loadMockData()
            isLoading = false
        }
    }
    
    func loadInitialData() async {
        await refreshData()
    }
    
    func getCount(for filter: AchievementFilter) -> Int {
        switch filter {
        case .all:
            return achievements.count
        case .completed:
            return achievements.filter { $0.isCompleted }.count
        case .inProgress:
            return achievements.filter { !$0.isCompleted }.count
        case .recent:
            return recentAchievements.count
        }
    }
    
    // MARK: - Existing Methods
    
    func loadAchievements() {
        isLoading = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            // Data would be loaded from API here
        }
    }
    
    func filterAchievements(by category: String) {
        selectedFilter = category
    }
    
    func celebrateAchievement(_ achievement: Achievement) {
        newAchievement = achievement
        showingCelebration = true
    }
    
    var filteredAchievements: [Achievement] {
        if selectedFilter == "all" {
            return achievements
        }
        return achievements.filter { $0.category == selectedFilter }
    }
    
    var completedAchievementsCount: Int {
        achievements.filter { $0.isCompleted }.count
    }
    
    var totalPoints: Int {
        achievements.filter { $0.isCompleted }.reduce(0) { $0 + $1.points }
    }
    
    var activeStreaks: [Streak] {
        streaks.filter { $0.isActive }
    }
    
    var longestStreak: Streak? {
        streaks.max { $0.longestCount < $1.longestCount }
    }
    
    private func loadMockData() {
        // Mock achievements data
        achievements = [
            Achievement(
                id: "ach_1",
                title: "First Week Complete",
                description: "Complete your first week of consistent health tracking",
                type: "milestone",
                category: "consistency",
                threshold: 7,
                currentValue: 7,
                isCompleted: true,
                completedAt: Calendar.current.date(byAdding: .day, value: -5, to: Date()),
                badgeLevel: .bronze,
                points: 100,
                rarity: "common"
            ),
            Achievement(
                id: "ach_2",
                title: "Step Master",
                description: "Walk 10,000 steps in a single day",
                type: "goal",
                category: "activity",
                threshold: 10000,
                currentValue: 12500,
                isCompleted: true,
                completedAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
                badgeLevel: .silver,
                points: 250,
                rarity: "uncommon"
            ),
            Achievement(
                id: "ach_3",
                title: "Early Bird",
                description: "Wake up before 6 AM for 5 consecutive days",
                type: "streak",
                category: "sleep",
                threshold: 5,
                currentValue: 3,
                isCompleted: false,
                completedAt: nil,
                badgeLevel: .bronze,
                points: 150,
                rarity: "common"
            ),
            Achievement(
                id: "ach_4",
                title: "Hydration Hero",
                description: "Drink 8 glasses of water daily for 2 weeks",
                type: "consistency",
                category: "wellness",
                threshold: 14,
                currentValue: 9,
                isCompleted: false,
                completedAt: nil,
                badgeLevel: .gold,
                points: 500,
                rarity: "rare"
            )
        ]
        
        // Mock streaks data
        streaks = [
            Streak(
                id: "streak_1",
                type: "daily_activity",
                title: "Daily Steps",
                description: "Consecutive days hitting step goal",
                currentCount: 12,
                longestCount: 15,
                startDate: Calendar.current.date(byAdding: .day, value: -12, to: Date()) ?? Date(),
                lastUpdate: Date(),
                isActive: true,
                milestones: [
                    StreakMilestone(id: "ms1", count: 7, title: "One Week", reward: "Bronze Badge", isCompleted: true),
                    StreakMilestone(id: "ms2", count: 14, title: "Two Weeks", reward: "Silver Badge", isCompleted: false),
                    StreakMilestone(id: "ms3", count: 30, title: "One Month", reward: "Gold Badge", isCompleted: false)
                ]
            ),
            Streak(
                id: "streak_2",
                type: "sleep_consistency",
                title: "Sleep Schedule",
                description: "Consecutive nights with 7+ hours sleep",
                currentCount: 0,
                longestCount: 8,
                startDate: Calendar.current.date(byAdding: .day, value: -20, to: Date()) ?? Date(),
                lastUpdate: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                isActive: false,
                milestones: [
                    StreakMilestone(id: "ms4", count: 7, title: "One Week", reward: "Sleep Badge", isCompleted: true),
                    StreakMilestone(id: "ms5", count: 14, title: "Two Weeks", reward: "Sleep Master", isCompleted: false)
                ]
            )
        ]
        
        categories = ["all", "activity", "sleep", "nutrition", "wellness", "consistency"]
    }
}

// MARK: - Missing Enum

enum AchievementFilter: String, CaseIterable {
    case all = "all"
    case completed = "completed"
    case inProgress = "in_progress"
    case recent = "recent"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .completed: return "Completed"
        case .inProgress: return "In Progress"
        case .recent: return "Recent"
        }
    }
} 