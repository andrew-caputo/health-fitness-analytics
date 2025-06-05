import SwiftUI
import HealthKit

struct AppPermissionsView: View {
    @StateObject private var viewModel = AppPermissionsViewModel()
    @EnvironmentObject var healthDataManager: HealthDataManager
    @Environment(\.dismiss) private var dismiss
    @State private var permissionGroups: [PermissionGroup] = []
    @State private var isLoading = true
    @State private var showingHealthApp = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    loadingView
                } else {
                    permissionsContent
                }
            }
            .navigationTitle("HealthKit Permissions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("Refresh") {
                            loadPermissions()
                        }
                        
                        Button("Health App") {
                            showingHealthApp = true
                        }
                    }
                }
            }
            .onAppear {
                loadPermissions()
            }
            .alert("Open Health App", isPresented: $showingHealthApp) {
                Button("Open") {
                    healthDataManager.openHealthApp()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("To modify HealthKit permissions, you need to use the Health app. Would you like to open it now?")
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading Permissions...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var permissionsContent: some View {
        List {
            // Overview Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        VStack(alignment: .leading) {
                            Text("HealthKit Permissions")
                                .font(.headline)
                            Text("Manage what health data this app can access")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack {
                            Text("\(enabledPermissionsCount)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Text("Enabled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Quick stats
                    HStack(spacing: 20) {
                        PermissionStat(
                            title: "Total Types",
                            value: "\(totalPermissionsCount)",
                            color: .blue
                        )
                        
                        PermissionStat(
                            title: "Denied",
                            value: "\(deniedPermissionsCount)",
                            color: .red
                        )
                        
                        PermissionStat(
                            title: "Not Set",
                            value: "\(notSetPermissionsCount)",
                            color: .orange
                        )
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Permission Groups
            ForEach(permissionGroups) { group in
                Section {
                    ForEach(group.permissions) { permission in
                        PermissionRow(permission: permission)
                    }
                } header: {
                    HStack {
                        Image(systemName: group.icon)
                            .foregroundColor(group.color)
                        Text(group.name)
                        Spacer()
                        Text("\(group.enabledCount)/\(group.permissions.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } footer: {
                    if !group.description.isEmpty {
                        Text(group.description)
                            .font(.caption)
                    }
                }
            }
            
            // Actions Section
            Section {
                Button(action: {
                    healthDataManager.requestHealthKitPermissions()
                    
                    // Refresh permission display after request
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        loadPermissions()
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("Request All Permissions")
                        Spacer()
                    }
                }
                
                Button(action: {
                    showingHealthApp = true
                }) {
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(.gray)
                        Text("Manage in Health App")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } footer: {
                Text("HealthKit permissions can only be modified through the Health app. This view shows the current status of permissions.")
                    .font(.caption)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    private var enabledPermissionsCount: Int {
        permissionGroups.flatMap { $0.permissions }.filter { $0.status == .sharingAuthorized }.count
    }
    
    private var deniedPermissionsCount: Int {
        permissionGroups.flatMap { $0.permissions }.filter { $0.status == .sharingDenied }.count
    }
    
    private var notSetPermissionsCount: Int {
        permissionGroups.flatMap { $0.permissions }.filter { $0.status == .notDetermined }.count
    }
    
    private var totalPermissionsCount: Int {
        permissionGroups.flatMap { $0.permissions }.count
    }
    
    private func loadPermissions() {
        Task {
            await MainActor.run {
                permissionGroups = createPermissionGroups()
                isLoading = false
            }
        }
    }
    
    private func createPermissionGroups() -> [PermissionGroup] {
        return [
            PermissionGroup(
                name: "Activity & Fitness",
                icon: "figure.walk",
                color: .green,
                description: "Steps, workouts, active energy, and exercise data",
                permissions: [
                    HealthPermission(
                        name: "Steps",
                        type: HKQuantityType.quantityType(forIdentifier: .stepCount)!,
                        status: healthDataManager.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .stepCount)!)
                    ),
                    HealthPermission(
                        name: "Distance Walking/Running",
                        type: HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
                        status: healthDataManager.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!)
                    ),
                    HealthPermission(
                        name: "Active Energy",
                        type: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
                        status: healthDataManager.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!)
                    ),
                    HealthPermission(
                        name: "Exercise Time",
                        type: HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!,
                        status: healthDataManager.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .appleExerciseTime)!)
                    ),
                    HealthPermission(
                        name: "Workouts",
                        type: HKWorkoutType.workoutType(),
                        status: healthDataManager.authorizationStatus(for: HKWorkoutType.workoutType())
                    )
                ]
            ),
            
            PermissionGroup(
                name: "Body Measurements",
                icon: "figure.arms.open",
                color: .pink,
                description: "Weight, height, BMI, and body composition data",
                permissions: [
                    HealthPermission(
                        name: "Weight",
                        type: HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
                        status: healthDataManager.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .bodyMass)!)
                    ),
                    HealthPermission(
                        name: "Height",
                        type: HKQuantityType.quantityType(forIdentifier: .height)!,
                        status: healthDataManager.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .height)!)
                    ),
                    HealthPermission(
                        name: "Body Mass Index",
                        type: HKQuantityType.quantityType(forIdentifier: .bodyMassIndex)!,
                        status: healthDataManager.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .bodyMassIndex)!)
                    ),
                    HealthPermission(
                        name: "Body Fat Percentage",
                        type: HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!,
                        status: healthDataManager.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!)
                    )
                ]
            ),
            
            PermissionGroup(
                name: "Heart Health",
                icon: "heart.fill",
                color: .red,
                description: "Heart rate, HRV, and cardiovascular data",
                permissions: [
                    HealthPermission(
                        name: "Heart Rate",
                        type: HKQuantityType.quantityType(forIdentifier: .heartRate)!,
                        status: healthDataManager.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .heartRate)!)
                    ),
                    HealthPermission(
                        name: "Heart Rate Variability",
                        type: HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
                        status: healthDataManager.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!)
                    ),
                    HealthPermission(
                        name: "Resting Heart Rate",
                        type: HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
                        status: healthDataManager.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!)
                    )
                ]
            ),
            
            PermissionGroup(
                name: "Nutrition",
                icon: "fork.knife",
                color: .orange,
                description: "Dietary intake, calories, and nutrition data",
                permissions: [
                    HealthPermission(
                        name: "Dietary Energy",
                        type: HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
                        status: healthDataManager.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)!)
                    ),
                    HealthPermission(
                        name: "Carbohydrates",
                        type: HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
                        status: healthDataManager.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates)!)
                    ),
                    HealthPermission(
                        name: "Protein",
                        type: HKQuantityType.quantityType(forIdentifier: .dietaryProtein)!,
                        status: healthDataManager.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .dietaryProtein)!)
                    ),
                    HealthPermission(
                        name: "Total Fat",
                        type: HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal)!,
                        status: healthDataManager.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal)!)
                    ),
                    HealthPermission(
                        name: "Water",
                        type: HKQuantityType.quantityType(forIdentifier: .dietaryWater)!,
                        status: healthDataManager.authorizationStatus(for: HKQuantityType.quantityType(forIdentifier: .dietaryWater)!)
                    )
                ]
            ),
            
            PermissionGroup(
                name: "Sleep",
                icon: "bed.double.fill",
                color: .purple,
                description: "Sleep analysis and sleep stage data",
                permissions: [
                    HealthPermission(
                        name: "Sleep Analysis",
                        type: HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
                        status: healthDataManager.authorizationStatus(for: HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!)
                    )
                ]
            ),
            
            PermissionGroup(
                name: "Mindfulness",
                icon: "brain.head.profile",
                color: .indigo,
                description: "Meditation and mindfulness session data",
                permissions: [
                    HealthPermission(
                        name: "Mindful Session",
                        type: HKCategoryType.categoryType(forIdentifier: .mindfulSession)!,
                        status: healthDataManager.authorizationStatus(for: HKCategoryType.categoryType(forIdentifier: .mindfulSession)!)
                    )
                ]
            )
        ]
    }
}

