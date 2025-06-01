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
        // Mock coaching messages
        coachingMessages = [
            CoachingMessage(
                id: "msg1",
                coachingType: .motivational,
                title: "Great Progress on Sleep!",
                message: "You've been consistently getting 7+ hours of sleep this week. This is excellent for your recovery and overall health.",
                content: "You've been consistently getting 7+ hours of sleep this week. This is excellent for your recovery and overall health.",
                timing: .daily,
                timestamp: Date(),
                priority: 4,
                targetMetrics: ["sleep_duration", "sleep_quality"],
                actionableSteps: ["Continue your current bedtime routine", "Track how you feel with this sleep schedule"],
                actionItems: ["Continue your current bedtime routine", "Track how you feel with this sleep schedule"],
                expectedOutcome: "Improved energy and recovery",
                followUpDays: 7,
                personalizationFactors: ["good_sleep_habits", "consistent_schedule"],
                focusAreas: ["sleep", "recovery"],
                isRead: false
            ),
            CoachingMessage(
                id: "msg2",
                coachingType: .educational,
                title: "Understanding Heart Rate Zones",
                message: "Your recent workouts show you're spending most time in Zone 2. Here's why this is beneficial for building your aerobic base.",
                content: "Your recent workouts show you're spending most time in Zone 2. Here's why this is beneficial for building your aerobic base.",
                timing: .weekly,
                timestamp: Calendar.current.date(byAdding: .hour, value: -2, to: Date()),
                priority: 3,
                targetMetrics: ["heart_rate", "exercise_intensity"],
                actionableSteps: ["Continue Zone 2 training", "Add one Zone 4 session per week"],
                actionItems: ["Continue Zone 2 training", "Add one Zone 4 session per week"],
                expectedOutcome: "Improved cardiovascular fitness",
                followUpDays: 14,
                personalizationFactors: ["endurance_focus", "heart_rate_data"],
                focusAreas: ["cardio", "training"],
                isRead: false
            ),
            CoachingMessage(
                id: "msg3",
                coachingType: .corrective,
                title: "Nutrition Opportunity",
                message: "Your protein intake has been below target this week. Let's work on incorporating more protein-rich foods into your meals.",
                content: "Your protein intake has been below target this week. Let's work on incorporating more protein-rich foods into your meals.",
                timing: .immediate,
                timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
                priority: 5,
                targetMetrics: ["protein_intake", "macronutrients"],
                actionableSteps: ["Add protein to each meal", "Consider a protein shake post-workout"],
                actionItems: ["Add protein to each meal", "Consider a protein shake post-workout"],
                expectedOutcome: "Better muscle recovery and satiety",
                followUpDays: 3,
                personalizationFactors: ["low_protein", "muscle_building_goal"],
                focusAreas: ["nutrition", "recovery"],
                isRead: false
            )
        ]
    
        // Mock behavioral interventions
        behavioralInterventions = [
            BehavioralIntervention(
                id: "int1",
                title: "Evening Wind-Down Routine",
                description: "Establish a consistent pre-sleep routine to improve sleep quality",
                interventionType: .habitFormation,
                targetBehavior: "Consistent bedtime routine",
                currentPattern: "Inconsistent sleep schedule, screen time before bed",
                desiredPattern: "Regular 30-minute wind-down routine starting at 9:30 PM",
                interventionStrategy: "Use environmental cues and habit stacking to create a consistent routine",
                strategy: "Use environmental cues and habit stacking to create a consistent routine",
                implementationSteps: [
                    "Set a daily alarm for 9:30 PM",
                    "Put devices in another room",
                    "Read for 15 minutes",
                    "Practice 10 minutes of meditation",
                    "Write in gratitude journal"
                ],
                successMetrics: ["Days following routine", "Sleep quality score", "Time to fall asleep"],
                timelineDays: 21,
                durationDays: 21,
                difficultyLevel: "moderate",
                progress: 0.65,
                startDate: Calendar.current.date(byAdding: .day, value: -14, to: Date())
            ),
            BehavioralIntervention(
                id: "int2",
                title: "Hydration Habit",
                description: "Increase daily water intake through strategic reminders",
                interventionType: .environmentalDesign,
                targetBehavior: "Drinking 8 glasses of water daily",
                currentPattern: "Forgetting to drink water, only 4-5 glasses per day",
                desiredPattern: "Consistent water intake throughout the day",
                interventionStrategy: "Place water bottles in strategic locations and use time-based reminders",
                strategy: "Place water bottles in strategic locations and use time-based reminders",
                implementationSteps: [
                    "Place water bottle by bedside",
                    "Set hourly reminders",
                    "Drink water before each meal",
                    "Use a marked water bottle to track intake"
                ],
                successMetrics: ["Daily water intake", "Reminder completion rate"],
                timelineDays: 14,
                durationDays: 14,
                difficultyLevel: "easy",
                progress: 0.85,
                startDate: Calendar.current.date(byAdding: .day, value: -10, to: Date())
            )
        ]
        
        // Mock focus areas
        focusAreas = [
            FocusArea(
                id: "focus1",
                title: "Sleep Optimization",
                description: "Improving sleep quality and consistency",
            priority: .high,
            icon: "bed.double.fill",
                color: .purple,
                actionItems: ["Maintain bedtime routine", "Track sleep patterns"],
                expectedImpact: "Better energy and recovery",
                timeframe: "2-3 weeks"
            ),
            FocusArea(
                id: "focus2",
                title: "Nutrition Balance",
                description: "Optimizing macronutrient intake",
                priority: .medium,
                icon: "fork.knife",
                color: .green,
                actionItems: ["Increase protein intake", "Plan balanced meals"],
                expectedImpact: "Improved body composition",
                timeframe: "1-2 months"
            )
        ]
        
        // Mock coaching history
        coachingHistory = [
            CoachingHistoryEntry(
                id: "hist1",
                type: .celebratory,
                title: "7-Day Sleep Streak!",
                summary: "Congratulations on achieving 7 consecutive days of 7+ hours sleep",
                timestamp: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
                outcome: "Sleep consistency improved by 40%"
            ),
            CoachingHistoryEntry(
                id: "hist2",
                type: .educational,
                title: "Heart Rate Training Zones",
                summary: "Learned about optimal training zones for aerobic development",
                timestamp: Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date(),
                outcome: "Applied Zone 2 training in 3 workouts"
            )
        ]
        
        // Mock progress analysis
        progressAnalysis = ProgressAnalysis(
            id: "analysis1",
            analysisDate: Date(),
            timeframe: "Past 2 weeks",
            summary: "Overall progress has been excellent with significant improvements in sleep and activity levels. Focus on nutrition will help optimize results.",
            overallScore: 85,
            keyMetrics: [
                MetricProgress(
                    metric: "Sleep Quality",
                    currentValue: "8.2/10",
                    previousValue: "7.1/10",
                    change: 15.5,
                    isImprovement: true,
                    changeText: "+15.5%"
                ),
                MetricProgress(
                    metric: "Daily Steps",
                    currentValue: "9,450",
                    previousValue: "8,200",
                    change: 15.2,
                    isImprovement: true,
                    changeText: "+1,250"
                ),
                MetricProgress(
                    metric: "Protein Intake",
                    currentValue: "95g",
                    previousValue: "120g",
                    change: -20.8,
                    isImprovement: false,
                    changeText: "-25g"
                ),
                MetricProgress(
                    metric: "Exercise Frequency",
                    currentValue: "5 days/week",
                    previousValue: "3 days/week",
                    change: 66.7,
                    isImprovement: true,
                    changeText: "+2 days"
                )
            ],
            recommendations: [
                "Continue your excellent sleep routine",
                "Increase protein intake by 20-25g daily",
                "Consider adding one strength training session",
                "Maintain current activity levels"
            ],
            focusAreas: ["sleep", "stress_management", "recovery"],
            nextAnalysisDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        )
    }
} 