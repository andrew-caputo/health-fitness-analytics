import Foundation
import SwiftUI

@MainActor
class DataSourceSelectionViewModel: ObservableObject {
    @Published var availableSources: [PreferenceDataSource] = []
    @Published var currentPreferences: UserDataSourcePreferences = .empty
    @Published var preferences: [HealthCategory: String?] = [:]
    @Published var isLoading = false
    @Published var error: String?
    @Published var showError = false
    
    private let networkManager = NetworkManager.shared
    
    var hasValidSelections: Bool {
        // Require at least activity and sleep sources
        return preferences[.activity] != nil && preferences[.sleep] != nil
    }
    
    var completionPercentage: Double {
        let totalCategories = HealthCategory.allCases.count
        let selectedCategories = preferences.values.compactMap { $0 }.count
        return Double(selectedCategories) / Double(totalCategories)
    }
    
    var hasRecommendedSelections: Bool {
        // Recommend at least activity, sleep, and one of nutrition/body composition
        let hasActivity = preferences[.activity] != nil
        let hasSleep = preferences[.sleep] != nil
        let hasBodyOrNutrition = preferences[.nutrition] != nil || preferences[.bodyComposition] != nil
        return hasActivity && hasSleep && hasBodyOrNutrition
    }
    
    var validationMessage: String? {
        if preferences[.activity] == nil {
            return "Please select an Activity data source to continue"
        }
        if preferences[.sleep] == nil {
            return "Please select a Sleep data source to continue"
        }
        return nil
    }
    
    var linkedCategoriesMessage: String? {
        if preferences[.activity] != nil {
            return "Heart Rate and Workouts will default to the same source as Activity, but you can change them to different sources if you want."
        }
        return nil
    }
    
    init() {
        initializePreferences()
    }
    
    private func initializePreferences() {
        for category in HealthCategory.allCases {
            preferences[category] = nil
        }
    }
    
