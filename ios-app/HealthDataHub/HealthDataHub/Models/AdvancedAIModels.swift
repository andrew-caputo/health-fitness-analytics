import Foundation
import SwiftUI

// MARK: - Goal Recommendation Models

struct GoalRecommendation: Codable, Identifiable {
    let id: String
    let type: String
    let title: String
    let description: String
    let category: String
    let targetValue: Double
    let currentValue: Double
    let timeline: Int
    let difficulty: String
    let confidence: Double
    let reasoning: [String]
    let benefits: [String]
    let successFactors: [String]
    let resources: [GoalResource]
    
    // Additional computed properties for Views
    var unit: String {
        switch category.lowercased() {
        case "activity", "steps": return "steps"
        case "sleep": return "hours"
        case "nutrition": return "calories"
        case "weight": return "lbs"
        default: return "units"
        }
    }
    
    var timelineDescription: String {
        if timeline == 1 {
            return "1 day"
        } else if timeline < 7 {
            return "\(timeline) days"
        } else if timeline < 30 {
            let weeks = timeline / 7
            return "\(weeks) week\(weeks == 1 ? "" : "s")"
        } else {
            let months = timeline / 30
            return "\(months) month\(months == 1 ? "" : "s")"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, title, description, category, timeline, difficulty, confidence, reasoning, benefits, resources
        case targetValue = "target_value"
        case currentValue = "current_value"
        case successFactors = "success_factors"
    }
}

struct GoalResource: Codable, Identifiable {
    let id: String
    let type: String
    let title: String
    let description: String
    let url: String?
    let category: String
    
    enum CodingKeys: String, CodingKey {
        case id, type, title, description, url, category
    }
}

struct GoalAdjustment: Codable, Identifiable {
    let id: String
    let goalId: String
    let recommendationType: String
    let currentProgress: Double
    let suggestedTarget: Double
    let reasoning: String
    let adjustmentPercentage: Double
    let newTimeline: Int?
    let confidence: Double
    
    enum CodingKeys: String, CodingKey {
        case id, reasoning, confidence
        case goalId = "goal_id"
        case recommendationType = "recommendation_type"
        case currentProgress = "current_progress"
        case suggestedTarget = "suggested_target"
        case adjustmentPercentage = "adjustment_percentage"
        case newTimeline = "new_timeline"
    }
}

// MARK: - Achievement Models

struct Achievement: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let type: String
    let category: String
    let threshold: Double
    let currentValue: Double
    let isCompleted: Bool
    let completedAt: Date?
    let badgeLevel: BadgeLevel
    let points: Int
    let rarity: String
    
    // Computed properties for views
    var achievementType: AchievementType {
        return AchievementType(rawValue: type) ?? .milestone
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, type, category, threshold, points, rarity
        case currentValue = "current_value"
        case isCompleted = "is_completed"
        case completedAt = "completed_at"
        case badgeLevel = "badge_level"
    }
}

struct Streak: Codable, Identifiable {
    let id: String
    let type: String
    let title: String
    let description: String
    let currentCount: Int
    let longestCount: Int
    let startDate: Date
    let lastUpdate: Date
    let isActive: Bool
    let milestones: [StreakMilestone]
    
    // Computed properties for views
    var metricType: String {
        return type.replacingOccurrences(of: "_", with: " ")
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, title, description, milestones
        case currentCount = "current_count"
        case longestCount = "longest_count"
        case startDate = "start_date"
        case lastUpdate = "last_update"
        case isActive = "is_active"
    }
}

struct StreakMilestone: Codable, Identifiable {
    let id: String
    let count: Int
    let title: String
    let reward: String
    let isCompleted: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, count, title, reward
        case isCompleted = "is_completed"
    }
}

enum BadgeLevel: String, Codable, CaseIterable {
    case bronze = "bronze"
    case silver = "silver"
    case gold = "gold"
    case platinum = "platinum"
    case diamond = "diamond"
    
