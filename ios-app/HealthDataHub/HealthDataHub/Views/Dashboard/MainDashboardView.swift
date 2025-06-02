import SwiftUI

struct MainDashboardView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var selectedTab = 0
    
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
            setupHealthKit()
        }
    }
    
    private func setupHealthKit() {
        if !healthKitManager.isAuthorized {
            healthKitManager.requestHealthKitPermissions()
        }
    }
}

// MARK: - Dashboard Home View

struct DashboardHomeView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    
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
                                if case .success = healthKitManager.syncStatus {
                                    return "checkmark.circle.fill"
                                } else {
                                    return "arrow.clockwise.circle"
                                }
                            }())
                                .foregroundColor({
                                    if case .success = healthKitManager.syncStatus {
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
                            value: "8,532",
                            icon: "figure.walk",
                            color: .blue
                        )
                        
                        QuickStatCard(
                            title: "Sleep",
                            value: "7h 23m",
                            icon: "bed.double",
                            color: .purple
                        )
                        
                        QuickStatCard(
                            title: "Heart Rate",
                            value: "72 BPM",
                            icon: "heart.fill",
                            color: .red
                        )
                        
                        QuickStatCard(
                            title: "Active Calories",
                            value: "456 kcal",
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
                                    healthKitManager.syncLatestData()
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
                healthKitManager.syncLatestData()
            }
        }
        .onAppear {
        }
    }
    
    private var syncStatusText: String {
        switch healthKitManager.syncStatus {
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
}

// MARK: - Supporting Views

struct QuickStatCard: View {
    let title: String
    let value: String
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
    @StateObject private var healthKitManager = HealthKitManager()
    
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
                        
                        Text(healthKitManager.isAuthorized ? "Connected" : "Not Connected")
                            .foregroundColor(healthKitManager.isAuthorized ? .green : .orange)
                    }
                    
                    if !healthKitManager.isAuthorized {
                        Button("Enable HealthKit") {
                            healthKitManager.requestHealthKitPermissions()
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