import SwiftUI

struct ContentView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var healthDataManager = HealthDataManager.shared
    @State private var showDataSourceSelection = false
    @State private var isNewUser = false
    @State private var isCheckingOnboarding = false
    
    var body: some View {
        Group {
            if networkManager.isAuthenticated {
                if isCheckingOnboarding {
                    // Show loading while determining if onboarding is needed
                    LoadingView(message: "Setting up your account...")
                } else if showDataSourceSelection && isNewUser {
                    DataSourceSelectionView(onComplete: {
                        showDataSourceSelection = false
                        isNewUser = false
                    })
                    .environmentObject(healthDataManager)
                    .environmentObject(networkManager)
                } else {
                    MainDashboardView()
                        .environmentObject(healthDataManager)
                        .environmentObject(networkManager)
                }
            } else {
                LoginView()
                    .environmentObject(networkManager)
            }
        }
        .onAppear {
            checkAuthenticationState()
        }
        .onChange(of: networkManager.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                checkForNewUserOnboarding()
            }
        }
    }
    
    private func checkAuthenticationState() {
        // Check for stored authentication on app launch
        if networkManager.isAuthenticated {
            Task {
                do {
                    // Verify that the stored token is still valid
                    let isValid = try await networkManager.verifyToken()
                    if !isValid {
                        // Token is invalid, clear authentication
                        try? await networkManager.logout()
                    } else {
                        // Token is valid, check onboarding for existing session
                        checkForNewUserOnboarding()
                    }
                } catch {
                    // Token is invalid, clear authentication
                    try? await networkManager.logout()
                }
            }
        }
    }
    
    private func checkForNewUserOnboarding() {
        // Set loading state to prevent MainDashboardView from showing prematurely
        isCheckingOnboarding = true
        
        // Check if this is a new user who needs data source selection
        Task {
            do {
                print("🔍 ContentView: Starting onboarding evaluation...")
                let preferencesResponse = try await networkManager.getUserDataSourcePreferences()
                let hasPreferences = preferencesResponse.preferences != nil
                print("📋 ContentView: User has preferences: \(hasPreferences)")
                
                // For new users, don't check HealthKit permissions yet - let them complete data source selection first
                // For returning users, only check HealthKit if they have Apple Health selections
                let needsHealthKitCheck = hasPreferences && userHasAppleHealthSelections(preferencesResponse.preferences)
                let hasHealthKitPermissions = needsHealthKitCheck ? await checkHealthKitPermissionsWithRetry() : true
                print("🍎 ContentView: Needs HealthKit check: \(needsHealthKitCheck), Has permissions: \(hasHealthKitPermissions)")
                
                // Determine if onboarding is needed
                let needsOnboarding = !hasPreferences || (needsHealthKitCheck && !hasHealthKitPermissions)
                
                await MainActor.run {
                    // Clear loading state first
                    isCheckingOnboarding = false
                    
                    if needsOnboarding {
                        isNewUser = !hasPreferences
                        showDataSourceSelection = true
                        print("✨ ContentView: Onboarding needed - Preferences: \(hasPreferences), HealthKit: \(hasHealthKitPermissions)")
                    } else {
                        isNewUser = false
                        showDataSourceSelection = false
                        print("👍 ContentView: User setup complete - Preferences: \(hasPreferences), HealthKit: \(hasHealthKitPermissions)")
                    }
                }
            } catch {
                // If we can't check preferences, assume new user and show onboarding for safety
                await MainActor.run {
                    isCheckingOnboarding = false
                    isNewUser = true
                    showDataSourceSelection = true
                    print("⚠️ ContentView: Error checking preferences (\(error.localizedDescription)). Assuming new user.")
                }
            }
        }
    }
    
    private func userHasAppleHealthSelections(_ preferences: UserDataSourcePreferences?) -> Bool {
        guard let prefs = preferences else { return false }
        
        return prefs.activity_source == "apple_health" ||
               prefs.sleep_source == "apple_health" ||
               prefs.nutrition_source == "apple_health" ||
               prefs.body_composition_source == "apple_health" ||
               prefs.heart_health_source == "apple_health"
    }
    
    private func checkHealthKitPermissionsWithRetry() async -> Bool {
        // Give iOS time to process permissions if they were recently granted
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        return await MainActor.run {
            HealthDataManager.shared.hasRequiredPermissions()
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    ContentView()
} 