import Foundation
import Combine

@MainActor
class HealthCoachViewModel: ObservableObject {
    @Published var coachingMessages: [CoachingMessage] = []
    @Published var filteredMessages: [CoachingMessage] = []
    @Published var activeInterventions: [BehavioralIntervention] = []
    @Published var coachingHistory: [CoachingHistoryEntry] = []
    @Published var todaysFocus: FocusArea?
    @Published var latestProgressAnalysis: ProgressAnalysis?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager = NetworkManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Computed properties
    var totalMessages: Int {
        coachingMessages.count
    }
    
    var successRate: Double {
        // Calculate success rate based on completed interventions
        let completedInterventions = activeInterventions.filter { $0.progress >= 1.0 }
        guard !activeInterventions.isEmpty else { return 0.85 } // Default rate
        return Double(completedInterventions.count) / Double(activeInterventions.count)
    }
    
    var priorityMessages: [CoachingMessage] {
        filteredMessages.filter { $0.priority >= 3 }.sorted { $0.priority > $1.priority }
    }
    
    init() {
        setupMockData()
    }
    
    func loadInitialData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let messages = fetchCoachingMessages()
            async let interventions = fetchBehavioralInterventions()
            async let analysis = fetchProgressAnalysis()
            
            let (fetchedMessages, fetchedInterventions, fetchedAnalysis) = try await (messages, interventions, analysis)
            