    var displayName: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .diamond: return "Diamond"
        }
    }
    
    var colorName: String {
        switch self {
        case .bronze: return "brown"
        case .silver: return "gray"
        case .gold: return "yellow"
        case .platinum: return "purple"
        case .diamond: return "cyan"
        }
    }
    
    var color: Color {
        switch self {
        case .bronze: return .brown
        case .silver: return .gray
        case .gold: return .yellow
        case .platinum: return .purple
        case .diamond: return .cyan
        }
    }
}

enum CelebrationLevel: String, Codable {
    case minor = "minor"
    case moderate = "moderate"
    case major = "major"
    case epic = "epic"
}

// MARK: - Coaching Models

struct CoachingMessage: Codable, Identifiable {
    let id: String
    let coachingType: CoachingType
    let title: String
    let message: String // API field name
    let content: String? // View field name - optional for backward compatibility
    let timing: InterventionTiming?
    let timestamp: Date?
    let priority: Int
    let targetMetrics: [String]
    let actionableSteps: [String]
    let actionItems: [String]? // Alternative field name
    let expectedOutcome: String
    let followUpDays: Int?
    let personalizationFactors: [String]
    let focusAreas: [String]
    var isRead: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, title, message, content, timing, timestamp, priority
        case coachingType = "coaching_type"
        case targetMetrics = "target_metrics"
        case actionableSteps = "actionable_steps"
        case actionItems = "action_items"
        case expectedOutcome = "expected_outcome"
        case followUpDays = "follow_up_days"
        case personalizationFactors = "personalization_factors"
        case focusAreas = "focus_areas"
        case isRead = "is_read"
    }
    
    // Computed properties for compatibility
    var displayContent: String {
        return content ?? message
    }
    
    var displayActionItems: [String] {
        return actionItems ?? actionableSteps
    }
}

struct BehavioralIntervention: Codable, Identifiable {
    let id: String
    let title: String?
    let description: String?
    let interventionType: InterventionType
    let targetBehavior: String
    let currentPattern: String
    let desiredPattern: String
    let interventionStrategy: String
    let strategy: String? // Alternative field name
    let implementationSteps: [String]
    let successMetrics: [String]
    let timelineDays: Int
    let durationDays: Int? // Alternative field name
    let difficultyLevel: String?
    var progress: Double?
    let startDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, strategy, progress
        case interventionType = "intervention_type"
        case targetBehavior = "target_behavior"
        case currentPattern = "current_pattern"
        case desiredPattern = "desired_pattern"
        case interventionStrategy = "intervention_strategy"
        case implementationSteps = "implementation_steps"
        case successMetrics = "success_metrics"
        case timelineDays = "timeline_days"
        case durationDays = "duration_days"
        case difficultyLevel = "difficulty_level"
        case startDate = "start_date"
    }
    
    // Computed properties for compatibility
    var displayStrategy: String {
        return strategy ?? interventionStrategy
    }
    
    var displayDuration: Int {
        return durationDays ?? timelineDays
    }
}

// MARK: - Additional Supporting Models

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

// MARK: - Enums

enum CoachingType: String, Codable, CaseIterable {
    case all = "all"
    case motivational = "motivational"
    case educational = "educational"
    case behavioral = "behavioral"
    case corrective = "corrective"
    case celebratory = "celebratory"
    case preventive = "preventive"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .motivational: return "Motivational"
        case .educational: return "Educational"
        case .behavioral: return "Behavioral"
        case .corrective: return "Corrective"
        case .celebratory: return "Celebratory"
        case .preventive: return "Preventive"
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
        case .preventive: return "shield.fill"
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
        case .preventive: return .green
        }
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

