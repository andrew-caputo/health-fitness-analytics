import SwiftUI

struct HealthCoachView: View {
    @State private var coachingMessages: [CoachingMessage] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading coaching insights...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if coachingMessages.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Your AI Health Coach")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Get personalized coaching based on your health data patterns")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("Get Coaching") {
                            // TODO: Trigger coaching
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(coachingMessages, id: \.id) { message in
                            CoachingMessageRow(message: message)
                        }
                    }
                }
            }
            .navigationTitle("Health Coach")
            .task {
                await loadCoachingMessages()
            }
        }
    }
    
    private func loadCoachingMessages() async {
        isLoading = true
        // TODO: Implement coaching API call
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isLoading = false
    }
}

struct CoachingMessageRow: View {
    let message: CoachingMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: messageIcon)
                    .foregroundColor(messageColor)
                
                Text(message.title)
                    .font(.headline)
                
                Spacer()
                
                Text(message.category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Text(message.content)
                .font(.body)
            
            if !message.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Action Items:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    ForEach(message.actionItems, id: \.self) { item in
                        Text("• \(item)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text(message.timestamp)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private var messageIcon: String {
        switch message.type {
        case "motivation":
            return "heart.fill"
        case "warning":
            return "exclamationmark.triangle.fill"
        case "tip":
            return "lightbulb.fill"
        default:
            return "message.fill"
        }
    }
    
    private var messageColor: Color {
        switch message.type {
        case "motivation":
            return .green
        case "warning":
            return .orange
        case "tip":
            return .yellow
        default:
            return .blue
        }
    }
}

struct CoachingMessage: Codable, Identifiable {
    let id: String
    let title: String
    let content: String
    let type: String
    let category: String
    let actionItems: [String]
    let timestamp: String
}

#Preview {
    HealthCoachView()
} 