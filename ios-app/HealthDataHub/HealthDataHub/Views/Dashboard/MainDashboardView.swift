import SwiftUI

struct MainDashboardView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @EnvironmentObject var healthDataManager: HealthDataManager
    @StateObject private var viewModel = MainDashboardViewModel()
    @State private var selectedTab = 0
    @State private var isSettingsPresented = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Home
            DashboardHomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            // AI Insights
            AIInsightsDashboardView()
                .tabItem {
                    Image(systemName: "brain")
                    Text("AI Insights")
                }
                .tag(1)
            
            // Goals & Progress
            PersonalizedGoalsView()
                .tabItem {
                    Image(systemName: "target")
                    Text("Goals")
                }
                .tag(2)
            
            // Achievements
            AchievementsView()
                .tabItem {
                    Image(systemName: "trophy.fill")
                    Text("Achievements")
                }
                .tag(3)
            
            // Health Coach
            HealthCoachView()
                .tabItem {
                    Image(systemName: "person.badge.plus")
                    Text("Coach")
                }
                .tag(4)
            
            // Settings & Profile
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
                .tag(5)
        }
        .onAppear {
            if healthDataManager.isAuthorized {
                healthDataManager.syncLatestData()
            }
        }
    }
    
    private func setupHealthKit() {
        if !healthDataManager.isAuthorized {
            healthDataManager.requestHealthKitPermissions()
        }
    }
}

// MARK: - Dashboard Home View

struct DashboardHomeView: View {
    @EnvironmentObject var healthDataManager: HealthDataManager
    