// MARK: - Permission Stat Component

struct PermissionStat: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Permission Row Component

struct PermissionRow: View {
    let permission: HealthPermission
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(permission.statusColor)
                .frame(width: 12, height: 12)
            
            // Permission info
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(permission.statusDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status icon
            Image(systemName: permission.statusIcon)
                .foregroundColor(permission.statusColor)
                .font(.caption)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Data Models

struct PermissionGroup: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let description: String
    let permissions: [HealthPermission]
    
    var enabledCount: Int {
        permissions.filter { $0.status == .sharingAuthorized }.count
    }
}

struct HealthPermission: Identifiable {
    let id = UUID()
    let name: String
    let type: HKObjectType
    let status: HKAuthorizationStatus
    
    var statusColor: Color {
        switch status {
        case .sharingAuthorized:
            return .green
        case .sharingDenied:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
    
    var statusIcon: String {
        switch status {
        case .sharingAuthorized:
            return "checkmark.circle.fill"
        case .sharingDenied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "circle"
        }
    }
    
    var statusDescription: String {
        switch status {
        case .sharingAuthorized:
            return "Authorized"
        case .sharingDenied:
            return "Denied"
        case .notDetermined:
            return "Not Set"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - HealthDataManager Extension

extension HealthDataManager {
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        return healthStore.authorizationStatus(for: type)
    }
}

// MARK: - Preview

#Preview {
    AppPermissionsView()
        .environmentObject(HealthDataManager.shared)
} 