            self.coachingMessages = fetchedMessages
            self.filteredMessages = fetchedMessages
            self.activeInterventions = fetchedInterventions
            self.latestProgressAnalysis = fetchedAnalysis
            self.todaysFocus = generateTodaysFocus()
            self.coachingHistory = generateCoachingHistory()
            
        } catch {
            self.errorMessage = "Failed to load coaching data: \(error.localizedDescription)"
            print("Error loading coaching data: \(error)")
        }
        
        isLoading = false
    }
    
    func refreshData() async {
        await loadInitialData()
    }
    
    func filterMessages(by type: CoachingType) {
        if type == .all {
            filteredMessages = coachingMessages
        } else {
            filteredMessages = coachingMessages.filter { $0.coachingType == type }
        }
    }
    
    func getMessageCount(for type: CoachingType) -> Int {
        if type == .all {
            return coachingMessages.count
        }
        return coachingMessages.filter { $0.coachingType == type }.count
    }
    
    func markMessageAsRead(_ messageId: String) {
        if let index = coachingMessages.firstIndex(where: { $0.id == messageId }) {
            // In a real implementation, this would update the backend
            print("Marking message as read: \(messageId)")
        }
    }
    
    func startIntervention(_ interventionId: String) async throws {
        let endpoint = "/ai/coaching/interventions/\(interventionId)/start"
        let _: BehavioralIntervention = try await networkManager.request(
            endpoint: endpoint,
            method: .POST
        )
        
        // Update local state
        await refreshData()
    }
    
    func updateInterventionProgress(_ interventionId: String, progress: Double) async throws {
        let endpoint = "/ai/coaching/interventions/\(interventionId)/progress"
        let requestBody = ["progress": progress]
        
        let _: BehavioralIntervention = try await networkManager.request(
            endpoint: endpoint,
            method: .PUT,
            body: requestBody
        )
        
        // Update local intervention
        if let index = activeInterventions.firstIndex(where: { $0.id == interventionId }) {
            activeInterventions[index].progress = progress
        }
    }
    
    // MARK: - API Calls
    
    private func fetchCoachingMessages() async throws -> [CoachingMessage] {
        let endpoint = "/ai/coaching/messages"
        let response: CoachingMessagesResponse = try await networkManager.request(
            endpoint: endpoint,
            method: .GET
        )
        return response.messages
    }
    
    private func fetchBehavioralInterventions() async throws -> [BehavioralIntervention] {
        let endpoint = "/ai/coaching/interventions"
        let response: [BehavioralIntervention] = try await networkManager.request(
            endpoint: endpoint,
            method: .GET
        )
        return response
    }
    
    private func fetchProgressAnalysis() async throws -> ProgressAnalysis {
        let endpoint = "/ai/coaching/progress"
        let analysis: ProgressAnalysis = try await networkManager.request(
            endpoint: endpoint,
            method: .GET
        )
        return analysis
    }
    
    // MARK: - Mock Data Setup
    
    private func setupMockData() {
        coachingMessages = createMockCoachingMessages()
        filteredMessages = coachingMessages
        activeInterventions = createMockBehavioralInterventions()
        coachingHistory = generateCoachingHistory()
        todaysFocus = generateTodaysFocus()
        latestProgressAnalysis = generateMockProgressAnalysis()
    }
    
    private func createMockCoachingMessages() -> [CoachingMessage] {
        return [
            CoachingMessage(
                id: "msg_1",
                coachingType: .motivational,
                title: "Great Progress on Your Step Goal!",
                content: "You've been consistently hitting your daily step targets this week. Your dedication is paying off with improved cardiovascular health and energy levels. Keep up the fantastic work!",
                timestamp: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
                priority: 4,
                actionItems: [
                    "Continue your current walking routine",
                    "Consider increasing your daily target by 500 steps",
                    "Track how you feel after reaching your goals"
                ],
                focusAreas: ["activity", "motivation"],
                expectedOutcome: "Sustained motivation and potential goal progression",
                isRead: false
            ),
            
            CoachingMessage(
                id: "msg_2",
                coachingType: .educational,
                title: "Understanding Sleep Quality Metrics",
                content: "Your sleep data shows room for improvement in deep sleep duration. Deep sleep is crucial for physical recovery, memory consolidation, and immune function. Here's what you can do to optimize it.",
                timestamp: Calendar.current.date(byAdding: .hour, value: -6, to: Date()) ?? Date(),
                priority: 3,
                actionItems: [
                    "Maintain consistent bedtime routine",
                    "Keep bedroom temperature between 65-68°F",
                    "Avoid screens 1 hour before bed",
                    "Consider magnesium supplementation"
                ],
                focusAreas: ["sleep", "recovery"],
                expectedOutcome: "Improved deep sleep percentage and recovery quality",
                isRead: false
            ),
            
            CoachingMessage(
                id: "msg_3",
                coachingType: .behavioral,
                title: "Building Better Hydration Habits",
                content: "Your water intake has been inconsistent lately. Let's work on creating automatic hydration triggers throughout your day to make this habit effortless and sustainable.",
                timestamp: Calendar.current.date(byAdding: .hour, value: -12, to: Date()) ?? Date(),
                priority: 5,
                actionItems: [
                    "Set hourly hydration reminders",
                    "Place water bottles in visible locations",
                    "Link water intake to existing habits",
                    "Track intake with visual cues"
                ],
                focusAreas: ["nutrition", "habits"],
                expectedOutcome: "Consistent daily hydration without conscious effort",
                isRead: true
            ),
            
            CoachingMessage(
                id: "msg_4",
                coachingType: .corrective,
                title: "Heart Rate Variability Concerns",
                content: "Your HRV has been declining over the past week, which may indicate increased stress or insufficient recovery. Let's address this before it impacts your overall health and performance.",
                timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                priority: 5,
                actionItems: [
                    "Prioritize 7-8 hours of sleep",
                    "Reduce training intensity temporarily",
                    "Practice stress management techniques",
                    "Consider meditation or breathing exercises"
                ],
                focusAreas: ["recovery", "stress"],
                expectedOutcome: "Improved HRV and stress resilience",
                isRead: false
            ),
            
            CoachingMessage(
                id: "msg_5",
                coachingType: .celebratory,
                title: "Congratulations on Your Streak!",
                content: "Amazing work! You've maintained your exercise routine for 14 consecutive days. This consistency is building lasting habits and significant health improvements. You should be proud of this achievement!",
                timestamp: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                priority: 2,
                actionItems: [
                    "Celebrate this milestone appropriately",
                    "Reflect on what strategies worked best",
                    "Set your next streak goal",
                    "Share your success with friends"
                ],
                focusAreas: ["motivation", "habits"],
                expectedOutcome: "Sustained motivation and habit reinforcement",
                isRead: true
            ),
            
            CoachingMessage(
                id: "msg_6",
                coachingType: .preventive,
                title: "Preventing Workout Plateau",
                content: "Your workout performance has plateaued recently. This is normal, but let's proactively adjust your routine to continue making progress and prevent stagnation.",
                timestamp: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                priority: 3,
                actionItems: [
                    "Vary your workout intensity",
                    "Incorporate new exercise types",
                    "Ensure adequate protein intake",
                    "Schedule deload weeks"
                ],
                focusAreas: ["exercise", "progression"],
                expectedOutcome: "Continued fitness improvements and plateau prevention",
                isRead: false
            )
        ]
    }
    
    private func createMockBehavioralInterventions() -> [BehavioralIntervention] {
        return [
            BehavioralIntervention(
                id: "int_1",
                title: "Morning Hydration Habit",
                description: "Establish a consistent morning hydration routine to kickstart your metabolism and improve daily water intake.",
                interventionType: .habitFormation,
                targetBehavior: "Drink 16oz of water immediately upon waking",
                currentPattern: "Inconsistent morning hydration, often forgetting until mid-morning",
                desiredPattern: "Automatic 16oz water consumption within 5 minutes of waking",
                strategy: "Implementation intention and environmental design",
                implementationSteps: [
                    "Place water bottle on nightstand before bed",
                    "Set phone reminder for wake-up time",
                    "Link to existing morning routine (before coffee)",
                    "Track completion for 21 days"
                ],
                durationDays: 21,
                progress: 0.65,
                startDate: Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date(),
                successMetrics: ["Daily completion rate", "Morning energy levels", "Overall hydration"]
            ),
            
            BehavioralIntervention(
                id: "int_2",
                title: "Evening Wind-Down Routine",
                description: "Create a consistent pre-sleep routine to improve sleep quality and duration through better sleep hygiene practices.",
                interventionType: .environmentalDesign,
                targetBehavior: "Complete 30-minute wind-down routine before bed",
                currentPattern: "Inconsistent bedtime, often using devices until sleep",
                desiredPattern: "Structured 30-minute routine ending with lights out",
                strategy: "Environmental cues and routine stacking",
                implementationSteps: [
                    "Set bedroom lighting to dim 1 hour before bed",
                    "Create device-free bedroom environment",
                    "Establish reading or meditation routine",
                    "Use sleep tracking for feedback"
                ],
                durationDays: 28,
                progress: 0.43,
                startDate: Calendar.current.date(byAdding: .day, value: -12, to: Date()) ?? Date(),
                successMetrics: ["Sleep quality score", "Time to fall asleep", "Morning alertness"]
            ),
            
            BehavioralIntervention(
                id: "int_3",
                title: "Stress Response Management",
                description: "Develop healthy coping mechanisms for stress through mindfulness and breathing techniques to improve HRV and overall well-being.",
                interventionType: .cognitiveRestructuring,
                targetBehavior: "Use 5-minute breathing exercise when stress is detected",
                currentPattern: "Reactive stress responses, often leading to poor decisions",
                desiredPattern: "Proactive stress management with immediate intervention",
                strategy: "Mindfulness-based stress reduction and trigger awareness",
                implementationSteps: [
                    "Learn 4-7-8 breathing technique",
                    "Set HRV-based stress alerts",
                    "Practice daily 10-minute meditation",
                    "Journal stress triggers and responses"
                ],
                durationDays: 35,
                progress: 0.29,
                startDate: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date(),
                successMetrics: ["HRV improvement", "Stress response time", "Mood ratings"]
            )
        ]
    }
    
    private func generateTodaysFocus() -> FocusArea {
        return FocusArea(
            id: "focus_today",
            title: "Optimize Recovery",
            description: "Your recent data suggests focusing on recovery will have the biggest impact on your overall health progress. Your HRV has been declining and sleep quality could be improved.",
            priority: .high,
            icon: "bed.double.fill",
            color: .blue,
            actionItems: [
                "Aim for 8 hours of sleep tonight",
                "Practice 10 minutes of meditation",
                "Reduce training intensity by 20%",
                "Stay hydrated throughout the day"
            ],
            expectedImpact: "Improved HRV, better sleep quality, enhanced next-day performance",
            timeframe: "Today and tonight"
        )
    }
    
    private func generateCoachingHistory() -> [CoachingHistoryEntry] {
        return [
            CoachingHistoryEntry(
                id: "hist_1",
                type: .motivational,
                title: "Step Goal Achievement",
                summary: "Celebrated reaching 10K steps milestone",
                timestamp: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
                outcome: "Increased motivation and goal progression"
            ),
            
            CoachingHistoryEntry(
                id: "hist_2",
                type: .educational,
                title: "Sleep Optimization Tips",
                summary: "Provided guidance on improving deep sleep",
                timestamp: Calendar.current.date(byAdding: .hour, value: -6, to: Date()) ?? Date(),
                outcome: "User implemented bedtime routine changes"
            ),
            
            CoachingHistoryEntry(
                id: "hist_3",
                type: .behavioral,
                title: "Hydration Habit Formation",
                summary: "Started morning hydration intervention",
                timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                outcome: "65% completion rate, improving consistency"
            ),
            
            CoachingHistoryEntry(
                id: "hist_4",
                type: .corrective,
                title: "HRV Decline Alert",
                summary: "Addressed declining heart rate variability",
                timestamp: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                outcome: "User reduced training intensity, HRV stabilizing"
            ),
            
            CoachingHistoryEntry(
                id: "hist_5",
                type: .celebratory,
                title: "Exercise Streak Celebration",
                summary: "Celebrated 14-day exercise consistency",
                timestamp: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                outcome: "Reinforced positive behavior patterns"
            )
        ]
    }
    
    private func generateMockProgressAnalysis() -> ProgressAnalysis {
        return ProgressAnalysis(
            id: "analysis_1",
            analysisDate: Date(),
            timeframe: "Last 7 days",
            summary: "Strong progress in activity and hydration, with opportunities for improvement in sleep quality and stress management.",
            overallScore: 78,
            keyMetrics: [
                MetricProgress(
                    metric: "Daily Steps",
                    currentValue: "9,250 avg",
                    previousValue: "8,100 avg",
                    change: 14.2,
                    isImprovement: true,
                    changeText: "+14.2%"
                ),
                MetricProgress(
                    metric: "Sleep Quality",
                    currentValue: "72% avg",
                    previousValue: "78% avg",
                    change: -7.7,
                    isImprovement: false,
                    changeText: "-7.7%"
                ),
                MetricProgress(
                    metric: "Water Intake",
                    currentValue: "2.3L avg",
                    previousValue: "1.9L avg",
                    change: 21.1,
                    isImprovement: true,
                    changeText: "+21.1%"
                ),
                MetricProgress(
                    metric: "HRV",
                    currentValue: "42ms avg",
                    previousValue: "46ms avg",
                    change: -8.7,
                    isImprovement: false,
                    changeText: "-8.7%"
                )
            ],
            recommendations: [
                "Focus on sleep optimization to improve recovery",
                "Continue current activity levels - excellent progress",
                "Maintain hydration improvements",
                "Implement stress management techniques for HRV"
            ],
            focusAreas: ["sleep", "stress_management", "recovery"],
            nextAnalysisDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        )
    }
}