enum InterventionTiming: String, Codable {
    case immediate = "immediate"
    case daily = "daily"
    case weekly = "weekly"
    case milestone = "milestone"
    case struggle = "struggle"
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

// MARK: - Progress Models

struct GoalProgress: Codable, Identifiable {
    let id = UUID()
    let goalId: String
    let currentValue: Double
    let targetValue: Double
    let progressPercentage: Double
    let daysElapsed: Int
    let totalTimeline: Int
    let onTrack: Bool
    let projectedCompletion: Date?
    let recentTrend: String
    let motivationLevel: String
    
    // Additional properties for Views
    var title: String {
        return "Goal \(goalId.prefix(8))"
    }
    
    var category: GoalCategory {
        return .activity // Default category
    }
    
    var status: GoalStatus {
        if progressPercentage >= 1.0 { return .completed }
        if progressPercentage >= 0.8 { return .onTrack }
        if progressPercentage >= 0.6 { return .ahead }
        return .behind
    }
    
    var unit: String {
        return "steps" // Default unit
    }
    
    var totalDays: Int {
        return totalTimeline
    }
    
    var progressHistory: [ProgressDataPoint] {
        // Generate mock history data
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -daysElapsed, to: Date()) ?? Date()
        
        return (0..<daysElapsed).map { day in
            let date = calendar.date(byAdding: .day, value: day, to: startDate) ?? Date()
            let baseProgress = Double(day) / Double(totalTimeline)
            let variation = Double.random(in: 0.8...1.2)
            let value = min(1.0, baseProgress * variation)
            
            return ProgressDataPoint(
                id: "point_\(day)",
                day: day + 1,
                date: date,
                value: value
            )
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case goalId = "goal_id"
        case currentValue = "current_value"
        case targetValue = "target_value"
        case progressPercentage = "progress_percentage"
        case daysElapsed = "days_elapsed"
        case totalTimeline = "total_timeline"
        case onTrack = "on_track"
        case projectedCompletion = "projected_completion"
        case recentTrend = "recent_trend"
        case motivationLevel = "motivation_level"
    }
}

// MARK: - API Response Models

struct GoalRecommendationsResponse: Codable {
    let recommendations: [GoalRecommendation]
    let totalCount: Int
    let userPreferences: [String: String]
    
    enum CodingKeys: String, CodingKey {
        case recommendations
        case totalCount = "total_count"
        case userPreferences = "user_preferences"
    }
}

struct AchievementsResponse: Codable {
    let achievements: [Achievement]
    let totalCount: Int
    let recentCount: Int
    let categories: [String: Int]
    
    enum CodingKeys: String, CodingKey {
        case achievements
        case totalCount = "total_count"
        case recentCount = "recent_count"
        case categories
    }
}

struct StreaksResponse: Codable {
    let streaks: [Streak]
    let activeCount: Int
    let longestStreak: Streak?
    let totalMilestones: Int
    
    enum CodingKeys: String, CodingKey {
        case streaks
        case activeCount = "active_count"
        case longestStreak = "longest_streak"
        case totalMilestones = "total_milestones"
    }
}

struct CoachingMessagesResponse: Codable {
    let messages: [CoachingMessage]
    let priorityCount: [String: Int]
    let nextUpdate: Date?
    
    enum CodingKeys: String, CodingKey {
        case messages
        case priorityCount = "priority_count"
        case nextUpdate = "next_update"
    }
}

struct GoalProgressResponse: Codable {
    let progress: GoalProgress
    let predictions: [String]
    let recommendations: [String]
    
    enum CodingKeys: String, CodingKey {
        case progress, predictions, recommendations
    }
}

// MARK: - Additional Models for Views

struct HealthInsight: Codable, Identifiable {
    let id: String
    let insightType: String
    let priority: String
    let title: String
    let description: String
    let dataSources: [String]
    let metricsInvolved: [String]
    let confidenceScore: Double
    let actionableRecommendations: [String]
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, priority
        case insightType = "insight_type"
        case dataSources = "data_sources"
        case metricsInvolved = "metrics_involved"
        case confidenceScore = "confidence_score"
        case actionableRecommendations = "actionable_recommendations"
        case createdAt = "created_at"
    }
}

