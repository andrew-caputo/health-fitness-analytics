import SwiftUI
import HealthKit
import BackgroundTasks

@main
struct HealthDataHubApp: App {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var backgroundSyncManager = BackgroundSyncManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitManager)
                .environmentObject(backgroundSyncManager)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        // Register background tasks
        backgroundSyncManager.registerBackgroundTasks()
        
        // Request HealthKit permissions on app launch
        healthKitManager.requestHealthKitPermissions()
    }
} 