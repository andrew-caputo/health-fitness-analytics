import SwiftUI
import HealthKit

struct ContentView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var backgroundSyncManager: BackgroundSyncManager
    @StateObject private var networkManager = NetworkManager.shared
    
    @State private var selectedTab = 0
    
    var body: some View {
        Group {
            if networkManager.isAuthenticated {
                authenticatedView
            } else {
                LoginView()
            }
        }
        .environmentObject(networkManager)
    }
    
    private var authenticatedView: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            DashboardView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("Dashboard")
                }
                .tag(0)
            
            // Charts Tab
            HealthChartsView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Charts")
                }
                .tag(1)
            
            // Connected Apps Tab
            ConnectedAppsDetailView()
                .tabItem {
                    Image(systemName: "app.connected.to.app.below.fill")
                    Text("Apps")
                }
                .tag(2)
            
            // Trends Tab
            TrendsAnalysisView()
                .tabItem {
                    Image(systemName: "chart.bar.xaxis")
                    Text("Trends")
                }
                .tag(3)
            
            // Privacy Tab
            PrivacyDashboardView()
                .tabItem {
                    Image(systemName: "shield.checkered")
                    Text("Privacy")
                }
                .tag(4)
            
            // Sync Tab
            SyncDashboardView()
                .tabItem {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Sync")
                }
                .tag(5)
            
            // Notifications Tab
            NotificationCenterView()
                .tabItem {
                    Image(systemName: "bell")
                    Text("Alerts")
                }
                .tag(6)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(7)
        }
        .onAppear {
            setupInitialData()
        }
    }
    
    private func setupInitialData() {
        healthKitManager.updateConnectedApps()
    }
}

// MARK: - Dashboard View

struct DashboardView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var backgroundSyncManager: BackgroundSyncManager
    
    @State private var stepCount: Int = 0
    @State private var heartRate: Int = 0
    @State private var workoutCount: Int = 0
    @State private var sleepHours: Double = 0.0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // HealthKit Status Card
                    HealthKitStatusCard()
                    
                    // Health Metrics Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        HealthMetricCard(
                            title: "Steps",
                            value: "\(stepCount)",
                            unit: "steps",
                            icon: "figure.walk",
                            color: .blue
                        )
                        
                        HealthMetricCard(
                            title: "Heart Rate",
                            value: "\(heartRate)",
                            unit: "bpm",
                            icon: "heart.fill",
                            color: .red
                        )
                        
                        HealthMetricCard(
                            title: "Workouts",
                            value: "\(workoutCount)",
                            unit: "today",
                            icon: "figure.strengthtraining.traditional",
                            color: .orange
                        )
                        
                        HealthMetricCard(
                            title: "Sleep",
                            value: String(format: "%.1f", sleepHours),
                            unit: "hours",
                            icon: "bed.double.fill",
                            color: .purple
                        )
                    }
                    
                    // Quick Actions
                    QuickActionsCard()
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Health Dashboard")
            .refreshable {
                await refreshHealthData()
            }
        }
        .onAppear {
            loadHealthData()
        }
    }
    
    private func loadHealthData() {
        // Load step count
        healthKitManager.readStepCount { samples in
            let todaySteps = samples.filter { sample in
                Calendar.current.isDateInToday(sample.startDate)
            }.reduce(0) { total, sample in
                total + Int(sample.quantity.doubleValue(for: .count()))
            }
            
            DispatchQueue.main.async {
                self.stepCount = todaySteps
            }
        }
        
        // Load heart rate
        healthKitManager.readHeartRate { samples in
            if let latestSample = samples.first {
                let bpm = Int(latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())))
                DispatchQueue.main.async {
                    self.heartRate = bpm
                }
            }
        }
        
        // Load workouts
        healthKitManager.readWorkouts { workouts in
            let todayWorkouts = workouts.filter { workout in
                Calendar.current.isDateInToday(workout.startDate)
            }
            
            DispatchQueue.main.async {
                self.workoutCount = todayWorkouts.count
            }
        }
        
        // Load sleep data
        healthKitManager.readSleepData { samples in
            let lastNightSleep = samples.filter { sample in
                Calendar.current.isDateInYesterday(sample.startDate) || Calendar.current.isDateInToday(sample.startDate)
            }.reduce(0.0) { total, sample in
                total + sample.endDate.timeIntervalSince(sample.startDate)
            }
            
            DispatchQueue.main.async {
                self.sleepHours = lastNightSleep / 3600 // Convert to hours
            }
        }
    }
    
    private func refreshHealthData() async {
        loadHealthData()
        backgroundSyncManager.performManualSync()
    }
}