struct ProgressDataPoint: Identifiable, Codable {
    let id: String
    let day: Int
    let date: Date
    let value: Double
}

struct ProgressPredictions: Identifiable, Codable {
    let id: String
    let generatedDate: Date
    let timeframe: String
    let summary: String
    let confidence: Double
    let goalPredictions: [GoalPrediction]
    let recommendations: [String]
    let riskFactors: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, timeframe, summary, confidence, recommendations
        case generatedDate = "generated_date"
        case goalPredictions = "goal_predictions"
        case riskFactors = "risk_factors"
    }
}

struct GoalPrediction: Identifiable, Codable {
    let id: String
    let goalId: String
    let goalTitle: String
    let outcome: String
    let confidence: Double
    let timeframe: String
    let isPositive: Bool
    let reasoning: String
    
    enum CodingKeys: String, CodingKey {
        case id, outcome, confidence, timeframe, reasoning
        case goalId = "goal_id"
        case goalTitle = "goal_title"
        case isPositive = "is_positive"
    }
}

struct UpcomingAchievement: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let badgeLevel: BadgeLevel
    let icon: String
    let progress: Double
    let estimatedDate: Date
    let category: GoalCategory
    let requirements: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, icon, progress, category, requirements
        case badgeLevel = "badge_level"
        case estimatedDate = "estimated_date"
    }
}

struct GoalAdjustmentRecommendation: Identifiable, Codable {
    let id: String
    let goalId: String
    let title: String
    let description: String
    let adjustmentType: GoalAdjustmentType
    let currentTarget: Double
    let recommendedTarget: Double
    let currentTimeline: Date?
    let recommendedTimeline: Date?
    let reasoning: String
    let expectedImpact: String
    let confidence: Double
    let priority: RecommendationPriority
    let dataSources: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, reasoning, confidence, priority
        case goalId = "goal_id"
        case adjustmentType = "adjustment_type"
        case currentTarget = "current_target"
        case recommendedTarget = "recommended_target"
        case currentTimeline = "current_timeline"
        case recommendedTimeline = "recommended_timeline"
        case expectedImpact = "expected_impact"
        case dataSources = "data_sources"
    }
}

struct ConnectedDataSource: Identifiable, Codable {
    let id: String
    let name: String
    let icon: String
    let isActive: Bool
    let lastSync: Date
    let dataTypes: [String]
    let syncFrequency: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, icon, syncFrequency
        case isActive = "is_active"
        case lastSync = "last_sync"
        case dataTypes = "data_types"
    }
}

// MARK: - Additional Enums

enum GoalCategory: String, Codable, CaseIterable {
    case all = "all"
    case activity = "activity"
    case nutrition = "nutrition"
    case sleep = "sleep"
    case mindfulness = "mindfulness"
    case weight = "weight"
    case health = "health"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .activity: return "Activity"
        case .nutrition: return "Nutrition"
        case .sleep: return "Sleep"
        case .mindfulness: return "Mindfulness"
        case .weight: return "Weight"
        case .health: return "Health"
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "target"
        case .activity: return "figure.run"
        case .nutrition: return "leaf.fill"
        case .sleep: return "bed.double.fill"
        case .mindfulness: return "brain.head.profile"
        case .weight: return "scalemass.fill"
        case .health: return "heart.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .blue
        case .activity: return .green
        case .nutrition: return .orange
        case .sleep: return .purple
        case .mindfulness: return .indigo
        case .weight: return .pink
        case .health: return .red
        }
    }
}

enum GoalAdjustmentType: String, Codable {
    case increaseTarget = "increase_target"
    case decreaseTarget = "decrease_target"
    case extendTimeline = "extend_timeline"
    case shortenTimeline = "shorten_timeline"
    case maintainCurrent = "maintain_current"
    