// MARK: - Supporting Data Models

struct CoachingMessage: Identifiable, Codable {
    let id: String
    let coachingType: CoachingType
    let title: String
    let content: String
    let timestamp: Date
    let priority: Int // 1-5, 5 being highest
    let actionItems: [String]
    let focusAreas: [String]
    let expectedOutcome: String
    var isRead: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, timestamp, priority
        case coachingType = "coaching_type"
        case actionItems = "action_items"
        case focusAreas = "focus_areas"
        case expectedOutcome = "expected_outcome"
        case isRead = "is_read"
    }
}

struct BehavioralIntervention: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let interventionType: InterventionType
    let targetBehavior: String
    let currentPattern: String
    let desiredPattern: String
    let strategy: String
    let implementationSteps: [String]
    let durationDays: Int
    var progress: Double // 0.0 to 1.0
    let startDate: Date
    let successMetrics: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, strategy, progress
        case interventionType = "intervention_type"
        case targetBehavior = "target_behavior"
        case currentPattern = "current_pattern"
        case desiredPattern = "desired_pattern"
        case implementationSteps = "implementation_steps"
        case durationDays = "duration_days"
        case startDate = "start_date"
        case successMetrics = "success_metrics"
    }
}

struct FocusArea: Identifiable {
    let id: String
    let title: String
    let description: String
    let priority: FocusPriority
    let icon: String
    let color: Color
    let actionItems: [String]
    let expectedImpact: String
    let timeframe: String
}

