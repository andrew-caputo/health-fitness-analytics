import SwiftUI

struct MainDashboardView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var healthDataManager = HealthDataManager.shared
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
    @StateObject private var healthDataManager = HealthDataManager.shared
    
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
                        QuickStatCard(
                            title: "Today's Steps",
                            value: healthDataManager.todaySteps > 0 ? "\(healthDataManager.todaySteps)" : "No data",
                            subtitle: displaySourceName(healthDataManager.userPreferences?.activity_source),
                            icon: "figure.walk",
                            color: .blue
                        )
                        
                        QuickStatCard(
                            title: "Sleep",
                            value: healthDataManager.lastNightSleep > 0 ? formatSleepDuration(healthDataManager.lastNightSleep) : "No data",
                            subtitle: displaySourceName(healthDataManager.userPreferences?.sleep_source),
                            icon: "bed.double",
                            color: .purple
                        )
                        
                        QuickStatCard(
                            title: "Heart Rate",
                            value: healthDataManager.currentHeartRate > 0 ? "\(healthDataManager.currentHeartRate) BPM" : "No data",
                            subtitle: displaySourceName(healthDataManager.userPreferences?.heart_health_source ?? healthDataManager.userPreferences?.activity_source),
                            icon: "heart.fill",
                            color: .red
                        )
                        
                        QuickStatCard(
                            title: "Calories",
                            value: healthDataManager.todayActiveCalories > 0 ? "\(healthDataManager.todayActiveCalories) kcal" : "No data",
                            subtitle: displaySourceName(healthDataManager.userPreferences?.activity_source),
                            icon: "flame.fill",
                            color: .orange
                        )
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
                                    print("🔄 === SYNC BUTTON TAPPED ===")
                                    print("🔄 Manual sync triggered from dashboard")
                                    print("🔄 Auth status before sync: \(healthDataManager.isAuthorized)")
                                    healthDataManager.syncLatestData()
                                }
                            )
                            
                            QuickActionRow(
                                icon: "stethoscope",
                                title: "Debug Data Flow",
                                action: {
                                    print("🔍 === DEBUG BUTTON TAPPED ===")
                                    print("🔍 === MANUAL DEBUG SYNC TRIGGERED ===")
                                    print("🔍 Authorization status: \(healthDataManager.isAuthorized)")
                                    print("🔍 Current sync status: \(healthDataManager.syncStatus)")
                                    print("🔍 Current user preferences: \(String(describing: healthDataManager.userPreferences))")
                                    print("🔍 Current data values - Steps: \(healthDataManager.todaySteps), Calories: \(healthDataManager.todayActiveCalories), HR: \(healthDataManager.currentHeartRate), Sleep: \(healthDataManager.lastNightSleep)")
                                    print("🔍 About to call syncLatestData()...")
                                    healthDataManager.syncLatestData()
                                }
                            )
                            
                            QuickActionRow(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "View Detailed Charts",
                                action: {
                                    // TODO: Navigate to charts view
                                }
                            )
                            
                            QuickActionRow(
                                icon: "person.2.fill",
                                title: "Connected Apps",
                                action: {
                                    // TODO: Navigate to connected apps settings
                                }
                            )
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
            
            if healthDataManager.isAuthorized {
                print("🚀 Authorization confirmed - triggering sync")
                healthDataManager.syncLatestData()
            } else {
                print("❌ Not authorized - skipping sync. Requesting permissions...")
                healthDataManager.requestHealthKitPermissions()
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
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
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
    @StateObject private var healthDataManager = HealthDataManager.shared
    
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
            healthDataManager.refreshAuthorizationStatus()
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