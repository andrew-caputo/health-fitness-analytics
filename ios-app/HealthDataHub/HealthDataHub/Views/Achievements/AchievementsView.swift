import SwiftUI

struct AchievementsView: View {
    @StateObject private var viewModel = AchievementsViewModel()
    @State private var selectedFilter: AchievementFilter = .all
    @State private var selectedAchievement: Achievement?
    @State private var selectedStreak: Streak?
    @State private var showingCelebration = false
    @State private var showingShareSheet = false
    @State private var showingStreakDetail = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Achievement Stats Overview
                    achievementStatsHeader
                    
                    // Filter Section
                    achievementFilters
                    
                    // Recent Achievements
                    if !viewModel.recentAchievements.isEmpty {
                        recentAchievementsSection
                    }
                    
                    // Achievements Grid
                    achievementsGridSection
                    
                    // Active Streaks
                    activeStreaksSection
                    
                    // Upcoming Milestones
                    upcomingMilestonesSection
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
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                AchievementStatCard(
                    title: "Total",
                    value: "\(viewModel.totalAchievements)",
                    icon: "trophy",
                    color: .blue
                )
                
                AchievementStatCard(
                    title: "Completed",
                    value: "\(viewModel.completedAchievementsCount)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                AchievementStatCard(
                    title: "Points",
                    value: "\(viewModel.totalPoints)",
                    icon: "star.fill",
                    color: .yellow
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var achievementFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AchievementFilter.allCases, id: \.self) { filter in
                    AchievementFilterButton(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        count: viewModel.getCount(for: filter)
                    ) {
                        selectedFilter = filter
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
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                Spacer()
            }
            
            LazyVStack(spacing: 12) {
                ForEach(viewModel.recentAchievements) { achievement in
                    AchievementCard(achievement: achievement) {
                        selectedAchievement = achievement
                        showingCelebration = true
                    }
                }
            }
        }
    }
    
    private var achievementsGridSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All Achievements")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(viewModel.filteredAchievements) { achievement in
                    CompactAchievementCard(achievement: achievement) {
                        selectedAchievement = achievement
                        showingCelebration = true
                    }
                }
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
            }
            
            if viewModel.activeStreaks.isEmpty {
                Text("No active streaks. Start building consistency!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                if let longestStreak = viewModel.longestActiveStreak {
                    StreakCard(streak: longestStreak, isHighlighted: true) {
                        selectedStreak = longestStreak
                        showingStreakDetail = true
                    }
                }
                
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.activeStreaks.filter { $0.id != viewModel.longestActiveStreak?.id }) { streak in
                        StreakCard(streak: streak, isHighlighted: false) {
                            selectedStreak = streak
                            showingStreakDetail = true
                        }
                    }
                }
            }
        }
    }
    
    private var upcomingMilestonesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Upcoming Milestones")
                    .font(.headline)
                    .fontWeight(.semibold)
                Image(systemName: "flag.checkered")
                    .foregroundColor(.green)
                Spacer()
            }
            
            if viewModel.upcomingMilestones.isEmpty {
                Text("All milestones completed! 🎉")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.upcomingMilestones, id: \.id) { milestone in
                        MilestoneCard(milestone: milestone)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct AchievementStatCard: View {
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

struct AchievementFilterButton: View {
    let filter: AchievementFilter
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(filter.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("\(count)")
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Badge
                ZStack {
                    Circle()
                        .fill(achievement.badgeLevel.color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: achievement.isCompleted ? "trophy.fill" : "target")
                        .font(.title2)
                        .foregroundColor(achievement.badgeLevel.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(achievement.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(achievement.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    HStack {
                        Text(achievement.achievementType.displayName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(achievement.badgeLevel.color.opacity(0.2))
                            .foregroundColor(achievement.badgeLevel.color)
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        if achievement.isCompleted {
                            Text("\(achievement.points) pts")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        } else {
                            ProgressView(value: achievement.currentValue / achievement.threshold)
                                .progressViewStyle(LinearProgressViewStyle(tint: achievement.badgeLevel.color))
                                .frame(width: 60)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CompactAchievementCard: View {
    let achievement: Achievement
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Badge
                ZStack {
                    Circle()
                        .fill(achievement.badgeLevel.color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: achievement.isCompleted ? "trophy.fill" : "target")
                        .font(.title3)
                        .foregroundColor(achievement.badgeLevel.color)
                }
                
                VStack(spacing: 4) {
                    Text(achievement.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(achievement.achievementType.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if achievement.isCompleted {
                        Text("\(achievement.points) pts")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    } else {
                        ProgressView(value: achievement.currentValue / achievement.threshold)
                            .progressViewStyle(LinearProgressViewStyle(tint: achievement.badgeLevel.color))
                            .scaleEffect(0.8)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StreakCard: View {
    let streak: Streak
    let isHighlighted: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Streak Icon
                ZStack {
                    Circle()
                        .fill(streak.isActive ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: streak.isActive ? "flame.fill" : "flame")
                        .foregroundColor(streak.isActive ? .orange : .gray)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(streak.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(streak.metricType.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Current: \(streak.currentCount) days")
                            .font(.caption)
                            .foregroundColor(streak.isActive ? .orange : .gray)
                        
                        Spacer()
                        
                        Text("Best: \(streak.longestCount) days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if isHighlighted {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHighlighted ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MilestoneCard: View {
    let milestone: StreakMilestone
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .foregroundColor(.green)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Reach \(milestone.count) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(milestone.reward)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.green)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Missing View Components

struct CelebrationView: View {
    let achievement: Achievement
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Celebration Animation
                ZStack {
                    Circle()
                        .fill(achievement.badgeLevel.color.opacity(0.3))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundColor(achievement.badgeLevel.color)
                }
                
                VStack(spacing: 16) {
                    Text("🎉 Congratulations! 🎉")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(achievement.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text(achievement.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("+\(achievement.points) points")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Button("Continue") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("Achievement Unlocked")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct ShareAchievementsView: View {
    let achievements: [Achievement]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Share Your Achievements")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Share your progress with friends and family!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct StreakDetailView: View {
    let streak: Streak
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Streak Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(streak.isActive ? Color.orange.opacity(0.3) : Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: streak.isActive ? "flame.fill" : "flame")
                                .font(.system(size: 40))
                                .foregroundColor(streak.isActive ? .orange : .gray)
                        }
                        
                        Text(streak.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(streak.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Streak Stats
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("\(streak.currentCount)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(streak.isActive ? .orange : .gray)
                            Text("Current")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(spacing: 4) {
                            Text("\(streak.longestCount)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Text("Best")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Milestones
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Milestones")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(streak.milestones) { milestone in
                            HStack {
                                Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(milestone.isCompleted ? .green : .gray)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(milestone.title)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(milestone.reward)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text("\(milestone.count) days")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Streak Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

struct AchievementsView_Previews: PreviewProvider {
    static var previews: some View {
        AchievementsView()
    }
} 