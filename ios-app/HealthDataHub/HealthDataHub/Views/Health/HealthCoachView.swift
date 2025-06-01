import SwiftUI

struct HealthCoachView: View {
    @StateObject private var viewModel = HealthCoachViewModel()
    @State private var selectedFilter: CoachingType = .all
    @State private var showingInterventionDetail = false
    @State private var selectedIntervention: BehavioralIntervention?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Header with coaching summary
                    CoachingSummaryCard(viewModel: viewModel)
                    
                    // Filter tabs
                    CoachingFilterTabs(
                        selectedFilter: $selectedFilter,
                        onFilterChange: { filter in
                            viewModel.filterMessages(by: filter)
                        }
                    )
                    
                    // Messages section
                    MessagesSection(
                        messages: filteredMessages,
                        onMessageTap: { message in
                            viewModel.markMessageAsRead(message.id)
                        }
                    )
                    
                    // Active interventions
                    if !viewModel.behavioralInterventions.isEmpty {
                        InterventionsSection(
                            interventions: viewModel.behavioralInterventions,
                            onInterventionTap: { intervention in
                                selectedIntervention = intervention
                                showingInterventionDetail = true
                            }
                        )
                    }
                    
                    // Progress analysis
                    if let analysis = viewModel.progressAnalysis {
                        ProgressAnalysisCard(analysis: analysis)
                    }
                    
                    // Coaching history
                    HistorySection(history: viewModel.coachingHistory)
                }
                .padding()
            }
            .refreshable {
                viewModel.loadCoachingData()
            }
            .navigationTitle("Health Coach")
            .navigationBarTitleDisplayMode(.large)
            }
            .sheet(isPresented: $showingInterventionDetail) {
                if let intervention = selectedIntervention {
                InterventionDetailView(
                    intervention: intervention,
                    onProgressUpdate: { progress in
                        viewModel.updateInterventionProgress(intervention.id, progress: progress)
                }
                )
            }
        }
        .task {
            viewModel.loadCoachingData()
        }
    }
    
    private var filteredMessages: [CoachingMessage] {
        if selectedFilter == .all {
            return viewModel.coachingMessages
        }
        return viewModel.coachingMessages.filter { $0.coachingType == selectedFilter }
    }
}

// MARK: - Coaching Summary Card

struct CoachingSummaryCard: View {
    let viewModel: HealthCoachViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                Text("Your AI Health Coach")
                    .font(.headline)
                    .fontWeight(.semibold)
                    
                    Text("Personalized guidance for optimal health")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(viewModel.coachingMessages.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Messages")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if !viewModel.focusAreas.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Focus")
                .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(viewModel.focusAreas.prefix(2)) { area in
                        TodaysFocusRow(focusArea: area)
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Today's Focus Row

struct TodaysFocusRow: View {
    let focusArea: FocusArea
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: focusArea.icon)
                .foregroundColor(focusArea.color)
                .font(.caption)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(focusArea.title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(focusArea.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            PriorityIndicator(priority: MessagePriority(rawValue: focusArea.priority.rawValue.count) ?? .medium)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Coaching Filter Tabs

struct CoachingFilterTabs: View {
    @Binding var selectedFilter: CoachingType
    let onFilterChange: (CoachingType) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CoachingType.allCases, id: \.self) { type in
                    CoachingFilterTab(
                        type: type,
                        isSelected: selectedFilter == type,
                        onTap: {
                            selectedFilter = type
                            onFilterChange(type)
                    }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct CoachingFilterTab: View {
    let type: CoachingType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.caption)
                
                Text(type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? type.color.opacity(0.2) : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? type.color : .secondary)
                }
        .buttonStyle(PlainButtonStyle())
            }
}

// MARK: - Messages Section

struct MessagesSection: View {
    let messages: [CoachingMessage]
    let onMessageTap: (CoachingMessage) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Messages")
                    .font(.headline)
                    .fontWeight(.semibold)
            
            ForEach(messages.prefix(5)) { message in
                CoachingMessageCard(
                    message: message,
                    onTap: {
                        onMessageTap(message)
                }
                )
            }
        }
    }
}

// MARK: - Interventions Section

struct InterventionsSection: View {
    let interventions: [BehavioralIntervention]
    let onInterventionTap: (BehavioralIntervention) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Interventions")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(interventions) { intervention in
                InterventionCard(
                    intervention: intervention,
                    onTap: {
                        onInterventionTap(intervention)
                }
                )
            }
        }
    }
}

