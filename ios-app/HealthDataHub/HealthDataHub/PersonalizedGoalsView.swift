import SwiftUI

struct PersonalizedGoalsView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @State private var goals: [Goal] = []
    @State private var isLoading = false
    @State private var showingAddGoal = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading goals...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if goals.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "target")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("No Goals Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Set your first health goal to get personalized recommendations")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Add Goal") {
                            showingAddGoal = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(goals, id: \.id) { goal in
                            GoalRow(goal: goal)
                        }
                    }
                }
            }
            .navigationTitle("Goals")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        showingAddGoal = true
                    }
                }
            }
            .task {
                await loadGoals()
            }
            .sheet(isPresented: $showingAddGoal) {
                AddGoalView()
            }
        }
    }
    
    private func loadGoals() async {
        isLoading = true
        // TODO: Implement goals API call
        // For now, we'll show placeholder empty state
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        isLoading = false
    }
}

struct GoalRow: View {
    let goal: Goal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.title)
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(goal.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: goal.progress)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text(goal.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct AddGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var goalTitle = ""
    @State private var goalDescription = ""
    @State private var selectedCategory = "Fitness"
    
    let categories = ["Fitness", "Nutrition", "Sleep", "Mindfulness"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Goal Details") {
                    TextField("Goal title", text: $goalTitle)
                    TextField("Description", text: $goalDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("Add Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // TODO: Implement save goal
                        dismiss()
                    }
                    .disabled(goalTitle.isEmpty)
                }
            }
        }
    }
}

struct Goal: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let category: String
    let progress: Double
    let targetDate: String
}

#Preview {
    PersonalizedGoalsView()
} 