struct CoachingHistoryEntry: Identifiable {
    let id: String
    let type: CoachingType
    let title: String
    let summary: String
    let timestamp: Date
    let outcome: String
}

struct ProgressAnalysis: Identifiable, Codable {
    let id: String
    let analysisDate: Date
    let timeframe: String
    let summary: String
    let overallScore: Int
    let keyMetrics: [MetricProgress]
    let recommendations: [String]
    let focusAreas: [String]
    let nextAnalysisDate: Date
    
    enum CodingKeys: String, CodingKey {
        case id, timeframe, summary, recommendations
        case analysisDate = "analysis_date"
        case overallScore = "overall_score"
        case keyMetrics = "key_metrics"
        case focusAreas = "focus_areas"
        case nextAnalysisDate = "next_analysis_date"
    }
}

struct MetricProgress: Identifiable, Codable {
    let id = UUID()
    let metric: String
    let currentValue: String
    let previousValue: String
    let change: Double
    let isImprovement: Bool
    let changeText: String
    
    enum CodingKeys: String, CodingKey {
        case metric
        case currentValue = "current_value"
        case previousValue = "previous_value"
        case change
        case isImprovement = "is_improvement"
        case changeText = "change_text"
    }
}

enum InterventionType: String, Codable {
    case habitFormation = "habit_formation"
    case environmentalDesign = "environmental_design"
    case cognitiveRestructuring = "cognitive_restructuring"
    case socialSupport = "social_support"
    case motivationalInterviewing = "motivational_interviewing"
    
