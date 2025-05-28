import SwiftUI
import Charts

struct PersonalizedGoalsView: View {
    @StateObject private var viewModel = PersonalizedGoalsViewModel()
    @State private var selectedCategory: GoalCategory = .activity
    @State private var selectedDifficulty: GoalDifficulty = .moderate
    @State private var showingGoalDetail = false
    @State private var selectedGoal: GoalRecommendation?
    @State private var showingAdjustmentSheet = false
    @State private var showingCoordinationView = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with AI Insights
                    aiInsightsHeader
                    
                    // Category Filter
                    categoryFilter
                    
                    // Difficulty Filter
                    difficultyFilter
                    
                    // Goal Recommendations
                    goalRecommendationsSection
                    
                    // Active Goals Progress
                    activeGoalsSection
                    
                    // Goal Coordination
                    goalCoordinationSection
                }
                .padding()
            }
            .navigationTitle("Personalized Goals")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Coordinate") {
                        showingCoordinationView = true
                    }
                }
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .sheet(isPresented: $showingGoalDetail) {
                if let goal = selectedGoal {
                    GoalDetailView(goal: goal, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showingAdjustmentSheet) {
                if let goal = selectedGoal {
                    GoalAdjustmentView(goal: goal, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showingCoordinationView) {
                GoalCoordinationView(viewModel: viewModel)
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
    }
    
    private var aiInsightsHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text("AI Goal Recommendations")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Text("Based on your health patterns and progress, here are personalized goals to optimize your wellness journey.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            // Success Rate Indicator
            if let successRate = viewModel.averageSuccessProbability {
                HStack {
                    Image(systemName: "target")
                        .foregroundColor(.green)
                    Text("Average Success Rate: \(Int(successRate * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var categoryFilter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.headline)
                .fontWeight(.medium)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(GoalCategory.allCases, id: \.self) { category in
                        CategoryFilterButton(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                            Task {
                                await viewModel.filterByCategory(category)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var difficultyFilter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Difficulty Level")
                .font(.headline)
                .fontWeight(.medium)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(GoalDifficulty.allCases, id: \.self) { difficulty in
                        DifficultyFilterButton(
                            difficulty: difficulty,
                            isSelected: selectedDifficulty == difficulty
                        ) {
                            selectedDifficulty = difficulty
                            Task {
                                await viewModel.filterByDifficulty(difficulty)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var goalRecommendationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recommended Goals")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(viewModel.filteredRecommendations.count) goals")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.filteredRecommendations.isEmpty {
                EmptyGoalsView()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredRecommendations) { goal in
                        GoalRecommendationCard(goal: goal) {
                            selectedGoal = goal
                            showingGoalDetail = true
                        }
                    }
                }
            }
        }
    }
    
    private var activeGoalsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Active Goals")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(viewModel.activeGoals.count) active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.activeGoals.isEmpty {
                Text("No active goals yet. Start by selecting a recommendation above!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.activeGoals) { goal in
                        ActiveGoalCard(goal: goal) {
                            selectedGoal = goal
                            showingAdjustmentSheet = true
                        }
                    }
                }
            }
        }
    }
    
    private var goalCoordinationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Goal Synergies")
                    .font(.headline)
                    .fontWeight(.semibold)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
                Spacer()
            }
            
            if viewModel.goalCoordinations.isEmpty {
                Text("Set multiple goals to see synergy recommendations")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.goalCoordinations) { coordination in
                        GoalCoordinationCard(coordination: coordination)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct CategoryFilterButton: View {
    let category: GoalCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct DifficultyFilterButton: View {
    let difficulty: GoalDifficulty
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(difficulty.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(difficulty.color) : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct GoalRecommendationCard: View {
    let goal: GoalRecommendation
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(goal.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.leading)
                        
                        Text(goal.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        DifficultyBadge(difficulty: goal.difficulty)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.caption2)
                            Text("\(Int(goal.successProbability * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.green)
                    }
                }
                
                // Progress Visualization
                GoalProgressBar(
                    current: goal.currentValue,
                    target: goal.targetValue,
                    unit: goal.unit
                )
                
                // Key Benefits
                if !goal.expectedBenefits.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Expected Benefits:")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        ForEach(goal.expectedBenefits.prefix(2), id: \.self) { benefit in
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                Text(benefit)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Timeline
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("\(goal.timelineDays) days")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("Confidence: \(Int(goal.confidenceScore * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
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

struct ActiveGoalCard: View {
    let goal: GoalRecommendation
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Active Goal")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                Button("Adjust", action: action)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            // Enhanced Progress Visualization
            GoalProgressBar(
                current: goal.currentValue,
                target: goal.targetValue,
                unit: goal.unit
            )
            
            // Progress Chart
            GoalProgressChart(goal: goal)
                .frame(height: 100)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct GoalCoordinationCard: View {
    let coordination: GoalCoordination
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
                Text("Goal Synergy")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text(coordination.coordinationType.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            
            Text(coordination.impactDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !coordination.optimizationSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Optimization Tips:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    ForEach(coordination.optimizationSuggestions.prefix(2), id: \.self) { suggestion in
                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

struct GoalProgressBar: View {
    let current: Double
    let target: Double
    let unit: String
    
    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(current, specifier: "%.1f") / \(target, specifier: "%.1f") \(unit)")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(progress >= 1.0 ? .green : .blue)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(progress >= 1.0 ? Color.green : Color.blue)
                        .frame(width: geometry.size.width * progress, height: 6)
                        .cornerRadius(3)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                }
            }
            .frame(height: 6)
        }
    }
}

struct GoalProgressChart: View {
    let goal: GoalRecommendation
    
    // Mock data for demonstration
    private var progressData: [ProgressDataPoint] {
        let days = 7
        return (0..<days).map { day in
            let progress = Double(day) / Double(days) * goal.currentValue
            return ProgressDataPoint(
                day: day,
                value: progress + Double.random(in: -0.1...0.1) * progress
            )
        }
    }
    
    var body: some View {
        Chart(progressData) { dataPoint in
            LineMark(
                x: .value("Day", dataPoint.day),
                y: .value("Progress", dataPoint.value)
            )
            .foregroundStyle(.blue)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            AreaMark(
                x: .value("Day", dataPoint.day),
                y: .value("Progress", dataPoint.value)
            )
            .foregroundStyle(.blue.opacity(0.1))
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(position: .bottom)
        }
    }
}

struct ProgressDataPoint: Identifiable {
    let id = UUID()
    let day: Int
    let value: Double
}

struct DifficultyBadge: View {
    let difficulty: GoalDifficulty
    
    var body: some View {
        Text(difficulty.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(difficulty.color).opacity(0.2))
            .foregroundColor(Color(difficulty.color))
            .cornerRadius(4)
    }
}

struct EmptyGoalsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Goals Available")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Try adjusting your filters or check back later for new AI-generated recommendations.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Preview

struct PersonalizedGoalsView_Previews: PreviewProvider {
    static var previews: some View {
        PersonalizedGoalsView()
    }
} 