    func loadAvailableSources() async {
        isLoading = true
        error = nil
        
        do {
            // Load available sources
            let sources = try await networkManager.getAvailableDataSources()
            availableSources = sources
            
            // Try to load existing preferences
            do {
                let preferencesResponse = try await networkManager.getUserDataSourcePreferences()
                if let existingPreferences = preferencesResponse.preferences {
                    currentPreferences = existingPreferences
                    updateLocalPreferences(from: existingPreferences)
                }
            } catch {
                // User might not have preferences yet, which is fine for new users
                print("No existing preferences found (expected for new users): \(error)")
            }
            
        } catch {
            self.error = "Failed to load data sources: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
    
    private func updateLocalPreferences(from serverPreferences: UserDataSourcePreferences) {
        preferences[.activity] = serverPreferences.activity_source
        preferences[.sleep] = serverPreferences.sleep_source
        preferences[.nutrition] = serverPreferences.nutrition_source
        preferences[.bodyComposition] = serverPreferences.body_composition_source
        preferences[.heartHealth] = serverPreferences.heart_health_source // Heart data comes from heart_health_source
        preferences[.workouts] = serverPreferences.activity_source // Workouts come from activity source
    }
    
    func getSourcesForCategory(_ category: HealthCategory) -> [PreferenceDataSource] {
        return availableSources.filter { source in
            source.supports(category: category)
        }
    }
    
    func selectSource(_ sourceName: String, for category: HealthCategory) {
        print("🎯 Selecting source '\(sourceName)' for category '\(category.rawValue)'")
        preferences[category] = sourceName
        
        // If selecting activity source, also update heart and workouts with visual feedback
        if category == .activity {
            print("🔗 Auto-linking Heart and Workouts to Activity source: \(sourceName)")
            preferences[.heartHealth] = sourceName
            preferences[.workouts] = sourceName
        }
        
        // Auto-select Apple Health for all categories if user hasn't made selections
        if sourceName == "apple_health" && preferences.values.compactMap({ $0 }).count == 1 {
            print("🍎 Auto-selecting Apple Health for all available categories")
            for cat in HealthCategory.allCases {
                if preferences[cat] == nil && getSourcesForCategory(cat).contains(where: { $0.source_name == "apple_health" }) {
                    preferences[cat] = "apple_health"
                    print("🔗 Auto-selected Apple Health for \(cat.rawValue)")
                }
            }
        }
        
        print("📊 Updated preferences: \(preferences)")
    }
    
    func getSelectedSource(for category: HealthCategory) -> String? {
        return preferences[category] ?? nil
    }
    
    func getSelectedSourceDisplay(for category: HealthCategory) -> String {
        guard let sourceName = preferences[category], let unwrappedSourceName = sourceName else {
            return "Not selected"
        }
        
        if let source = availableSources.first(where: { $0.source_name == unwrappedSourceName }) {
            return source.display_name
        } else {
            return unwrappedSourceName
        }
    }
    
    func savePreferences() async {
        isLoading = true
        error = nil
        
        let newPreferences = UserDataSourcePreferences(
            activity_source: preferences[.activity] ?? nil,
            sleep_source: preferences[.sleep] ?? nil,
            nutrition_source: preferences[.nutrition] ?? nil,
            body_composition_source: preferences[.bodyComposition] ?? nil,
            heart_health_source: preferences[.heartHealth] ?? nil
        )
        
        do {
            let createdPrefs = try await networkManager.createUserDataSourcePreferences(newPreferences)
            currentPreferences = createdPrefs
            // Successfully created, ensure error is nil
            self.error = nil
            self.showError = false
        } catch let creationError {
            print("⚠️ Create preferences failed: \(creationError.localizedDescription)")
            
            do {
                let updatedPrefs = try await networkManager.updateUserDataSourcePreferences(newPreferences)
                currentPreferences = updatedPrefs
                // Successfully updated, ensure error is nil
                self.error = nil
                self.showError = false
            } catch let updateError {
                print("❌ Update preferences also failed: \(updateError.localizedDescription)")
                self.error = "Failed to save preferences. Update attempt failed: \(updateError.localizedDescription)"
                self.showError = true
            }
        }
        
        isLoading = false
    }
    
    func resetSelections() {
        initializePreferences()
        currentPreferences = .empty
    }
    
    func getSourceIcon(_ sourceName: String) -> String {
        return availableSources.first { $0.source_name == sourceName }?.iconName ?? "app.connected.to.app.below.fill"
    }
    
    func getSourceDisplayName(_ sourceName: String) -> String {
        return availableSources.first { $0.source_name == sourceName }?.display_name ?? sourceName
    }
    
    func isSourceConnected(_ sourceName: String) -> Bool {
        // For now, assume Apple Health is always available, others need setup
        return sourceName == "apple_health"
    }
    
    func getIntegrationTypeDisplayName(_ sourceName: String) -> String {
        return availableSources.first { $0.source_name == sourceName }?.integrationTypeDisplayName ?? "Connect"
    }
    
    func clearError() {
        error = nil
        showError = false
    }
    
    func clearCategoryPreference(_ category: HealthCategory) async {
        isLoading = true
        error = nil
        
        do {
            // Create updated preferences with the category cleared using the updated() method
            let newPreferences = currentPreferences.updated(category: category, sourceName: nil)
            
            let updatedPreferences = try await networkManager.updateUserDataSourcePreferences(newPreferences)
            currentPreferences = updatedPreferences
            
        } catch {
            self.error = "Failed to clear preference: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
}

// MARK: - Data Source Selection State Manager
@MainActor
class DataSourceSettingsViewModel: ObservableObject {
    @Published var availableSources: [PreferenceDataSource] = []
    @Published var currentPreferences: UserDataSourcePreferences = .empty
    @Published var isLoading = false
    @Published var error: String?
    @Published var showError = false
    
    private let networkManager = NetworkManager.shared
    
    func loadData() async {
        isLoading = true
        error = nil
        
        do {
            async let sourcesTask = networkManager.getAvailableDataSources()
            async let preferencesTask = networkManager.getUserDataSourcePreferences()
            
            let (sources, preferencesResponse) = try await (sourcesTask, preferencesTask)
            
            availableSources = sources
            currentPreferences = preferencesResponse.preferences ?? .empty
            
        } catch {
            self.error = "Failed to load data: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
    
    func currentSourceName(for category: HealthCategory) -> String? {
        guard let sourceName = currentPreferences.preferredSource(for: category) else { return nil }
        return availableSources.first { $0.source_name == sourceName }?.display_name
    }
    
    func isConnected(category: HealthCategory) -> Bool {
        guard let sourceName = currentPreferences.preferredSource(for: category) else { return false }
        // For now, assume Apple Health is always connected
        return sourceName == "apple_health"
    }
    
    func changeSource(for category: HealthCategory, to sourceName: String) async {
        isLoading = true
        error = nil
        
        // Check if source requires connection and isn't connected
        if sourceName != "apple_health" && !isSourceActuallyConnected(sourceName) {
            let sourceName = availableSources.first { $0.source_name == sourceName }?.display_name ?? sourceName
            self.error = "Please connect your \(sourceName) account first before selecting it as a data source. Go to Connected Apps to set up the connection."
            self.showError = true
            isLoading = false
            return
        }
        
        do {
            try await networkManager.setPreferredSourceForCategory(category: category, sourceName: sourceName)
            
            // Reload preferences to get updated state
            let preferencesResponse = try await networkManager.getUserDataSourcePreferences()
            currentPreferences = preferencesResponse.preferences ?? .empty
            
        } catch {
            let sourceName = availableSources.first { $0.source_name == sourceName }?.display_name ?? sourceName
            
            // Check if it's a connection-related error
            if error.localizedDescription.contains("not found") || error.localizedDescription.contains("connected") {
                self.error = "Please connect your \(sourceName) account first. Go to Connected Apps to set up the connection."
            } else {
                self.error = "Failed to change source to \(sourceName): \(error.localizedDescription)"
            }
            showError = true
        }
        
        isLoading = false
    }
    
    private func isSourceActuallyConnected(_ sourceName: String) -> Bool {
        // For now, only Apple Health is considered connected
        // In the future, this would check actual OAuth connection status
        return sourceName == "apple_health"
    }
    
    func clearError() {
        error = nil
        showError = false
    }
    
    func resetAllPreferences() async {
        isLoading = true
        error = nil
        
        do {
            try await networkManager.deleteUserDataSourcePreferences()
            currentPreferences = .empty
        } catch {
            self.error = "Failed to reset preferences: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
    
    func clearCategoryPreference(_ category: HealthCategory) async {
        isLoading = true
        error = nil
        
        do {
            // Create updated preferences with the category cleared using the updated() method
            let newPreferences = currentPreferences.updated(category: category, sourceName: nil)
            
            let updatedPreferences = try await networkManager.updateUserDataSourcePreferences(newPreferences)
            currentPreferences = updatedPreferences
            
        } catch {
            self.error = "Failed to clear preference: \(error.localizedDescription)"
            showError = true
        }
        
        isLoading = false
    }
} 