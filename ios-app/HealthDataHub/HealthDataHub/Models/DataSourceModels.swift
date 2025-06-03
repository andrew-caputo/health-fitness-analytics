import Foundation
import SwiftUI

// MARK: - Health Categories
enum HealthCategory: String, CaseIterable, Codable {
    case activity = "activity"
    case bodyComposition = "body_composition"
    case nutrition = "nutrition"
    case sleep = "sleep"
    case heartHealth = "heart_health"
    case workouts = "workouts"
    
    var displayName: String {
        switch self {
        case .activity: return "Activity"
        case .bodyComposition: return "Body Composition"
        case .nutrition: return "Nutrition"
        case .sleep: return "Sleep"
        case .heartHealth: return "Heart Health"
        case .workouts: return "Workouts"
        }
    }
    
    var icon: String {
        switch self {
        case .activity: return "figure.walk"
        case .bodyComposition: return "scalemass"
        case .nutrition: return "fork.knife"
        case .sleep: return "bed.double"
        case .heartHealth: return "heart"
        case .workouts: return "dumbbell"
        }
    }
    
    var description: String {
        switch self {
        case .activity: return "Steps, distance, calories burned"
        case .bodyComposition: return "Weight, BMI, body fat percentage"
        case .nutrition: return "Calories, macros, water intake"
        case .sleep: return "Sleep duration, sleep stages, sleep quality"
        case .heartHealth: return "Heart rate, heart rate variability"
        case .workouts: return "Exercise sessions and fitness activities"
        }
    }
}

// MARK: - Data Source Models
struct PreferenceDataSource: Codable, Identifiable, Hashable {
    let id = UUID()
    let source_name: String
    let display_name: String
    let supports_activity: Bool
    let supports_sleep: Bool
    let supports_nutrition: Bool
    let supports_body_composition: Bool
    let supports_heart_health: Bool
    let integration_type: String
    let is_active: Bool
    
    enum CodingKeys: String, CodingKey {
        case source_name, display_name, supports_activity, supports_sleep
        case supports_nutrition, supports_body_composition, supports_heart_health, integration_type, is_active
    }
    
    func supports(category: HealthCategory) -> Bool {
        switch category {
        case .activity: return supports_activity
        case .bodyComposition: return supports_body_composition
        case .nutrition: return supports_nutrition
        case .sleep: return supports_sleep
        case .heartHealth: return supports_heart_health
        case .workouts: return supports_activity // Workouts are part of activity data
        }
    }
    
    var integrationTypeDisplayName: String {
        // Special case for Apple Health - it uses HealthKit, not file upload
        if source_name.lowercased() == "apple_health" {
            return "Connect Account"
        }
        
        switch integration_type.lowercased() {
        case "oauth2": return "Connect Account"
        case "file_upload": return "Upload File"
        case "api": return "API Integration"
        default: return "Connect"
        }
    }
    
    var iconName: String {
        switch source_name.lowercased() {
        case "apple_health": return "applelogo"
        case "withings": return "logo_withings"
        case "oura": return "logo_oura"
        case "myfitnesspal": return "logo_myfitnesspal"
        case "fitbit": return "logo_fitbit"
        case "strava": return "logo_strava"
        case "whoop": return "logo_whoop"
        case "cronometer": return "logo_cronometer"
        case "csv_upload": return "doc.text.fill"
        default: return "questionmark.circle.fill"
        }
    }
    
    var isSFSymbol: Bool {
        switch source_name.lowercased() {
        case "apple_health", "csv_upload":
            return true
        case "withings", "oura", "myfitnesspal", "fitbit", "strava", "whoop", "cronometer":
            return false
        default:
            return true
        }
    }
    
    var brandColor: Color {
        switch source_name.lowercased() {
        case "apple_health": return .primary
        case "withings": return .blue
        case "oura": return .purple
        case "myfitnesspal": return .blue
        case "fitbit": return .teal
        case "strava": return .orange
        case "whoop": return .red
        case "cronometer": return .green
        case "csv": return .gray
        default: return .blue
        }
    }
}

// MARK: - Available Source Info
struct AvailableSource: Codable, Identifiable, Hashable {
    let id = UUID()
    let source_name: String
    let display_name: String
    let integration_type: String
    let is_connected: Bool
    
