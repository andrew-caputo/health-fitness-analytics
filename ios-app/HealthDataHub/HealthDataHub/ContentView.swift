import SwiftUI

struct ContentView: View {
    @StateObject private var networkManager = NetworkManager.shared
    
    var body: some View {
        Group {
            if networkManager.isAuthenticated {
                MainDashboardView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            // Check for stored authentication on app launch
            if networkManager.isAuthenticated {
                    Task {
                    do {
                        // Verify that the stored token is still valid
                        _ = try await networkManager.verifyToken()
                    } catch {
                        // Token is invalid, clear authentication
                        try? await networkManager.logout()
                    }
                }
            }
        }
    }
}

#Preview {
        ContentView()
} 