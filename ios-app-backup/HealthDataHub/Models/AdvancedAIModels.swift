import Foundation

// MARK: - Goal Models

struct GoalRecommendation: Codable, Identifiable {
    let id: String
    let category: GoalCategory
    let goalType: GoalType
    let title: String
    let description: String
    let targetValue: Double
    let currentValue: Double
    let unit: String
    let difficulty: GoalDifficulty
    let timelineDays: Int
    let confidenceScore: Double
    let reasoning: String
    let expectedBenefits: [String]
    let successProbability: Double
    let requiredActions: [String]
    let relatedMetrics: [String]
    let adjustmentTriggers: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, category, title, description, unit, difficulty, reasoning
        case goalType = "goal_type"
        case targetValue = "target_value"
        case currentValue = "current_value"
        case timelineDays = "timeline_days"
        case confidenceScore = "confidence_score"
        case expectedBenefits = "expected_benefits"
        case successProbability = "success_probability"
        case requiredActions = "required_actions"
        case relatedMetrics = "related_metrics"
        case adjustmentTriggers = "adjustment_triggers"
    }
}

struct GoalAdjustment: Codable, Identifiable {
    let id = UUID()
    let goalId: String
    let adjustmentType: String
    let newTarget: Double
    let reasoning: String
    let confidence: Double
    let expectedImpact: String
    
    enum CodingKeys: String, CodingKey {
        case goalId = "goal_id"
        case adjustmentType = "adjustment_type"
        case newTarget = "new_target"
        case reasoning, confidence
        case expectedImpact = "expected_impact"
    }
}

struct GoalCoordination: Codable, Identifiable {
    let id = UUID()
    let primaryGoalId: String
    let relatedGoalIds: [String]
    let coordinationType: String
    let impactDescription: String
    let optimizationSuggestions: [String]
    
    enum CodingKeys: String, CodingKey {
        case primaryGoalId = "primary_goal_id"
        case relatedGoalIds = "related_goal_ids"
        case coordinationType = "coordination_type"
        case impactDescription = "impact_description"
        case optimizationSuggestions = "optimization_suggestions"
    }
}

enum GoalCategory: String, Codable, CaseIterable {
    case activity = "activity"
    case sleep = "sleep"
    case nutrition = "nutrition"
    case bodyComposition = "body_composition"
    case heartHealth = "heart_health"
    case wellness = "wellness"
    
    var displayName: String {
        switch self {
        case .activity: return "Activity"
        case .sleep: return "Sleep"
        case .nutrition: return "Nutrition"
        case .bodyComposition: return "Body Composition"
        case .heartHealth: return "Heart Health"
        case .wellness: return "Wellness"
        }
    }
    
    var icon: String {
        switch self {
        case .activity: return "figure.walk"
        case .sleep: return "bed.double"
        case .nutrition: return "fork.knife"
        case .bodyComposition: return "scalemass"
        case .heartHealth: return "heart"
        case .wellness: return "leaf"
        }
    }
}

enum GoalType: String, Codable {
    case increase = "increase"
    case decrease = "decrease"
    case maintain = "maintain"
    case achieve = "achieve"
}

enum GoalDifficulty: String, Codable, CaseIterable {
    case easy = "easy"
    case moderate = "moderate"
    case challenging = "challenging"
    case ambitious = "ambitious"
    
    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .moderate: return "Moderate"
        case .challenging: return "Challenging"
        case .ambitious: return "Ambitious"
        }
    }
    
    var color: String {
        switch self {
        case .easy: return "green"
        case .moderate: return "blue"
        case .challenging: return "orange"
        case .ambitious: return "red"
        }
    }
}

// MARK: - Achievement Models

struct Achievement: Codable, Identifiable {
    let id: String
    let achievementType: AchievementType
    let title: String
    let description: String
    let badgeLevel: BadgeLevel
    let celebrationLevel: CelebrationLevel
    let earnedDate: Date
    let metricType: String
    let achievementValue: Double
    let previousBest: Double?
    let improvementPercentage: Double?
    let streakDays: Int?
    let requirementsMet: [String]
    let nextMilestone: String?
    let sharingMessage: String
    let motivationMessage: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, description
        case achievementType = "achievement_type"
        case badgeLevel = "badge_level"
        case celebrationLevel = "celebration_level"
        case earnedDate = "earned_date"
        case metricType = "metric_type"
        case achievementValue = "achievement_value"
        case previousBest = "previous_best"
        case improvementPercentage = "improvement_percentage"
        case streakDays = "streak_days"
        case requirementsMet = "requirements_met"
        case nextMilestone = "next_milestone"
        case sharingMessage = "sharing_message"
        case motivationMessage = "motivation_message"
    }
}

