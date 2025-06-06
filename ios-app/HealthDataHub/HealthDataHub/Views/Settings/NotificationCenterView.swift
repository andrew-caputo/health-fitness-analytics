import SwiftUI
import UserNotifications

struct NotificationCenterView: View {
    @State private var notifications: [HealthNotification] = []
    @State private var notificationSettings: NotificationSettings = NotificationSettings()
    @State private var isLoading = true
    @State private var showingSettings = false
    @State private var selectedFilter: NotificationFilter = .all
    
    enum NotificationFilter: String, CaseIterable {
        case all = "All"
        case insights = "Insights"
        case goals = "Goals"
        case alerts = "Alerts"
        case sync = "Sync"
        
        var icon: String {
            switch self {
            case .all: return "bell"
            case .insights: return "lightbulb"
            case .goals: return "target"
            case .alerts: return "exclamationmark.triangle"
            case .sync: return "arrow.triangle.2.circlepath"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Tabs
                filterTabs
                
                // Notifications List
                if isLoading {
                    ProgressView("Loading notifications...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredNotifications.isEmpty {
                    emptyState
                } else {
                    notificationsList
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadNotifications()
            }
        }
        .sheet(isPresented: $showingSettings) {
            NotificationSettingsView(settings: $notificationSettings)
        }
    }
    
    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(NotificationFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        count: notificationCount(for: filter),
                        onTap: {
                            selectedFilter = filter
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var notificationsList: some View {
        List {
            ForEach(groupedNotifications.keys.sorted(by: >), id: \.self) { date in
                Section {
                    ForEach(groupedNotifications[date] ?? []) { notification in
                        NotificationRow(
                            notification: notification,
                            onTap: {
                                handleNotificationTap(notification)
                            },
                            onDismiss: {
                                dismissNotification(notification)
                            }
                        )
                    }
                } header: {
                    Text(dateFormatter.string(from: date))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
            }
            
            // Mark All as Read
            if hasUnreadNotifications {
                Section {
                    Button("Mark All as Read") {
                        markAllAsRead()
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .listStyle(PlainListStyle())
        .refreshable {
            await loadNotifications()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedFilter.icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No \(selectedFilter.rawValue) Notifications")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("You're all caught up! New notifications will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var filteredNotifications: [HealthNotification] {
        switch selectedFilter {
        case .all:
            return notifications
        case .insights:
            return notifications.filter { $0.type == .insight }
        case .goals:
            return notifications.filter { $0.type == .goalAchievement || $0.type == .goalReminder }
        case .alerts:
            return notifications.filter { $0.type == .healthAlert }
        case .sync:
            return notifications.filter { $0.type == .syncUpdate }
        }
    }
    
    private var groupedNotifications: [Date: [HealthNotification]] {
        Dictionary(grouping: filteredNotifications) { notification in
            Calendar.current.startOfDay(for: notification.timestamp)
        }
    }
    
    private var hasUnreadNotifications: Bool {
        filteredNotifications.contains { !$0.isRead }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    // MARK: - Helper Methods
    
    private func notificationCount(for filter: NotificationFilter) -> Int {
        switch filter {
        case .all:
            return notifications.count
        case .insights:
            return notifications.filter { $0.type == .insight }.count
        case .goals:
            return notifications.filter { $0.type == .goalAchievement || $0.type == .goalReminder }.count
        case .alerts:
            return notifications.filter { $0.type == .healthAlert }.count
        case .sync:
            return notifications.filter { $0.type == .syncUpdate }.count
        }
    }
    
    private func loadNotifications() async {
        isLoading = true
        
        // Simulate loading
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            notifications = createMockNotifications()
            notificationSettings = createMockSettings()
            isLoading = false
        }
    }
    
    private func handleNotificationTap(_ notification: HealthNotification) {
        // Mark as read
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
        }
        
        // Handle notification action based on type
        switch notification.type {
        case .insight:
            // Navigate to insights view
            break
        case .goalAchievement, .goalReminder:
            // Navigate to goals view
            break
        case .healthAlert:
            // Show alert details
            break
        case .syncUpdate:
            // Navigate to sync dashboard
            break
        }
    }
    
    private func dismissNotification(_ notification: HealthNotification) {
        notifications.removeAll { $0.id == notification.id }
    }
    
    private func markAllAsRead() {
        for index in notifications.indices {
            notifications[index].isRead = true
        }
    }
    
    private func createMockNotifications() -> [HealthNotification] {
        return [
            HealthNotification(
                type: .insight,
                title: "Sleep Quality Improving",
                message: "Your sleep quality has improved by 15% this week. Keep up the consistent bedtime routine!",
                timestamp: Date(),
                isRead: false,
                priority: .medium,
                actionData: ["view": "sleep_insights"]
            ),
            HealthNotification(
                type: .goalAchievement,
                title: "Step Goal Achieved! 🎉",
                message: "Congratulations! You've reached your daily step goal of 10,000 steps.",
                timestamp: Date().addingTimeInterval(-3600),
                isRead: false,
                priority: .high,
                actionData: ["goal_id": "steps_daily"]
            ),
            HealthNotification(
                type: .healthAlert,
                title: "Resting Heart Rate Anomaly Detected",
                message: "Your resting heart rate has been elevated for the past 3 days. Consider consulting your healthcare provider.",
                timestamp: Date().addingTimeInterval(-7200),
                isRead: true,
                priority: .high,
                actionData: ["metric": "heart_rate", "period": "3_days"]
            ),
            HealthNotification(
                type: .syncUpdate,
                title: "Data Sync Complete",
                message: "Successfully synced 234 new data points from MyFitnessPal and Apple Health.",
                timestamp: Date().addingTimeInterval(-10800),
                isRead: true,
                priority: .low,
                actionData: ["sync_id": "sync_20240101_001"]
            ),
            HealthNotification(
                type: .insight,
                title: "Weekly Activity Summary",
                message: "You were most active on Tuesday with 12,456 steps. Your average this week was 9,234 steps.",
                timestamp: Date().addingTimeInterval(-86400),
                isRead: false,
                priority: .medium,
                actionData: ["view": "weekly_summary"]
            ),
            HealthNotification(
                type: .goalReminder,
                title: "Hydration Reminder",
                message: "You're 2 glasses behind your daily water goal. Stay hydrated!",
                timestamp: Date().addingTimeInterval(-172800),
                isRead: true,
                priority: .medium,
                actionData: ["goal_id": "hydration_daily"]
            )
        ]
    }
    
    private func createMockSettings() -> NotificationSettings {
        return NotificationSettings(
            insightsEnabled: true,
            goalsEnabled: true,
            alertsEnabled: true,
            syncEnabled: false,
            quietHoursEnabled: true,
            quietStartTime: Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date(),
            quietEndTime: Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? Date(),
            priorityFilter: .medium
        )
    }
}

// MARK: - Supporting Views

struct FilterChip: View {
    let filter: NotificationCenterView.NotificationFilter
    let isSelected: Bool
    let count: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.caption)
                
                Text(filter.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color(.systemGray5))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct NotificationRow: View {
    let notification: HealthNotification
    let onTap: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Notification Icon
                Image(systemName: notification.type.icon)
                    .foregroundColor(notification.type.color)
                    .font(.title3)
                    .frame(width: 24)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.subheadline)
                            .fontWeight(notification.isRead ? .regular : .semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(notification.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(notification.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Priority and Read Status
                    HStack {
                        if notification.priority == .high {
                            HStack(spacing: 2) {
                                Image(systemName: "exclamationmark")
                                    .font(.caption2)
                                Text("High Priority")
                                    .font(.caption2)
                            }
                            .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        if !notification.isRead {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                
                // Dismiss Button
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Dismiss", role: .destructive) {
                onDismiss()
            }
        }
    }
}

// MARK: - Data Models

struct HealthNotification: Identifiable {
    let id = UUID()
    let type: NotificationType
    let title: String
    let message: String
    let timestamp: Date
    var isRead: Bool
    let priority: NotificationPriority
    let actionData: [String: String]
}

enum NotificationType: String, CaseIterable {
    case insight = "Insight"
    case goalAchievement = "Goal Achievement"
    case goalReminder = "Goal Reminder"
    case healthAlert = "Health Alert"
    case syncUpdate = "Sync Update"
    
    var displayName: String { rawValue }
    
    var icon: String {
        switch self {
        case .insight: return "lightbulb.fill"
        case .goalAchievement: return "trophy.fill"
        case .goalReminder: return "target"
        case .healthAlert: return "exclamationmark.triangle.fill"
        case .syncUpdate: return "arrow.triangle.2.circlepath"
        }
    }
    
    var color: Color {
        switch self {
        case .insight: return .yellow
        case .goalAchievement: return .green
        case .goalReminder: return .blue
        case .healthAlert: return .red
        case .syncUpdate: return .purple
        }
    }
}



// MARK: - Preview

struct NotificationCenterView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationCenterView()
    }
} 