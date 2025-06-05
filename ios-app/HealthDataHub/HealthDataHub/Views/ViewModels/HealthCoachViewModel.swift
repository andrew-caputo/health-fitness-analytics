import Foundation
import SwiftUI
import Combine

@MainActor
class HealthCoachViewModel: ObservableObject {
    @Published var coachingMessages: [CoachingMessage] = []
    @Published var behavioralInterventions: [BehavioralIntervention] = []
    @Published var progressAnalysis: ProgressAnalysis?
    @Published var focusAreas: [FocusArea] = []
    @Published var coachingHistory: [CoachingHistoryEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedCoachingType: CoachingType = .all
    @Published var selectedPriority: MessagePriority = .medium
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadMockData()
    }
    
    func loadCoachingData() {
        isLoading = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            // Data would be loaded from API here
        }
    }
    
    func filterMessages(by type: CoachingType) {
        selectedCoachingType = type
        // Filter implementation would go here
    }
    
    func markMessageAsRead(_ messageId: String) {
        if let index = coachingMessages.firstIndex(where: { $0.id == messageId }) {
            coachingMessages[index].isRead = true
        }
    }
    
    func startIntervention(_ intervention: BehavioralIntervention) {
        // Implementation for starting intervention
    }
    
    func updateInterventionProgress(_ interventionId: String, progress: Double) {
        if let index = behavioralInterventions.firstIndex(where: { $0.id == interventionId }) {
            behavioralInterventions[index].progress = progress
        }
    }
    
    private func loadMockData() {
        // Real backend integration - replace mock data
        print("🧠 Loading real coaching data from backend API...")
        
        Task {
            await MainActor.run {
                isLoading = true
            }
            
            do {
                // Load coaching data concurrently
                async let messagesTask = loadRealCoachingMessages()
                async let interventionsTask = loadRealInterventions()
                async let progressTask = loadRealProgressAnalysis()
                
                let (realMessages, realInterventions, realProgress) = try await (messagesTask, interventionsTask, progressTask)
                
                await MainActor.run {
                    self.coachingMessages = realMessages
                    self.behavioralInterventions = realInterventions
                    self.progressAnalysis = realProgress
                    
                    // Generate focus areas from messages and interventions
                    self.focusAreas = self.generateFocusAreas(from: realMessages, interventions: realInterventions)
                    
                    // Generate coaching history from messages
                    self.coachingHistory = self.generateCoachingHistory(from: realMessages)
                    
                    self.isLoading = false
                }
                
                print("✅ Loaded \(realMessages.count) coaching messages, \(realInterventions.count) interventions")
            } catch {
                print("❌ Error loading real coaching data: \(error)")
                print("📱 Using fallback: Empty coaching data")
                
                await MainActor.run {
                    self.coachingMessages = []
                    self.behavioralInterventions = []
                    self.focusAreas = []
                    self.coachingHistory = []
                    self.progressAnalysis = nil
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Real Backend Integration Methods
    
    private func loadRealCoachingMessages() async throws -> [CoachingMessage] {
        print("💬 Fetching real coaching messages from backend API...")
        do {
            let response = try await withTimeout(seconds: 10) {
                try await NetworkManager.shared.fetchCoachingMessages()
            }
            
            // Convert backend messages to app model
            let messages = response.messages.map { message in
                CoachingMessage(
                    id: message.id,
                    coachingType: CoachingType(rawValue: message.coaching_type) ?? .educational,
                    title: message.title,
                    message: message.message,
                    content: message.content,
                    timing: InterventionTiming(rawValue: message.timing) ?? .daily,
                    timestamp: parseDate(message.timestamp) ?? Date(),
                    priority: message.priority,
                    targetMetrics: message.target_metrics,
                    actionableSteps: message.actionable_steps,
                    actionItems: message.actionable_steps,
                    expectedOutcome: message.expected_outcome,
                    followUpDays: message.follow_up_days,
                    personalizationFactors: message.personalization_factors,
                    focusAreas: message.focus_areas,
                    isRead: message.is_read
                )
            }
            
            print("✅ Converted \(messages.count) backend coaching messages to app model")
            return messages
        } catch {
            print("❌ Error fetching real coaching messages: \(error)")
            throw error
        }
    }
    
    private func loadRealInterventions() async throws -> [BehavioralIntervention] {
        print("🎯 Fetching real interventions from backend API...")
        do {
            let response = try await withTimeout(seconds: 10) {
                try await NetworkManager.shared.fetchCoachingInterventions()
            }
            
            // Convert backend interventions to app model
            let interventions = response.interventions.map { intervention in
                BehavioralIntervention(
                    id: intervention.id,
                    title: intervention.title,
                    description: intervention.description,
                    interventionType: InterventionType(rawValue: intervention.intervention_type) ?? .habitFormation,
                    targetBehavior: intervention.target_behavior,
                    currentPattern: intervention.current_pattern,
                    desiredPattern: intervention.desired_pattern,
                    interventionStrategy: intervention.strategy,
                    strategy: intervention.strategy,
                    implementationSteps: intervention.implementation_steps,
                    successMetrics: intervention.success_metrics,
                    timelineDays: intervention.duration_days,
                    durationDays: intervention.duration_days,
                    difficultyLevel: intervention.difficulty_level,
                    progress: intervention.progress,
                    startDate: parseDate(intervention.start_date)
                )
            }
            
            print("✅ Converted \(interventions.count) backend interventions to app model")
            return interventions
        } catch {
            print("❌ Error fetching real interventions: \(error)")
            throw error
        }
    }
    
    private func loadRealProgressAnalysis() async throws -> ProgressAnalysis? {
        print("📊 Fetching real progress analysis from backend API...")
        do {
            let response = try await withTimeout(seconds: 10) {
                try await NetworkManager.shared.fetchCoachingProgress()
            }
            
            // Convert backend progress analysis to app model
            let keyMetrics = response.key_metrics.map { metric in
                MetricProgress(
                    metric: metric.metric,
                    currentValue: metric.current_value,
                    previousValue: metric.previous_value,
                    change: metric.change,
                    isImprovement: metric.is_improvement,
                    changeText: metric.change_text
                )
            }
            
            let progressAnalysis = ProgressAnalysis(
                id: response.id,
                analysisDate: parseDate(response.analysis_date) ?? Date(),
                timeframe: response.timeframe,
                summary: response.summary,
                overallScore: Int(response.overall_score),
                keyMetrics: keyMetrics,
                recommendations: response.improvements,
                focusAreas: response.areas_for_focus,
                nextAnalysisDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            )
            
            print("✅ Converted backend progress analysis to app model")
            return progressAnalysis
        } catch {
            print("❌ Error fetching real progress analysis: \(error)")
            throw error
        }
    }
    
    private func generateFocusAreas(from messages: [CoachingMessage], interventions: [BehavioralIntervention]) -> [FocusArea] {
        // Generate focus areas based on coaching messages and interventions
        var areas: [FocusArea] = []
        
        // Extract unique focus areas from messages
        let messageFocusAreas = Set(messages.flatMap { $0.focusAreas })
        
        for (index, area) in messageFocusAreas.enumerated() {
            let relatedMessages = messages.filter { $0.focusAreas.contains(area) }
            let priority: FocusPriority = relatedMessages.contains { $0.priority >= 4 } ? .high : 
                                           relatedMessages.contains { $0.priority >= 3 } ? .medium : .low
            
            areas.append(FocusArea(
                id: "focus_\(index)",
                title: area.capitalized,
                description: "Focus area based on coaching insights",
                priority: priority,
                icon: iconForFocusArea(area),
                color: colorForFocusArea(area),
                actionItems: relatedMessages.flatMap { $0.displayActionItems },
                expectedImpact: relatedMessages.first?.expectedOutcome ?? "Improved health outcomes",
                timeframe: "2-4 weeks"
            ))
        }
        
        return areas
    }
    
    private func generateCoachingHistory(from messages: [CoachingMessage]) -> [CoachingHistoryEntry] {
        // Generate history from read messages
        return messages.filter { $0.isRead ?? false }.map { message in
            CoachingHistoryEntry(
                id: "hist_\(message.id)",
                type: message.coachingType == .motivational ? .celebratory : .educational,
                title: message.title,
                summary: message.message,
                timestamp: message.timestamp ?? Date(),
                outcome: message.expectedOutcome
            )
        }
    }
    
    private func iconForFocusArea(_ area: String) -> String {
        switch area.lowercased() {
        case "sleep": return "bed.double.fill"
        case "nutrition": return "fork.knife"
        case "activity", "exercise": return "figure.run"
        case "recovery": return "heart.fill"
        default: return "target"
        }
    }
    
    private func colorForFocusArea(_ area: String) -> Color {
        switch area.lowercased() {
        case "sleep": return .purple
        case "nutrition": return .green
        case "activity", "exercise": return .blue
        case "recovery": return .red
        default: return .gray
        }
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
} 