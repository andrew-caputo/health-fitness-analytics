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
        // Real backend integration - replace mock data
        print("🏆 Loading real achievements and streaks from backend API...")
        
        Task {
            await MainActor.run {
                isLoading = true
            }
            
            do {
                // Load achievements and streaks concurrently
                async let achievementsTask = loadRealAchievements()
                async let streaksTask = loadRealStreaks()
                
                let (realAchievements, realStreaks) = try await (achievementsTask, streaksTask)
                
                await MainActor.run {
                    self.achievements = realAchievements
                    self.streaks = realStreaks
                    self.categories = ["all", "activity", "sleep", "nutrition", "wellness", "consistency"]
                    self.isLoading = false
                }
                
                print("✅ Loaded \(realAchievements.count) real achievements and \(realStreaks.count) real streaks")
            } catch {
                print("❌ Error loading real achievements: \(error)")
                print("📱 Using fallback: Empty achievements")
                
                await MainActor.run {
                    self.achievements = []
                    self.streaks = []
                    self.categories = ["all", "activity", "sleep", "nutrition", "wellness", "consistency"]
                    self.isLoading = false
                }
            }
        }
    }
    
    private func loadRealAchievements() async throws -> [Achievement] {
        print("🎯 Fetching real achievements from backend API...")
        do {
            let response = try await withTimeout(seconds: 10) {
                try await NetworkManager.shared.fetchAchievements()
            }
            
            // Convert backend achievements to app model
            let achievements = response.achievements.map { achievement in
                Achievement(
                    id: achievement.id,
                    title: achievement.title,
                    description: achievement.description,
                    type: achievement.type,
                    category: achievement.category,
                    threshold: achievement.threshold,
                    currentValue: achievement.current_value,
                    isCompleted: achievement.is_completed,
                    completedAt: parseDate(achievement.completed_at),
                    badgeLevel: BadgeLevel(rawValue: achievement.badge_level) ?? .bronze,
                    points: achievement.points,
                    rarity: achievement.rarity
                )
            }
            
            print("✅ Converted \(achievements.count) backend achievements to app model")
            return achievements
        } catch {
            print("❌ Error fetching real achievements: \(error)")
            throw error
        }
    }
    
    private func loadRealStreaks() async throws -> [Streak] {
        print("🔥 Fetching real streaks from backend API...")
        do {
            let response = try await withTimeout(seconds: 10) {
                try await NetworkManager.shared.fetchStreaks()
            }
            
            // Convert backend streaks to app model
            let streaks = response.streaks.map { streak in
                let milestones = streak.milestones.map { milestone in
                    StreakMilestone(
                        id: milestone.id,
                        count: milestone.count,
                        title: milestone.title,
                        reward: milestone.reward,
                        isCompleted: milestone.is_completed
                    )
                }
                
                return Streak(
                    id: streak.id,
                    type: streak.type,
                    title: streak.title,
                    description: streak.description,
                    currentCount: streak.current_count,
                    longestCount: streak.longest_count,
                    startDate: parseDate(streak.start_date) ?? Date(),
                    lastUpdate: parseDate(streak.last_update) ?? Date(),
                    isActive: streak.is_active,
                    milestones: milestones
                )
            }
            
            print("✅ Converted \(streaks.count) backend streaks to app model")
            return streaks
        } catch {
            print("❌ Error fetching real streaks: \(error)")
            throw error
        }
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
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