    init() {
        print("🏠 === DashboardHomeView INITIALIZED ===")
        print("🏠 This confirms updated code is running")
        NSLog("🏠 NSLOG: DashboardHomeView initialized - this should appear in console")
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome back!")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Here's your health overview")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Sync Status
                        VStack(spacing: 4) {
                            Image(systemName: {
                                if case .success = healthDataManager.syncStatus {
                                    return "checkmark.circle.fill"
                                } else {
                                    return "arrow.clockwise.circle"
                                }
                            }())
                                .foregroundColor({
                                    if case .success = healthDataManager.syncStatus {
                                        return .green
                                    } else {
                                        return .blue
                                    }
                                }())
                                .font(.title2)
                            
                            Text(syncStatusText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Quick Stats Cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        NavigationLink(destination: HealthChartsView(initialMetric: .steps)) {
                            QuickStatCard(
                                title: "Today's Steps",
                                value: healthDataManager.todaySteps > 0 ? "\(healthDataManager.todaySteps)" : "No data",
                                subtitle: displaySourceName(healthDataManager.userPreferences?.activity_source),
                                icon: "figure.walk",
                                color: .blue,
                                action: nil
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .simultaneousGesture(TapGesture().onEnded {
                            NSLog("🚨 CARD TAP DETECTED - Today's Steps card was pressed")
                            print("🚨 === TODAY'S STEPS CARD TAPPED ===")
                            NSLog("🚨 === TODAY'S STEPS CARD TAPPED ===")
                            print("📊 Navigating to steps detail in HealthChartsView...")
                            NSLog("📊 Navigating to steps detail in HealthChartsView...")
                        })
                        
                        NavigationLink(destination: HealthChartsView(initialMetric: .sleep)) {
                            QuickStatCard(
                                title: "Sleep",
                                value: healthDataManager.lastNightSleep > 0 ? formatSleepDuration(healthDataManager.lastNightSleep) : "No data",
                                subtitle: displaySourceName(healthDataManager.userPreferences?.sleep_source),
                                icon: "bed.double",
                                color: .purple,
                                action: nil
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .simultaneousGesture(TapGesture().onEnded {
                            NSLog("🚨 CARD TAP DETECTED - Sleep card was pressed")
                            print("🚨 === SLEEP CARD TAPPED ===")
                            NSLog("🚨 === SLEEP CARD TAPPED ===")
                            print("📊 Navigating to sleep detail in HealthChartsView...")
                            NSLog("📊 Navigating to sleep detail in HealthChartsView...")
                        })
                        
                        NavigationLink(destination: HealthChartsView(initialMetric: .heartRate)) {
                            QuickStatCard(
                                title: "Resting Heart Rate",
                                value: healthDataManager.currentHeartRate > 0 ? "\(healthDataManager.currentHeartRate) BPM" : "No data",
                                subtitle: displaySourceName(healthDataManager.userPreferences?.heart_health_source ?? healthDataManager.userPreferences?.activity_source),
                                icon: "heart.fill",
                                color: .red,
                                action: nil
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .simultaneousGesture(TapGesture().onEnded {
                            NSLog("🚨 CARD TAP DETECTED - Resting Heart Rate card was pressed")
                            print("🚨 === RESTING HEART RATE CARD TAPPED ===")
                            NSLog("🚨 === RESTING HEART RATE CARD TAPPED ===")
                            print("📊 Navigating to resting heart rate detail in HealthChartsView...")
                            NSLog("📊 Navigating to resting heart rate detail in HealthChartsView...")
                        })
                        
                        NavigationLink(destination: HealthChartsView(initialMetric: .activeEnergy)) {
                            QuickStatCard(
                                title: "Calories",
                                value: healthDataManager.todayActiveCalories > 0 ? "\(healthDataManager.todayActiveCalories) kcal" : "No data",
                                subtitle: displaySourceName(healthDataManager.userPreferences?.activity_source),
                                icon: "flame.fill",
                                color: .orange,
                                action: nil
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .simultaneousGesture(TapGesture().onEnded {
                            NSLog("🚨 CARD TAP DETECTED - Calories card was pressed")
                            print("🚨 === CALORIES CARD TAPPED ===")
                            NSLog("🚨 === CALORIES CARD TAPPED ===")
                            print("📊 Navigating to calories detail in HealthChartsView...")
                            NSLog("📊 Navigating to calories detail in HealthChartsView...")
                        })
                    }
                    .padding(.horizontal)
                    
                    // Quick Actions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Actions")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            QuickActionRow(
                                icon: "arrow.clockwise",
                                title: "Sync Health Data",
                                action: {
                                    NSLog("🚨 BUTTON TAP DETECTED - Sync button was pressed")
                                    
                                    // Multiple logging methods for device compatibility
                                    print("🔄 === SYNC BUTTON TAPPED ===")
                                    NSLog("🔄 === SYNC BUTTON TAPPED ===")
                                    
                                    print("🔄 Manual sync triggered from dashboard")
                                    NSLog("🔄 Manual sync triggered from dashboard")
                                    
                                    print("🔄 Auth status before sync: \(healthDataManager.isAuthorized)")
                                    NSLog("🔄 Auth status before sync: %@", healthDataManager.isAuthorized ? "true" : "false")
                                    
                                    #if targetEnvironment(simulator)
                                        print("🔄 Running on SIMULATOR")
                                        NSLog("🔄 Running on SIMULATOR")
                                    #else
                                        print("🔄 Running on DEVICE")
                                        NSLog("🔄 Running on DEVICE")
                                    #endif
                                    
                                    healthDataManager.syncLatestData()
                                }
                            )
                            
                            QuickActionRow(
                                icon: "stethoscope",
                                title: "Debug Data Flow",
                                action: {
                                    NSLog("🚨 BUTTON TAP DETECTED - Debug button was pressed")
                                    
                                    // Multiple logging methods for device compatibility
                                    print("🔍 === DEBUG BUTTON TAPPED ===")
                                    NSLog("🔍 === DEBUG BUTTON TAPPED ===")
                                    
                                    print("🔍 === MANUAL DEBUG SYNC TRIGGERED ===")
                                    NSLog("🔍 === MANUAL DEBUG SYNC TRIGGERED ===")
                                    
                                    print("🔍 Authorization status: \(healthDataManager.isAuthorized)")
                                    NSLog("🔍 Authorization status: %@", healthDataManager.isAuthorized ? "true" : "false")
                                    
                                    #if targetEnvironment(simulator)
                                        print("🔍 Running on SIMULATOR")
                                        NSLog("🔍 Running on SIMULATOR")
                                    #else
                                        print("🔍 Running on DEVICE")
                                        NSLog("🔍 Running on DEVICE")
                                    #endif
                                    
                                    print("🔍 Current sync status: \(healthDataManager.syncStatus)")
                                    NSLog("🔍 Current sync status: %@", String(describing: healthDataManager.syncStatus))
                                    
                                    print("🔍 Current user preferences: \(String(describing: healthDataManager.userPreferences))")
                                    NSLog("🔍 Current user preferences: %@", String(describing: healthDataManager.userPreferences))
                                    
                                    print("🔍 Current data values - Steps: \(healthDataManager.todaySteps), Calories: \(healthDataManager.todayActiveCalories), HR: \(healthDataManager.currentHeartRate), Sleep: \(healthDataManager.lastNightSleep)")
                                    NSLog("🔍 Steps: %d, Calories: %d, HR: %d, Sleep: %.0f", healthDataManager.todaySteps, healthDataManager.todayActiveCalories, healthDataManager.currentHeartRate, healthDataManager.lastNightSleep)
                                    
                                    print("🔍 About to call syncLatestData()...")
                                    NSLog("🔍 About to call syncLatestData()...")
                                    
                                    healthDataManager.syncLatestData()
                                }
                            )
                            
                            // Navigation Links for main features
                            NavigationLink(destination: HealthChartsView()) {
                                HStack(spacing: 12) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                        .frame(width: 24)
                                    
                                    Text("View Detailed Charts")
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .simultaneousGesture(TapGesture().onEnded {
                                NSLog("🚨 NAVIGATION TAP DETECTED - View Detailed Charts navigation was pressed")
                                print("🚨 === VIEW DETAILED CHARTS NAVIGATION TAPPED ===")
                                NSLog("🚨 === VIEW DETAILED CHARTS NAVIGATION TAPPED ===")
                                print("📊 Navigating to HealthChartsView...")
                                NSLog("📊 Navigating to HealthChartsView...")
                            })
                            
                            NavigationLink(destination: DataSourceSettingsView()) {
                                HStack(spacing: 12) {
                                    Image(systemName: "person.2.fill")
                                        .foregroundColor(.blue)
                                        .font(.title3)
                                        .frame(width: 24)
                                    
                                    Text("Connected Apps")
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .simultaneousGesture(TapGesture().onEnded {
                                NSLog("🚨 NAVIGATION TAP DETECTED - Connected Apps navigation was pressed")
                                print("🚨 === CONNECTED APPS NAVIGATION TAPPED ===")
                                NSLog("🚨 === CONNECTED APPS NAVIGATION TAPPED ===")
                                print("🔗 Navigating to DataSourceSettingsView...")
                                NSLog("🔗 Navigating to DataSourceSettingsView...")
                            })
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Dashboard")
            .refreshable {
                healthDataManager.syncLatestData()
            }
        }
        .onAppear {
            print("🚀 DashboardHomeView onAppear triggered")
            print("🚀 HealthDataManager authorization status: \(healthDataManager.isAuthorized)")
            print("🚀 HealthDataManager auth status enum: \(healthDataManager.authorizationStatus)")
            print("🚀 Current sync status: \(healthDataManager.syncStatus)")
            
            // Only handle HealthKit authorization if user has completed onboarding
            // Check if user has preferences to determine if they've completed data source selection
            Task {
                do {
                    let preferencesResponse = try await NetworkManager.shared.getUserDataSourcePreferences()
                    let hasCompletedOnboarding = preferencesResponse.preferences != nil
                    
                    await MainActor.run {
                        if hasCompletedOnboarding {
                            if healthDataManager.isAuthorized {
                                print("🚀 Authorization confirmed - triggering sync")
                                healthDataManager.syncLatestData()
                            } else {
                                print("⚠️ User completed onboarding but HealthKit not authorized - will handle in settings")
                                // Don't automatically request permissions here - let user manage in settings
                            }
                        } else {
                            print("⏳ User hasn't completed onboarding yet - skipping HealthKit operations")
                        }
                    }
                } catch {
                    // If we can't check preferences, be conservative and don't request permissions
                    print("⚠️ Cannot verify onboarding status - skipping automatic HealthKit authorization")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func displaySourceName(_ sourceName: String?) -> String {
        guard let sourceName = sourceName else { return "Not configured" }
        
        switch sourceName.lowercased() {
        case "apple_health", "apple health", "healthkit":
            return "Apple Health"
        case "withings":
            return "Withings"
        case "oura":
            return "Oura Ring"
        case "fitbit":
            return "Fitbit"
        case "whoop":
            return "WHOOP"
        case "strava":
            return "Strava"
        case "myfitnesspal":
            return "MyFitnessPal"
        case "cronometer":
            return "Cronometer"
        case "csv":
            return "CSV Upload"
        default:
            return sourceName.capitalized
        }
    }
    
    private var syncStatusText: String {
        switch healthDataManager.syncStatus {
        case .idle:
            return "Ready"
        case .syncing:
            return "Syncing..."
        case .success:
            return "Up to date"
        case .error:
            return "Error"
        }
    }
    
    private func formatSleepDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "0m"
        }
    }
}

// MARK: - Supporting Views

struct QuickStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: (() -> Void)?
    
    var body: some View {
        let cardContent = VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
                
                // Add visual indicator that card is tappable
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        
        // Only apply onTapGesture if there's an action
        if let action = action {
            cardContent
                .onTapGesture {
                    action()
                }
        } else {
            cardContent
        }
    }
}

struct QuickActionRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.title3)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @EnvironmentObject var healthDataManager: HealthDataManager
    
    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section("Profile") {
                    if let user = networkManager.currentUser {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(user.email)
                                    .font(.headline)
                                
                                Text("Member since \(formatDate(user.createdAt))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // HealthKit Section
                Section("HealthKit") {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        
                        Text("HealthKit Status")
                        
                        Spacer()
                        
                        Text(healthDataManager.isAuthorized ? "Connected" : "Not Connected")
                            .foregroundColor(healthDataManager.isAuthorized ? .green : .orange)
                    }
                    
                    if !healthDataManager.isAuthorized {
                        Button("Enable HealthKit") {
                            healthDataManager.requestHealthKitPermissions()
                            // Refresh status after a delay to allow iOS to process the permission grant
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                healthDataManager.checkAuthorizationStatusWithRetry(delay: 0.5)
                            }
                        }
                    }
                }
                
                // Data Management
                Section("Data Management") {
                    NavigationLink(destination: DataSourceSettingsView()) {
                        Label("Data Sources", systemImage: "apps.iphone")
                    }
                    
                    NavigationLink(destination: PrivacyDashboardView()) {
                        Label("Privacy Dashboard", systemImage: "lock.shield")
                    }
                    
                    NavigationLink(destination: ConnectedAppsDetailView()) {
                        Label("Connected Apps", systemImage: "app.connected.to.app.below.fill")
                    }
                    
                    NavigationLink(destination: SyncDashboardView()) {
                        Label("Sync Settings", systemImage: "arrow.clockwise")
                    }
                }
                
                // Account Actions
                Section("Account") {
                    Button("Logout") {
                        Task {
                            do {
                                try await networkManager.logout()
                            } catch {
                                // Handle logout error if needed
                                print("Logout error: \(error)")
                            }
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
        }
        .onAppear {
            // Use delayed checking for better reliability
            healthDataManager.checkAuthorizationStatusWithRetry(delay: 0.5)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Refresh authorization status when app becomes active (user might have changed permissions in Health app)
            healthDataManager.checkAuthorizationStatusWithRetry(delay: 1.0)
        }
    }
    
    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "Unknown" }
        
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else { return "Unknown" }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        return displayFormatter.string(from: date)
    }
}

#Preview {
    MainDashboardView()
} 