    enum CodingKeys: String, CodingKey {
        case source_name, display_name, integration_type, is_connected
    }
}

// MARK: - Category Source Info
struct CategorySourceInfo: Codable {
    let category: String
    let preferred_source: String?
    let connected_sources: [String]
    let available_sources: [AvailableSource]
    
    var categoryEnum: HealthCategory? {
        return HealthCategory(rawValue: category)
    }
}

// MARK: - User Preferences
struct UserDataSourcePreferences: Codable {
    let activity_source: String?
    let sleep_source: String?
    let nutrition_source: String?
    let body_composition_source: String?
    let heart_health_source: String?
    
    func preferredSource(for category: HealthCategory) -> String? {
        switch category {
        case .activity, .workouts: return activity_source
        case .bodyComposition: return body_composition_source
        case .nutrition: return nutrition_source
        case .sleep: return sleep_source
        case .heartHealth: return heart_health_source
        }
    }
    
    mutating func setPreferredSource(_ sourceName: String?, for category: HealthCategory) {
        // Note: This creates a new instance since struct is immutable
        // The actual updating will be handled by the ViewModel
    }
}

// MARK: - API Response Models
struct UserPreferencesResponse: Codable {
    let preferences: UserDataSourcePreferences?
    let available_sources: [PreferenceDataSource]
    let connected_sources: [String]
}

struct SetPreferredSourceRequest: Codable {
    let source_name: String
}

struct EmptyResponse: Codable {}

// MARK: - View Models Helper
extension UserDataSourcePreferences {
    static var empty: UserDataSourcePreferences {
        return UserDataSourcePreferences(
            activity_source: nil,
            sleep_source: nil,
            nutrition_source: nil,
            body_composition_source: nil,
            heart_health_source: nil
        )
    }
    
    func updated(category: HealthCategory, sourceName: String?) -> UserDataSourcePreferences {
        switch category {
        case .activity, .workouts:
            return UserDataSourcePreferences(
                activity_source: sourceName,
                sleep_source: sleep_source,
                nutrition_source: nutrition_source,
                body_composition_source: body_composition_source,
                heart_health_source: heart_health_source
            )
        case .sleep:
            return UserDataSourcePreferences(
                activity_source: activity_source,
                sleep_source: sourceName,
                nutrition_source: nutrition_source,
                body_composition_source: body_composition_source,
                heart_health_source: heart_health_source
            )
        case .nutrition:
            return UserDataSourcePreferences(
                activity_source: activity_source,
                sleep_source: sleep_source,
                nutrition_source: sourceName,
                body_composition_source: body_composition_source,
                heart_health_source: heart_health_source
            )
        case .bodyComposition:
            return UserDataSourcePreferences(
                activity_source: activity_source,
                sleep_source: sleep_source,
                nutrition_source: nutrition_source,
                body_composition_source: sourceName,
                heart_health_source: heart_health_source
            )
        case .heartHealth:
            return UserDataSourcePreferences(
                activity_source: activity_source,
                sleep_source: sleep_source,
                nutrition_source: nutrition_source,
                body_composition_source: body_composition_source,
                heart_health_source: sourceName
            )
        }
    }
}

// MARK: - Data Source Selection State
class DataSourceSelectionState: ObservableObject {
    @Published var availableSources: [PreferenceDataSource] = []
    @Published var currentPreferences: UserDataSourcePreferences = .empty
    @Published var isLoading = false
    @Published var error: String?
    
    func getAvailableSources(for category: HealthCategory) -> [PreferenceDataSource] {
        return availableSources.filter { $0.supports(category: category) }
    }
    
    func getCurrentSource(for category: HealthCategory) -> PreferenceDataSource? {
        guard let sourceName = currentPreferences.preferredSource(for: category) else { return nil }
        return availableSources.first { $0.source_name == sourceName }
    }
    
    func hasSelection(for category: HealthCategory) -> Bool {
        return currentPreferences.preferredSource(for: category) != nil
    }
    
    var hasValidSelections: Bool {
        // At minimum, require activity and sleep sources
        return currentPreferences.activity_source != nil && currentPreferences.sleep_source != nil
    }
} 