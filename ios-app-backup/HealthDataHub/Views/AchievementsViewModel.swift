import Foundation
import Combine

@MainActor
class AchievementsViewModel: ObservableObject {
    @Published var achievements: [Achievement] = []
    @Published var filteredAchievements: [Achievement] = []
    @Published var activeStreaks: [Streak] = []
    @Published var upcomingMilestones: [MilestoneProgress] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Computed properties
    var totalAchievements: Int {
        achievements.count
    }
    
    var weeklyAchievements: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return achievements.filter { $0.earnedDate >= weekAgo }.count
    }
    
    var recentAchievements: [Achievement] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return achievements
            .filter { $0.earnedDate >= weekAgo }
            .sorted { $0.earnedDate > $1.earnedDate }
            .prefix(5)
            .map { $0 }
    }
    
    var longestActiveStreak: Streak? {
        activeStreaks.max { $0.currentCount < $1.currentCount }
    }
    
    init() {
        setupMockData()
    }
    
    func loadInitialData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let achievementsData = fetchAchievements()
            async let streaksData = fetchStreaks()
            
            let (fetchedAchievements, fetchedStreaks) = try await (achievementsData, streaksData)
            
            self.achievements = fetchedAchievements
            self.filteredAchievements = fetchedAchievements
            self.activeStreaks = fetchedStreaks.filter { $0.isActive }
            self.upcomingMilestones = generateUpcomingMilestones()
            
        } catch {
            self.errorMessage = "Failed to load achievement data: \(error.localizedDescription)"
            print("Error loading achievements: \(error)")
        }
        
        isLoading = false
    }
    
    func refreshData() async {
        await loadInitialData()
    }
    
    func applyFilter(_ filter: AchievementFilter) {
        switch filter {
        case .all:
            filteredAchievements = achievements
        case .recent:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            filteredAchievements = achievements.filter { $0.earnedDate >= weekAgo }
        case .milestones:
            filteredAchievements = achievements.filter { $0.achievementType == .milestone }
        case .streaks:
            filteredAchievements = achievements.filter { $0.achievementType == .streak }
        case .improvements:
            filteredAchievements = achievements.filter { $0.achievementType == .improvement }
        case .goals:
            filteredAchievements = achievements.filter { $0.achievementType == .goalCompletion }
        }
    }
    
    func getCount(for filter: AchievementFilter) -> Int {
        switch filter {
        case .all:
            return achievements.count
        case .recent:
            return recentAchievements.count
        case .milestones:
            return achievements.filter { $0.achievementType == .milestone }.count
        case .streaks:
            return achievements.filter { $0.achievementType == .streak }.count
        case .improvements:
            return achievements.filter { $0.achievementType == .improvement }.count
        case .goals:
            return achievements.filter { $0.achievementType == .goalCompletion }.count
        }
    }
    
    func celebrateAchievement(_ achievementId: String) async throws {
        let endpoint = "/ai/achievements/\(achievementId)/celebrate"
        let _: CelebrationEvent = try await networkManager.request(
            endpoint: endpoint,
            method: .POST
        )
        
        // Trigger local celebration effects
        // This would integrate with haptics, sounds, and visual effects
    }
    
    // MARK: - API Calls
    
    private func fetchAchievements() async throws -> [Achievement] {
        let endpoint = "/ai/achievements"
        let response: AchievementsResponse = try await networkManager.request(
            endpoint: endpoint,
            method: .GET
        )
        return response.achievements
    }
    
    private func fetchStreaks() async throws -> [Streak] {
        let endpoint = "/ai/achievements/streaks"
        let response: StreaksResponse = try await networkManager.request(
            endpoint: endpoint,
            method: .GET
        )
        return response.streaks
    }
    
    // MARK: - Mock Data Setup
    
    private func setupMockData() {
        achievements = createMockAchievements()
        filteredAchievements = achievements
        activeStreaks = createMockStreaks()
        upcomingMilestones = generateUpcomingMilestones()
    }
    
    private func createMockAchievements() -> [Achievement] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        return [
            Achievement(
                id: "ach_1",
                achievementType: .milestone,
                title: "10K Steps Milestone",
                description: "Reached 10,000 steps in a single day for the first time!",
                badgeLevel: .gold,
                celebrationLevel: .major,
                earnedDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                metricType: "steps",
                achievementValue: 10000,
                previousBest: 8500,
                improvementPercentage: 17.6,
                streakDays: nil,
                requirementsMet: ["Daily step goal", "Consistent activity"],
                nextMilestone: "15,000 steps milestone",
                sharingMessage: "Just hit my first 10K steps in a day! 🚶‍♂️💪",
                motivationMessage: "Amazing work! You've proven you can push beyond your limits. Keep building on this momentum!"
            ),
            
            Achievement(
                id: "ach_2",
                achievementType: .streak,
                title: "7-Day Sleep Streak",
                description: "Maintained 7+ hours of sleep for 7 consecutive days",
                badgeLevel: .silver,
                celebrationLevel: .moderate,
                earnedDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                metricType: "sleep",
                achievementValue: 7.5,
                previousBest: 6.2,
                improvementPercentage: 21.0,
                streakDays: 7,
                requirementsMet: ["Sleep duration goal", "Consistency"],
                nextMilestone: "14-day sleep streak",
                sharingMessage: "One week of great sleep! 😴✨ Feeling more energized than ever!",
                motivationMessage: "Excellent sleep consistency! Quality rest is the foundation of all health improvements."
            ),
            
            Achievement(
                id: "ach_3",
                achievementType: .improvement,
                title: "Heart Rate Improvement",
                description: "Lowered resting heart rate by 5 BPM over the past month",
                badgeLevel: .platinum,
                celebrationLevel: .major,
                earnedDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
                metricType: "resting_heart_rate",
                achievementValue: 65,
                previousBest: 70,
                improvementPercentage: 7.1,
                streakDays: nil,
                requirementsMet: ["Cardiovascular improvement", "Training consistency"],
                nextMilestone: "60 BPM resting heart rate",
                sharingMessage: "My heart is getting stronger! 💓 5 BPM improvement this month!",
                motivationMessage: "Outstanding cardiovascular progress! Your heart is becoming more efficient with every workout."
            ),
            
            Achievement(
                id: "ach_4",
                achievementType: .consistency,
                title: "Hydration Hero",
                description: "Met daily water intake goal for 14 consecutive days",
                badgeLevel: .gold,
                celebrationLevel: .moderate,
                earnedDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                metricType: "water_intake",
                achievementValue: 2.5,
                previousBest: 1.8,
                improvementPercentage: 38.9,
                streakDays: 14,
                requirementsMet: ["Daily hydration goal", "Habit formation"],
                nextMilestone: "30-day hydration streak",
                sharingMessage: "2 weeks of perfect hydration! 💧 Feeling amazing!",
                motivationMessage: "Fantastic hydration habits! Your body is thanking you for this consistent care."
            ),
            
            Achievement(
                id: "ach_5",
                achievementType: .personalBest,
                title: "Personal Best Workout",
                description: "Achieved highest calorie burn in a single workout session",
                badgeLevel: .diamond,
                celebrationLevel: .epic,
                earnedDate: Calendar.current.date(byAdding: .day, value: -15, to: Date()) ?? Date(),
                metricType: "calories_burned",
                achievementValue: 650,
                previousBest: 520,
                improvementPercentage: 25.0,
                streakDays: nil,
                requirementsMet: ["Workout intensity", "Personal record"],
                nextMilestone: "700 calorie workout",
                sharingMessage: "New personal best! 🔥 650 calories in one workout! 💪",
                motivationMessage: "Incredible personal best! You've shattered your previous limits and set a new standard for yourself."
            ),
            
            Achievement(
                id: "ach_6",
                achievementType: .goalCompletion,
                title: "Weight Loss Goal",
                description: "Successfully reached your 3-month weight loss target",
                badgeLevel: .platinum,
                celebrationLevel: .epic,
                earnedDate: Calendar.current.date(byAdding: .day, value: -20, to: Date()) ?? Date(),
                metricType: "weight",
                achievementValue: 75.0,
                previousBest: 82.0,
                improvementPercentage: 8.5,
                streakDays: nil,
                requirementsMet: ["Weight loss target", "Sustained effort", "Lifestyle change"],
                nextMilestone: "Maintenance phase goal",
                sharingMessage: "Goal achieved! 🎯 Lost 7kg in 3 months through healthy habits! 🌟",
                motivationMessage: "Phenomenal goal achievement! You've proven that dedication and consistency create lasting transformation."
            ),
            
            Achievement(
                id: "ach_7",
                achievementType: .milestone,
                title: "First 5K Run",
                description: "Completed your first 5 kilometer run without stopping",
                badgeLevel: .gold,
                celebrationLevel: .major,
                earnedDate: Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date(),
                metricType: "running_distance",
                achievementValue: 5.0,
                previousBest: 3.2,
                improvementPercentage: 56.3,
                streakDays: nil,
                requirementsMet: ["Endurance milestone", "Running consistency"],
                nextMilestone: "10K run milestone",
                sharingMessage: "First 5K complete! 🏃‍♂️ From couch to 5K! 🎉",
                motivationMessage: "Incredible milestone! You've built the endurance and mental strength to conquer any distance."
            ),
            
            Achievement(
                id: "ach_8",
                achievementType: .streak,
                title: "Mindfulness Master",
                description: "Completed daily meditation for 21 consecutive days",
                badgeLevel: .silver,
                celebrationLevel: .moderate,
                earnedDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
                metricType: "meditation",
                achievementValue: 15.0,
                previousBest: 0.0,
                improvementPercentage: nil,
                streakDays: 21,
                requirementsMet: ["Daily meditation", "Habit formation", "Mental wellness"],
                nextMilestone: "30-day meditation streak",
                sharingMessage: "21 days of mindfulness! 🧘‍♂️ Building mental strength daily! ✨",
                motivationMessage: "Wonderful mindfulness journey! You're building mental resilience that benefits every aspect of your life."
            )
        ]
    }
    
    private func createMockStreaks() -> [Streak] {
        return [
            Streak(
                id: "streak_1",
                metricType: "steps",
                currentCount: 12,
                bestCount: 18,
                startDate: Calendar.current.date(byAdding: .day, value: -12, to: Date()) ?? Date(),
                lastUpdate: Date(),
                targetValue: 8000,
                streakType: "daily_goal",
                isActive: true,
                milestoneReached: [7]
            ),
            
            Streak(
                id: "streak_2",
                metricType: "water_intake",
                currentCount: 16,
                bestCount: 16,
                startDate: Calendar.current.date(byAdding: .day, value: -16, to: Date()) ?? Date(),
                lastUpdate: Date(),
                targetValue: 2.5,
                streakType: "hydration_goal",
                isActive: true,
                milestoneReached: [7, 14]
            ),
            
            Streak(
                id: "streak_3",
                metricType: "sleep",
                currentCount: 9,
                bestCount: 21,
                startDate: Calendar.current.date(byAdding: .day, value: -9, to: Date()) ?? Date(),
                lastUpdate: Date(),
                targetValue: 7.0,
                streakType: "sleep_quality",
                isActive: true,
                milestoneReached: [7]
            ),
            
            Streak(
                id: "streak_4",
                metricType: "meditation",
                currentCount: 5,
                bestCount: 25,
                startDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                lastUpdate: Date(),
                targetValue: 10.0,
                streakType: "mindfulness",
                isActive: true,
                milestoneReached: []
            ),
            
            Streak(
                id: "streak_5",
                metricType: "workout",
                currentCount: 3,
                bestCount: 12,
                startDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                lastUpdate: Date(),
                targetValue: 30.0,
                streakType: "exercise_minutes",
                isActive: true,
                milestoneReached: []
            )
        ]
    }
    
    private func generateUpcomingMilestones() -> [MilestoneProgress] {
        return [
            MilestoneProgress(
                title: "15K Steps Milestone",
                description: "Reach 15,000 steps in a single day",
                currentValue: 12500,
                targetValue: 15000,
                unit: "steps",
                progress: 12500 / 15000,
                estimatedCompletion: Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
            ),
            
            MilestoneProgress(
                title: "30-Day Sleep Streak",
                description: "Maintain 7+ hours of sleep for 30 consecutive days",
                currentValue: 9,
                targetValue: 30,
                unit: "days",
                progress: 9.0 / 30.0,
                estimatedCompletion: Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date()
            ),
            
            MilestoneProgress(
                title: "60 BPM Resting Heart Rate",
                description: "Achieve a resting heart rate of 60 BPM or lower",
                currentValue: 65,
                targetValue: 60,
                unit: "BPM",
                progress: (70 - 65) / (70 - 60), // Progress from 70 to 60
                estimatedCompletion: Calendar.current.date(byAdding: .day, value: 45, to: Date()) ?? Date()
            ),
            
            MilestoneProgress(
                title: "10K Run Milestone",
                description: "Complete a 10 kilometer run without stopping",
                currentValue: 5.0,
                targetValue: 10.0,
                unit: "km",
                progress: 5.0 / 10.0,
                estimatedCompletion: Calendar.current.date(byAdding: .day, value: 60, to: Date()) ?? Date()
            ),
            
            MilestoneProgress(
                title: "Body Fat Goal",
                description: "Reach target body fat percentage of 15%",
                currentValue: 18.5,
                targetValue: 15.0,
                unit: "%",
                progress: (20 - 18.5) / (20 - 15), // Progress from 20% to 15%
                estimatedCompletion: Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date()
            )
        ]
    }
}

// MARK: - Supporting Views (Placeholder implementations)

struct CelebrationView: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 20) {
            Text("🎉 Congratulations! 🎉")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            BadgeView(
                type: achievement.achievementType,
                level: achievement.badgeLevel,
                size: 120
            )
            
            Text(achievement.title)
                .font(.title)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text(achievement.motivationMessage)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Share Achievement") {
                // Share functionality
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

struct ShareAchievementsView: View {
    let achievements: [Achievement]
    
    var body: some View {
        VStack {
            Text("Share Your Achievements")
                .font(.title)
                .fontWeight(.semibold)
                .padding()
            
            Text("Select achievements to share with friends and family!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            
            // Achievement sharing interface would go here
            
            Button("Share Selected") {
                // Share functionality
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

struct StreakDetailView: View {
    let streak: Streak
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Streak Details")
                .font(.title)
                .fontWeight(.semibold)
            
            VStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                Text("\(streak.currentCount) Days")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
            }
            
            Text(streak.metricType.capitalized)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Keep up the great work! You're building a powerful healthy habit.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
            
            // Streak history and tips would go here
        }
        .padding()
    }
} 