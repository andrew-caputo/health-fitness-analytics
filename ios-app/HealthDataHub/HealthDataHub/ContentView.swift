import SwiftUI

struct ContentView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var healthDataManager = HealthDataManager.shared
    @State private var showDataSourceSelection = false
    @State private var isNewUser = false
    
    var body: some View {
        Group {
            if networkManager.isAuthenticated {
                if showDataSourceSelection && isNewUser {
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
                    }
                } catch {
                    // Token is invalid, clear authentication
                    try? await networkManager.logout()
                }
            }
        }
    }
    
    private func checkForNewUserOnboarding() {
        // Check if this is a new user who needs data source selection
        Task {
            // REVERTED: Original logic restored
            do {
                let preferencesResponse = try await networkManager.getUserDataSourcePreferences()
                if preferencesResponse.preferences == nil {
                    // New user - show data source selection
                    await MainActor.run {
                        isNewUser = true
                        showDataSourceSelection = true
                        print("✨ ContentView: New user detected or no preferences found. Setting showDataSourceSelection = true") // Log to KEEP
                    }
                } else {
                    await MainActor.run {
                        isNewUser = false
                        showDataSourceSelection = false
                        print("👍 ContentView: Existing user with preferences found. Setting showDataSourceSelection = false") // Log to KEEP
                    }
                }
            } catch {
                // If we can't check preferences, assume new user and show onboarding for safety
                // This could happen if the user logs in for the first time and the network request fails
                await MainActor.run {
                    isNewUser = true
                    showDataSourceSelection = true
                    print("⚠️ ContentView: Error checking preferences (\\(error.localizedDescription)). Assuming new user. Setting showDataSourceSelection = true") // Log to KEEP
                }
            }
        }
    }
}

#Preview {
    ContentView()
} 