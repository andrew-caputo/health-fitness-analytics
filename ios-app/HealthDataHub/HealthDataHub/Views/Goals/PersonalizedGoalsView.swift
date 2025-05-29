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
                        PersonalizedGoalRecommendationCard(goal: goal) {
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
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.activeGoals) { goal in
                        ActiveGoalProgressRow(goal: goal) {
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
            Text("Goal Coordination")
                .font(.headline)
                .fontWeight(.semibold)
            
            if viewModel.goalCoordinations.isEmpty {
                Text("No goal interactions detected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.goalCoordinations) { coordination in
                        GoalCoordinationCard(coordination: coordination)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct GoalDetailView: View {
    let goal: GoalRecommendation
    let viewModel: PersonalizedGoalsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Goal Details")
                        .font(.title2)
                        .bold()
                    
                    Text("Goal: \(goal.title)")
                        .font(.headline)
                    
                    Text(goal.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Target: \(Int(goal.targetValue)) \(goal.unit)")
                        .font(.subheadline)
                    
                    Text("Timeline: \(goal.timelineDescription)")
                        .font(.subheadline)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Goal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct GoalCoordinationView: View {
    let viewModel: PersonalizedGoalsViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Goal Coordination")
                        .font(.title2)
                        .bold()
                    
                    Text("Coordinate your goals for better results")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.goalCoordinations) { coordination in
                            GoalCoordinationCard(coordination: coordination)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Coordination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct GoalCoordinationCard: View {
    let coordination: GoalCoordination
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(coordination.title)
                .font(.headline)
            
            Text(coordination.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !coordination.synergies.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Synergies:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                    
                    ForEach(coordination.synergies, id: \.self) { synergy in
                        Text("• \(synergy)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !coordination.conflicts.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conflicts:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    
                    ForEach(coordination.conflicts, id: \.self) { conflict in
                        Text("• \(conflict)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack {
                Text("Impact Score")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(coordination.impactScore, specifier: "%.1f")")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct GoalAdjustmentView: View {
    let goal: GoalRecommendation
    let viewModel: PersonalizedGoalsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var adjustedTarget: Double
    
    init(goal: GoalRecommendation, viewModel: PersonalizedGoalsViewModel) {
        self.goal = goal
        self.viewModel = viewModel
        self._adjustedTarget = State(initialValue: goal.targetValue)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Adjust Goal Target")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Current: \(Int(goal.targetValue)) \(goal.unit)")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Stepper(value: $adjustedTarget, in: 1...100000, step: goal.targetValue < 100 ? 1 : 100) {
                    Text("New Target: \(Int(adjustedTarget)) \(goal.unit)")
                        .font(.headline)
                }
                
                Button("Save Adjustment") {
                    Task {
                        try? await viewModel.requestGoalAdjustment(for: goal.id, newTarget: adjustedTarget)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Adjust Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PersonalizedGoalRecommendationCard: View {
    let goal: GoalRecommendation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(goal.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(goal.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Text("\(Int(goal.confidence * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("confidence")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Label("\(Int(goal.targetValue)) \(goal.unit)", systemImage: "target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(goal.timelineDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ActiveGoalProgressRow: View {
    let goal: GoalRecommendation
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    ProgressView(value: 0.65) // Mock progress
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    
                    Text("65% complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CategoryFilterButton: View {
    let category: GoalCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                Text(category.displayName)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DifficultyFilterButton: View {
    let difficulty: GoalDifficulty
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(difficulty.displayName)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? difficulty.color : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyGoalsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Goals Available")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Try adjusting your filters or check back later for new recommendations.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Mock Data Generation

extension PersonalizedGoalsView {
    private func createMockProgressData() -> [ProgressDataPoint] {
        return (0..<30).map { day in
            ProgressDataPoint(
                id: UUID().uuidString,
                day: day,
                date: Calendar.current.date(byAdding: .day, value: day, to: Date()) ?? Date(),
                value: Double.random(in: 0.6...1.0)
            )
        }
    }
}

// MARK: - Preview

struct PersonalizedGoalsView_Previews: PreviewProvider {
    static var previews: some View {
        PersonalizedGoalsView()
    }
} 