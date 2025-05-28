import SwiftUI

struct HealthCoachView: View {
    @StateObject private var viewModel = HealthCoachViewModel()
    @State private var selectedMessage: CoachingMessage?
    @State private var showingMessageDetail = false
    @State private var showingInterventionDetail = false
    @State private var selectedIntervention: BehavioralIntervention?
    @State private var selectedCoachingType: CoachingType = .all
    @State private var showingProgressAnalysis = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // AI Coach Header
                    aiCoachHeader
                    
                    // Coaching Type Filter
                    coachingTypeFilter
                    
                    // Today's Focus
                    todaysFocusSection
                    
                    // Recent Messages
                    recentMessagesSection
                    
                    // Behavioral Interventions
                    behavioralInterventionsSection
                    
                    // Progress Analysis
                    progressAnalysisSection
                    
                    // Coaching History
                    coachingHistorySection
                }
                .padding()
            }
            .navigationTitle("Health Coach")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Analysis") {
                        showingProgressAnalysis = true
                    }
                }
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .sheet(isPresented: $showingMessageDetail) {
                if let message = selectedMessage {
                    CoachingMessageDetailView(message: message, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showingInterventionDetail) {
                if let intervention = selectedIntervention {
                    InterventionDetailView(intervention: intervention, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showingProgressAnalysis) {
                ProgressAnalysisView(viewModel: viewModel)
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
    }
    
    private var aiCoachHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                    .font(.title2)
                Text("Your AI Health Coach")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            Text("Personalized guidance based on your health patterns, goals, and progress to help you achieve optimal wellness.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            // Coach Stats
            HStack(spacing: 20) {
                CoachStatView(
                    title: "Messages",
                    value: "\(viewModel.totalMessages)",
                    icon: "message.fill",
                    color: .blue
                )
                
                CoachStatView(
                    title: "Interventions",
                    value: "\(viewModel.activeInterventions.count)",
                    icon: "lightbulb.fill",
                    color: .yellow
                )
                
                CoachStatView(
                    title: "Success Rate",
                    value: "\(Int(viewModel.successRate * 100))%",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var coachingTypeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CoachingType.allCases, id: \.self) { type in
                    CoachingTypeButton(
                        type: type,
                        isSelected: selectedCoachingType == type,
                        count: viewModel.getMessageCount(for: type)
                    ) {
                        selectedCoachingType = type
                        viewModel.filterMessages(by: type)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var todaysFocusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Focus")
                    .font(.headline)
                    .fontWeight(.semibold)
                Image(systemName: "target")
                    .foregroundColor(.orange)
                Spacer()
                Text(Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let focusArea = viewModel.todaysFocus {
                TodaysFocusCard(focusArea: focusArea)
            } else {
                Text("No specific focus area identified for today. Keep up your great work!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
    
    private var recentMessagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Coaching")
                    .font(.headline)
                    .fontWeight(.semibold)
                Image(systemName: "message.badge.filled.fill")
                    .foregroundColor(.blue)
                Spacer()
                Text("\(viewModel.filteredMessages.count) messages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.filteredMessages.isEmpty {
                EmptyCoachingView(type: selectedCoachingType)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredMessages.prefix(3)) { message in
                        CoachingMessageCard(message: message) {
                            selectedMessage = message
                            showingMessageDetail = true
                        }
                    }
                    
                    if viewModel.filteredMessages.count > 3 {
                        Button("View All Messages") {
                            // Navigate to full message list
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .padding()
                    }
                }
            }
        }
    }
    
    private var behavioralInterventionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Active Interventions")
                    .font(.headline)
                    .fontWeight(.semibold)
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Spacer()
                Text("\(viewModel.activeInterventions.count) active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if viewModel.activeInterventions.isEmpty {
                Text("No active interventions. Your health patterns are looking great!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.activeInterventions) { intervention in
                        InterventionCard(intervention: intervention) {
                            selectedIntervention = intervention
                            showingInterventionDetail = true
                        }
                    }
                }
            }
        }
    }
    
    private var progressAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Progress Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.green)
                Spacer()
                Button("View Details") {
                    showingProgressAnalysis = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if let analysis = viewModel.latestProgressAnalysis {
                ProgressInsightCard(analysis: analysis)
            } else {
                Text("Analyzing your progress patterns...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
    
    private var coachingHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Coaching History")
                    .font(.headline)
                    .fontWeight(.semibold)
                Image(systemName: "clock.fill")
                    .foregroundColor(.gray)
                Spacer()
            }
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.coachingHistory.prefix(5)) { entry in
                    CoachingHistoryRow(entry: entry)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct CoachStatView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CoachingTypeButton: View {
    let type: CoachingType
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                    .font(.caption)
                Text(type.displayName)
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
            .background(isSelected ? type.color : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

struct TodaysFocusCard: View {
    let focusArea: FocusArea
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: focusArea.icon)
                    .foregroundColor(focusArea.color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(focusArea.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(focusArea.priority.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(focusArea.priority.color.opacity(0.2))
                        .foregroundColor(focusArea.priority.color)
                        .cornerRadius(4)
                }
                
                Spacer()
            }
            
            Text(focusArea.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !focusArea.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recommended Actions:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(focusArea.actionItems.prefix(3), id: \.self) { action in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text(action)
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
                .stroke(focusArea.color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct CoachingMessageCard: View {
    let message: CoachingMessage
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: message.coachingType.icon)
                        .foregroundColor(message.coachingType.color)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.leading)
                        
                        Text(message.coachingType.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(message.coachingType.color.opacity(0.2))
                            .foregroundColor(message.coachingType.color)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(message.timestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        PriorityIndicator(priority: message.priority)
                    }
                }
                
                Text(message.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                
                if !message.actionItems.isEmpty {
                    HStack {
                        Image(systemName: "list.bullet")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(message.actionItems.count) action items")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Spacer()
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

struct InterventionCard: View {
    let intervention: BehavioralIntervention
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: intervention.interventionType.icon)
                        .foregroundColor(intervention.interventionType.color)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(intervention.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.leading)
                        
                        Text(intervention.interventionType.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(intervention.interventionType.color.opacity(0.2))
                            .foregroundColor(intervention.interventionType.color)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(intervention.durationDays) days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ProgressIndicator(progress: intervention.progress)
                    }
                }
                
                Text(intervention.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(intervention.interventionType.color)
                            .frame(width: geometry.size.width * intervention.progress, height: 4)
                            .cornerRadius(2)
                            .animation(.easeInOut(duration: 0.5), value: intervention.progress)
                    }
                }
                .frame(height: 4)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProgressInsightCard: View {
    let analysis: ProgressAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.green)
                Text("Weekly Progress")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text(analysis.analysisDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(analysis.summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Key metrics
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(analysis.keyMetrics.prefix(4), id: \.metric) { metric in
                    MetricProgressView(metric: metric)
                }
            }
            
            if !analysis.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key Recommendations:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(analysis.recommendations.prefix(2), id: \.self) { recommendation in
                        HStack(spacing: 4) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(recommendation)
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
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

struct CoachingHistoryRow: View {
    let entry: CoachingHistoryEntry
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.type.icon)
                .foregroundColor(entry.type.color)
                .font(.caption)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(entry.summary)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(entry.timestamp, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct MetricProgressView: View {
    let metric: MetricProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(metric.metric)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text(metric.changeText)
                    .font(.caption2)
                    .foregroundColor(metric.isImprovement ? .green : .red)
            }
            
            Text(metric.currentValue)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(6)
    }
}

struct PriorityIndicator: View {
    let priority: MessagePriority
    
    var body: some View {
        Circle()
            .fill(priority.color)
            .frame(width: 8, height: 8)
    }
}

struct ProgressIndicator: View {
    let progress: Double
    
    var body: some View {
        Text("\(Int(progress * 100))%")
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
    }
}

struct EmptyCoachingView: View {
    let type: CoachingType
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: type.icon)
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No \(type.displayName) Messages")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Your AI coach will provide \(type.displayName.lowercased()) guidance as you progress on your health journey.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Supporting Types

enum CoachingType: String, CaseIterable {
    case all = "all"
    case motivational = "motivational"
    case educational = "educational"
    case behavioral = "behavioral"
    case corrective = "corrective"
    case celebratory = "celebratory"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .motivational: return "Motivational"
        case .educational: return "Educational"
        case .behavioral: return "Behavioral"
        case .corrective: return "Corrective"
        case .celebratory: return "Celebratory"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "message"
        case .motivational: return "heart.fill"
        case .educational: return "book.fill"
        case .behavioral: return "brain.head.profile"
        case .corrective: return "exclamationmark.triangle.fill"
        case .celebratory: return "party.popper.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .blue
        case .motivational: return .red
        case .educational: return .green
        case .behavioral: return .purple
        case .corrective: return .orange
        case .celebratory: return .yellow
        }
    }
}

// MARK: - Preview

struct HealthCoachView_Previews: PreviewProvider {
    static var previews: some View {
        HealthCoachView()
    }
} 