    var displayName: String {
        switch self {
        case .increaseTarget: return "Increase Target"
        case .decreaseTarget: return "Decrease Target"
        case .extendTimeline: return "Extend Timeline"
        case .shortenTimeline: return "Shorten Timeline"
        case .maintainCurrent: return "Maintain Current"
        }
    }
}

enum RecommendationPriority: String, Codable {
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

// MARK: - Missing Model Types

enum GoalDifficulty: String, Codable, CaseIterable {
    case easy = "easy"
    case moderate = "moderate"
    case challenging = "challenging"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .moderate: return "Moderate"
        case .challenging: return "Challenging"
        case .expert: return "Expert"
        }
    }
    
    var color: Color {
        switch self {
        case .easy: return .green
        case .moderate: return .blue
        case .challenging: return .orange
        case .expert: return .red
        }
    }
}

enum AchievementType: String, Codable, CaseIterable {
    case streak = "streak"
    case milestone = "milestone"
    case improvement = "improvement"
    case consistency = "consistency"
    case goal = "goal"
    
    var displayName: String {
        switch self {
        case .streak: return "Streak"
        case .milestone: return "Milestone"
        case .improvement: return "Improvement"
        case .consistency: return "Consistency"
        case .goal: return "Goal"
        }
    }
    
    var icon: String {
        switch self {
        case .streak: return "flame"
        case .milestone: return "flag"
        case .improvement: return "chart.line.uptrend.xyaxis"
        case .consistency: return "checkmark.circle"
        case .goal: return "target"
        }
    }
}

struct GoalCoordination: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let relatedGoals: [String]
    let coordinationType: String
    let priority: String
    let synergies: [String]
    let conflicts: [String]
    let recommendations: [String]
    let impactScore: Double
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, priority, synergies, conflicts, recommendations
        case relatedGoals = "related_goals"
        case coordinationType = "coordination_type"
        case impactScore = "impact_score"
    }
}

enum ConflictResolution: String, Codable, CaseIterable {
    case useFirst = "use_first"
    case useSecond = "use_second"
    case merge = "merge"
    case ignore = "ignore"
    case manual = "manual"
    
    var displayName: String {
        switch self {
        case .useFirst: return "Use First Source"
        case .useSecond: return "Use Second Source"
        case .merge: return "Merge Data"
        case .ignore: return "Ignore Conflict"
        case .manual: return "Manual Resolution"
        }
    }
}

enum BulkResolutionStrategy: String, Codable, CaseIterable {
    case priorityBased = "priority_based"
    case newestFirst = "newest_first"
    case mostAccurate = "most_accurate"
    case userPreferred = "user_preferred"
    
    var displayName: String {
        switch self {
        case .priorityBased: return "Priority Based"
        case .newestFirst: return "Newest First"
        case .mostAccurate: return "Most Accurate"
        case .userPreferred: return "User Preferred"
        }
    }
}

enum ProgressTimeframe: String, Codable, CaseIterable {
    case sevenDays = "7_days"
    case thirtyDays = "30_days"
    case sixtyDays = "60_days"
    case ninetyDays = "90_days"
    case sixMonths = "6_months"
    case oneYear = "1_year"
    
    var displayName: String {
        switch self {
        case .sevenDays: return "7 Days"
        case .thirtyDays: return "30 Days"
        case .sixtyDays: return "60 Days"
        case .ninetyDays: return "90 Days"
        case .sixMonths: return "6 Months"
        case .oneYear: return "1 Year"
        }
    }
    
    var shortDisplayName: String {
        switch self {
        case .sevenDays: return "7D"
        case .thirtyDays: return "30D"
        case .sixtyDays: return "60D"
        case .ninetyDays: return "90D"
        case .sixMonths: return "6M"
        case .oneYear: return "1Y"
        }
    }
} 