// MARK: - History Section

struct HistorySection: View {
    let history: [CoachingHistoryEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
            ForEach(history.prefix(5)) { entry in
                CoachingHistoryRow(entry: entry)
                        }
                    }
                }
            }

// MARK: - Message Card

struct CoachingMessageCard: View {
    let message: CoachingMessage
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: message.coachingType.icon)
                        .foregroundColor(message.coachingType.color)
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(message.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.leading)
                        
                        if let timestamp = message.timestamp {
                            Text(timestamp, style: .relative)
                            .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        PriorityIndicator(priority: MessagePriority(rawValue: message.priority) ?? .medium)
                        
                        if message.isRead == false {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
                
                Text(message.displayContent)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                if !message.displayActionItems.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Action Items:")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        ForEach(message.displayActionItems.prefix(2), id: \.self) { item in
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                Text(item)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                    }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        message.isRead == false ? message.coachingType.color.opacity(0.3) : Color(.systemGray5),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Intervention Card

struct InterventionCard: View {
    let intervention: BehavioralIntervention
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: intervention.interventionType.icon)
                        .foregroundColor(intervention.interventionType.color)
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let title = intervention.title {
                            Text(title)
                                .font(.subheadline)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.leading)
                        }
                        
                        Text(intervention.interventionType.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let progress = intervention.progress {
                        ProgressIndicator(progress: progress)
                    }
                }
                
                if let description = intervention.description {
                    Text(description)
                        .font(.caption)
                    .foregroundColor(.secondary)
                        .lineLimit(2)
                    .multilineTextAlignment(.leading)
                }
                
                if let progress = intervention.progress {
                    ProgressView(value: progress)
                        .tint(intervention.interventionType.color)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(intervention.interventionType.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Intervention Detail View

struct InterventionDetailView: View {
    let intervention: BehavioralIntervention
    let onProgressUpdate: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var currentProgress: Double
    
    init(intervention: BehavioralIntervention, onProgressUpdate: @escaping (Double) -> Void) {
        self.intervention = intervention
        self.onProgressUpdate = onProgressUpdate
        self._currentProgress = State(initialValue: intervention.progress ?? 0.0)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        if let title = intervention.title {
                            Text(title)
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        if let description = intervention.description {
                            Text(description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Progress section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Progress")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ProgressView(value: currentProgress)
                            .tint(intervention.interventionType.color)
                        
                        HStack {
                            Text("0%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(currentProgress * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                            Spacer()
                            Text("100%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $currentProgress, in: 0...1, step: 0.05)
                            .accentColor(intervention.interventionType.color)
                    }
                    
                    // Implementation steps
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Implementation Steps")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(Array(intervention.implementationSteps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .frame(width: 20, height: 20)
                                    .background(intervention.interventionType.color)
                                    .clipShape(Circle())
                                
                                Text(step)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    // Success metrics
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Success Metrics")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(intervention.successMetrics, id: \.self) { metric in
                            HStack(spacing: 8) {
                                Image(systemName: "target")
                                    .foregroundColor(intervention.interventionType.color)
                                    .font(.caption)
                                
                                Text(metric)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Intervention Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        onProgressUpdate(currentProgress)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Progress Analysis Card

struct ProgressAnalysisCard: View {
    let analysis: ProgressAnalysis
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
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

// MARK: - Preview

struct HealthCoachView_Previews: PreviewProvider {
    static var previews: some View {
        HealthCoachView()
    }
} 