struct Streak: Codable, Identifiable {
    let id: String
    let metricType: String
    let currentCount: Int
    let bestCount: Int
    let startDate: Date
    let lastUpdate: Date
    let targetValue: Double
    let streakType: String
    let isActive: Bool
    let milestoneReached: [Int]
    
    enum CodingKeys: String, CodingKey {
        case id
        case metricType = "metric_type"
        case currentCount = "current_count"
        case bestCount = "best_count"
        case startDate = "start_date"
        case lastUpdate = "last_update"
        case targetValue = "target_value"
        case streakType = "streak_type"
        case isActive = "is_active"
        case milestoneReached = "milestone_reached"
    }
}

struct CelebrationEvent: Codable, Identifiable {
    let id: String
    let achievementId: String
    let celebrationType: String
    let celebrationLevel: CelebrationLevel
    let triggerDate: Date
    let message: String
    let visualElements: [String]
    let soundEffects: [String]
    let sharingOptions: [String]
    let followUpActions: [String]
    
    enum CodingKeys: String, CodingKey {
        case id
        case achievementId = "achievement_id"
        case celebrationType = "celebration_type"
        case celebrationLevel = "celebration_level"
        case triggerDate = "trigger_date"
        case message
        case visualElements = "visual_elements"
        case soundEffects = "sound_effects"
        case sharingOptions = "sharing_options"
        case followUpActions = "follow_up_actions"
    }
}

enum AchievementType: String, Codable {
    case milestone = "milestone"
    case streak = "streak"
    case improvement = "improvement"
    case consistency = "consistency"
    case goalCompletion = "goal_completion"
    case personalBest = "personal_best"
    case challenge = "challenge"
    
    var displayName: String {
        switch self {
        case .milestone: return "Milestone"
        case .streak: return "Streak"
        case .improvement: return "Improvement"
        case .consistency: return "Consistency"
        case .goalCompletion: return "Goal Completion"
        case .personalBest: return "Personal Best"
        case .challenge: return "Challenge"
        }
    }
    
    var icon: String {
        switch self {
        case .milestone: return "flag.checkered"
        case .streak: return "flame"
        case .improvement: return "chart.line.uptrend.xyaxis"
        case .consistency: return "target"
        case .goalCompletion: return "checkmark.circle"
        case .personalBest: return "trophy"
        case .challenge: return "star"
        }
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
    
    var color: String {
        switch self {
        case .bronze: return "brown"
        case .silver: return "gray"
        case .gold: return "yellow"
        case .platinum: return "purple"
        case .diamond: return "cyan"
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
    let message: String
    let timing: InterventionTiming
    let priority: Int
    let targetMetrics: [String]
    let actionableSteps: [String]
    let expectedOutcome: String
    let followUpDays: Int
    let personalizationFactors: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, title, message, timing, priority
        case coachingType = "coaching_type"
        case targetMetrics = "target_metrics"
        case actionableSteps = "actionable_steps"
        case expectedOutcome = "expected_outcome"
        case followUpDays = "follow_up_days"
        case personalizationFactors = "personalization_factors"
    }
}

struct BehavioralIntervention: Codable, Identifiable {
    let id: String
    let interventionType: String
    let targetBehavior: String
    let currentPattern: String
    let desiredPattern: String
    let interventionStrategy: String
    let implementationSteps: [String]
    let successMetrics: [String]
    let timelineDays: Int
    let difficultyLevel: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case interventionType = "intervention_type"
        case targetBehavior = "target_behavior"
        case currentPattern = "current_pattern"
        case desiredPattern = "desired_pattern"
        case interventionStrategy = "intervention_strategy"
        case implementationSteps = "implementation_steps"
        case successMetrics = "success_metrics"
        case timelineDays = "timeline_days"
        case difficultyLevel = "difficulty_level"
    }
}

enum CoachingType: String, Codable {
    case motivational = "motivational"
    case educational = "educational"
    case behavioral = "behavioral"
    case corrective = "corrective"
    case celebratory = "celebratory"
    case preventive = "preventive"
    
    var displayName: String {
        switch self {
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
        case .motivational: return "heart.fill"
        case .educational: return "book.fill"
        case .behavioral: return "arrow.triangle.2.circlepath"
        case .corrective: return "wrench.fill"
        case .celebratory: return "party.popper.fill"
        case .preventive: return "shield.fill"
        }
    }
    
    var color: String {
        switch self {
        case .motivational: return "red"
        case .educational: return "blue"
        case .behavioral: return "orange"
        case .corrective: return "yellow"
        case .celebratory: return "purple"
        case .preventive: return "green"
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