// MARK: - HealthKit Status Card

struct HealthKitStatusCard: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: healthKitManager.isAuthorized ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(healthKitManager.isAuthorized ? .green : .orange)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("HealthKit Status")
                        .font(.headline)
                    Text(healthKitManager.isAuthorized ? "Connected" : "Not Connected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !healthKitManager.isAuthorized {
                    Button("Connect") {
                        healthKitManager.requestHealthKitPermissions()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            
            if healthKitManager.isAuthorized {
                HStack {
                    Text("Access to \(healthKitManager.connectedApps.count) health apps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Manage") {
                        healthKitManager.openHealthApp()
                    }
                    .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Health Metric Card

struct HealthMetricCard: View {
    let title: String
    let value: String
    let unit: String
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Quick Actions Card

struct QuickActionsCard: View {
    @EnvironmentObject var backgroundSyncManager: BackgroundSyncManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                Button(action: {
                    backgroundSyncManager.performManualSync()
                }) {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!backgroundSyncManager.canPerformSync())
                
                Button(action: {
                    healthKitManager.openHealthApp()
                }) {
                    Label("Health App", systemImage: "heart.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Connected Apps View

struct ConnectedAppsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(healthKitManager.connectedApps, id: \.self) { app in
                        HStack {
                            Image(systemName: "app.fill")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(app)
                                    .font(.headline)
                                Text("Syncing health data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Connected Health Apps")
                } footer: {
                    Text("These apps are sharing data through HealthKit. You can manage permissions in the Health app.")
                }
            }
            .navigationTitle("Connected Apps")
            .refreshable {
                healthKitManager.updateConnectedApps()
            }
        }
    }
}

// MARK: - Sync Status View

struct SyncStatusView: View {
    @EnvironmentObject var backgroundSyncManager: BackgroundSyncManager
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Sync Status")
                                .font(.headline)
                            Text(backgroundSyncManager.getSyncStatusDescription())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if backgroundSyncManager.backgroundSyncStatus == .syncing {
                            ProgressView()
                        } else {
                            Button("Sync Now") {
                                backgroundSyncManager.performManualSync()
                            }
                            .disabled(!backgroundSyncManager.canPerformSync())
                        }
                    }
                    
                    if backgroundSyncManager.backgroundSyncStatus == .syncing {
                        ProgressView(value: backgroundSyncManager.syncProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                    }
                } header: {
                    Text("Background Sync")
                } footer: {
                    Text("Health data is automatically synced in the background. You can also manually sync at any time.")
                }
                
                if let lastSync = backgroundSyncManager.lastBackgroundSync {
                    Section {
                        HStack {
                            Text("Last Sync")
                            Spacer()
                            Text(lastSync, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let errorMessage = backgroundSyncManager.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    } header: {
                        Text("Error")
                    }
                }
            }
            .navigationTitle("Sync Status")
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var backgroundSyncManager: BackgroundSyncManager
    @EnvironmentObject var networkManager: NetworkManager
    
    @State private var showLogoutAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("HealthKit Access")
                        Spacer()
                        Text(healthKitManager.isAuthorized ? "Enabled" : "Disabled")
                            .foregroundColor(healthKitManager.isAuthorized ? .green : .red)
                    }
                    
                    Button("Manage HealthKit Permissions") {
                        healthKitManager.openHealthApp()
                    }
                } header: {
                    Text("Health Data")
                } footer: {
                    Text("Manage which health data types this app can access through the Health app.")
                }
                
                Section {
                    Button("Reset Sync Status") {
                        backgroundSyncManager.resetSyncStatus()
                    }
                    
                    Button("Schedule Background Sync") {
                        backgroundSyncManager.scheduleBackgroundSync()
                    }
                } header: {
                    Text("Sync Settings")
                }
                
                Section {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    if let user = networkManager.currentUser {
                        HStack {
                            Text("Account")
                            Spacer()
                            Text(user.email)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("About")
                }
                
                Section {
                    Button("Sign Out") {
                        showLogoutAlert = true
                    }
                    .foregroundColor(.red)
                } header: {
                    Text("Account")
                }
            }
            .navigationTitle("Settings")
            .alert("Sign Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await networkManager.logout()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(HealthKitManager())
            .environmentObject(BackgroundSyncManager())
    }
} 