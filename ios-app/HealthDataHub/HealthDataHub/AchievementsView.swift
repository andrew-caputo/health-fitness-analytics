import SwiftUI

struct AchievementsView: View {
    @State private var achievements: [Achievement] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading achievements...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if achievements.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        
                        Text("No Achievements Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Keep tracking your health data to unlock achievements!")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Sync Health Data") {
                            // TODO: Trigger sync
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(achievements, id: \.id) { achievement in
                            AchievementRow(achievement: achievement)
                        }
                    }
                }
            }
            .navigationTitle("Achievements")
            .task {
                await loadAchievements()
            }
        }
    }
    
    private func loadAchievements() async {
        isLoading = true
        // TODO: Implement achievements API call
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isLoading = false
    }
}

struct AchievementRow: View {
    let achievement: Achievement
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundColor(.yellow)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.headline)
                
                Text(achievement.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Earned \(achievement.dateEarned)")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct Achievement: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let category: String
    let dateEarned: String
}

#Preview {
    AchievementsView()
} 