    var displayName: String {
        switch self {
        case .habitFormation: return "Habit Formation"
        case .environmentalDesign: return "Environmental Design"
        case .cognitiveRestructuring: return "Cognitive Restructuring"
        case .socialSupport: return "Social Support"
        case .motivationalInterviewing: return "Motivational Interviewing"
        }
    }
    
    var icon: String {
        switch self {
        case .habitFormation: return "repeat"
        case .environmentalDesign: return "house"
        case .cognitiveRestructuring: return "brain"
        case .socialSupport: return "person.2"
        case .motivationalInterviewing: return "bubble.left.and.bubble.right"
        }
    }
    
    var color: Color {
        switch self {
        case .habitFormation: return .blue
        case .environmentalDesign: return .green
        case .cognitiveRestructuring: return .purple
        case .socialSupport: return .orange
        case .motivationalInterviewing: return .red
        }
    }
}

enum FocusPriority: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

enum MessagePriority: Int, CaseIterable {
    case lowest = 1
    case low = 2
    case medium = 3
    case high = 4
    case highest = 5
    
    var color: Color {
        switch self {
        case .lowest: return .gray
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .highest: return .red
        }
    }
}

// MARK: - Extensions

extension Color {
    static let systemGray6 = Color(.systemGray6)
    static let systemBackground = Color(.systemBackground)
} 