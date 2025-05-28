import SwiftUI

struct AchievementsView: View {
    @StateObject private var viewModel = AchievementsViewModel()
    @State private var selectedAchievement: Achievement?
    @State private var showingCelebration = false
    @State private var showingShareSheet = false
    @State private var selectedFilter: AchievementFilter = .all
    @State private var showingStreakDetail = false
    @State private var selectedStreak: Streak?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with Stats
                    achievementStatsHeader
                    
                    // Filter Tabs
                    filterTabs
                    
                    // Recent Achievements
                    if !viewModel.recentAchievements.isEmpty {
                        recentAchievementsSection
                    }
                    
                    // Active Streaks
                    activeStreaksSection
                    
                    // All Achievements
                    allAchievementsSection
                    
                    // Milestone Progress
                    milestoneProgressSection
                }
                .padding()
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        showingShareSheet = true
                    }
                }
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .sheet(isPresented: $showingCelebration) {
                if let achievement = selectedAchievement {
                    CelebrationView(achievement: achievement)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareAchievementsView(achievements: viewModel.filteredAchievements)
            }
            .sheet(isPresented: $showingStreakDetail) {
                if let streak = selectedStreak {
                    StreakDetailView(streak: streak)
                }
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
    }
    
    private var achievementStatsHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                Text("Your Achievements")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Stats Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                StatCard(
                    title: "Total",
                    value: "\(viewModel.totalAchievements)",
                    icon: "trophy",
                    color: .yellow
                )
                
                StatCard(
                    title: "This Week",
                    value: "\(viewModel.weeklyAchievements)",
                    icon: "calendar",
                    color: .blue
                )
                
                StatCard(
                    title: "Active Streaks",
                    value: "\(viewModel.activeStreaks.count)",
                    icon: "flame",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AchievementFilter.allCases, id: \.self) { filter in
                    FilterTab(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        count: viewModel.getCount(for: filter)
                    ) {
                        selectedFilter = filter
                        viewModel.applyFilter(filter)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var recentAchievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Achievements")
                    .font(.headline)
                    .fontWeight(.semibold)
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Spacer()
                Text("Last 7 days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(viewModel.recentAchievements) { achievement in
                        RecentAchievementCard(achievement: achievement) {
                            selectedAchievement = achievement
                            showingCelebration = true
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var activeStreaksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Active Streaks")
                    .font(.headline)
                    .fontWeight(.semibold)
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Spacer()
                if let longestStreak = viewModel.longestActiveStreak {
                    Text("Best: \(longestStreak.currentCount) days")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
            }
            
            if viewModel.activeStreaks.isEmpty {
                Text("Start building streaks by maintaining consistent healthy habits!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.activeStreaks) { streak in
                        StreakCard(streak: streak) {
                            selectedStreak = streak
                            showingStreakDetail = true
                        }
                    }
                }
            }
        }
    }
    
    private var allAchievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("All Achievements")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(viewModel.filteredAchievements.count) achievements")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.filteredAchievements.isEmpty {
                EmptyAchievementsView(filter: selectedFilter)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredAchievements) { achievement in
                        AchievementCard(achievement: achievement) {
                            selectedAchievement = achievement
                            showingCelebration = true
                        }
                    }
                }
            }
        }
    }
    
    private var milestoneProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Milestone Progress")
                    .font(.headline)
                    .fontWeight(.semibold)
                Image(systemName: "flag.checkered")
                    .foregroundColor(.green)
                Spacer()
            }
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.upcomingMilestones, id: \.id) { milestone in
                    MilestoneProgressCard(milestone: milestone)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
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
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct FilterTab: View {
    let filter: AchievementFilter
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text(filter.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color.gray.opacity(0.3))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? filter.color : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct RecentAchievementCard: View {
    let achievement: Achievement
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Badge
                BadgeView(
                    type: achievement.achievementType,
                    level: achievement.badgeLevel,
                    size: 60
                )
                
                VStack(spacing: 4) {
                    Text(achievement.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(achievement.earnedDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Celebration indicator
                if achievement.celebrationLevel != .minor {
                    HStack(spacing: 4) {
                        Image(systemName: "party.popper.fill")
                            .font(.caption2)
                        Text("Celebrate!")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .frame(width: 140)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StreakCard: View {
    let streak: Streak
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Flame icon with count
                VStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    
                    Text("\(streak.currentCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(streak.metricType.capitalized)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Current streak")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Best: \(streak.bestCount) days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if streak.currentCount > streak.bestCount {
                            Text("New Record! 🎉")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                // Progress to next milestone
                VStack(alignment: .trailing, spacing: 4) {
                    let nextMilestone = getNextMilestone(for: streak.currentCount)
                    let progress = Double(streak.currentCount) / Double(nextMilestone)
                    
                    Text("Next: \(nextMilestone)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    CircularProgressView(progress: progress, color: .orange)
                        .frame(width: 40, height: 40)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getNextMilestone(for count: Int) -> Int {
        let milestones = [7, 14, 30, 60, 100, 365]
        return milestones.first { $0 > count } ?? (count + 30)
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                BadgeView(
                    type: achievement.achievementType,
                    level: achievement.badgeLevel,
                    size: 50
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(achievement.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.leading)
                    
                    Text(achievement.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    HStack {
                        Text(achievement.earnedDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        BadgeLevelIndicator(level: achievement.badgeLevel)
                    }
                }
                
                Spacer()
                
                if achievement.improvementPercentage != nil {
                    VStack(alignment: .trailing, spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.green)
                        
                        if let improvement = achievement.improvementPercentage {
                            Text("+\(Int(improvement))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
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

struct MilestoneProgressCard: View {
    let milestone: MilestoneProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flag.checkered")
                    .foregroundColor(.green)
                Text(milestone.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(Int(milestone.progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
            
            Text(milestone.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * milestone.progress, height: 8)
                        .cornerRadius(4)
                        .animation(.easeInOut(duration: 0.5), value: milestone.progress)
                }
            }
            .frame(height: 8)
            
            HStack {
                Text("\(milestone.currentValue, specifier: "%.1f") / \(milestone.targetValue, specifier: "%.1f") \(milestone.unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("ETA: \(milestone.estimatedCompletion, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct BadgeView: View {
    let type: AchievementType
    let level: BadgeLevel
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(level.color))
                .frame(width: size, height: size)
            
            Circle()
                .fill(Color(level.color).opacity(0.3))
                .frame(width: size * 0.8, height: size * 0.8)
            
            Image(systemName: type.icon)
                .font(.system(size: size * 0.4))
                .foregroundColor(.white)
        }
        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}

struct BadgeLevelIndicator: View {
    let level: BadgeLevel
    
    var body: some View {
        Text(level.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(level.color).opacity(0.2))
            .foregroundColor(Color(level.color))
            .cornerRadius(4)
    }
}

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.3), lineWidth: 4)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
    }
}

struct EmptyAchievementsView: View {
    let filter: AchievementFilter
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: filter.icon)
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No \(filter.displayName) Yet")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Keep working towards your health goals to unlock achievements!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Supporting Types

enum AchievementFilter: String, CaseIterable {
    case all = "all"
    case recent = "recent"
    case milestones = "milestones"
    case streaks = "streaks"
    case improvements = "improvements"
    case goals = "goals"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .recent: return "Recent"
        case .milestones: return "Milestones"
        case .streaks: return "Streaks"
        case .improvements: return "Improvements"
        case .goals: return "Goals"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "trophy"
        case .recent: return "clock"
        case .milestones: return "flag.checkered"
        case .streaks: return "flame"
        case .improvements: return "chart.line.uptrend.xyaxis"
        case .goals: return "target"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .blue
        case .recent: return .purple
        case .milestones: return .green
        case .streaks: return .orange
        case .improvements: return .red
        case .goals: return .cyan
        }
    }
}

struct MilestoneProgress: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let currentValue: Double
    let targetValue: Double
    let unit: String
    let progress: Double
    let estimatedCompletion: Date
}

// MARK: - Preview

struct AchievementsView_Previews: PreviewProvider {
    static var previews: some View {
        AchievementsView()
    }
} 