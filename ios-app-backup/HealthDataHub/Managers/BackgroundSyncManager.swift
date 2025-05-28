import Foundation
import BackgroundTasks
import HealthKit
import Combine

@MainActor
class BackgroundSyncManager: ObservableObject {
    private let backgroundTaskIdentifier = "com.healthdatahub.app.healthsync"
    private let healthKitManager: HealthKitManager?
    
    @Published var lastBackgroundSync: Date?
    @Published var backgroundSyncStatus: BackgroundSyncStatus = .idle
    @Published var syncProgress: Double = 0.0
    @Published var errorMessage: String?
    
    enum BackgroundSyncStatus {
        case idle
        case syncing
        case success
        case error(String)
    }
    
    // MARK: - Initialization
    
    init(healthKitManager: HealthKitManager? = nil) {
        self.healthKitManager = healthKitManager
    }
    
    // MARK: - Background Task Registration
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundTaskIdentifier, using: nil) { task in
            self.handleBackgroundSync(task: task as! BGAppRefreshTask)
        }
        
        print("Background task registered: \(backgroundTaskIdentifier)")
    }
    
    // MARK: - Background Sync Scheduling
    
    func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes from now
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background sync scheduled successfully")
        } catch {
            print("Failed to schedule background sync: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Background Sync Handler
    
    private func handleBackgroundSync(task: BGAppRefreshTask) {
        print("Background sync task started")
        
        // Set expiration handler
        task.expirationHandler = {
            print("Background sync task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Perform sync
        Task {
            await performBackgroundSync { success in
                print("Background sync completed with success: \(success)")
                task.setTaskCompleted(success: success)
                
                // Schedule next background sync
                self.scheduleBackgroundSync()
            }
        }
    }
    
    // MARK: - Data Synchronization
    
    func performBackgroundSync(completion: @escaping (Bool) -> Void) async {
        await MainActor.run {
            backgroundSyncStatus = .syncing
            syncProgress = 0.0
            errorMessage = nil
        }
        
        do {
            // Step 1: Read HealthKit data (25% progress)
            await updateProgress(0.25)
            let healthData = await readHealthKitData()
            
            // Step 2: Process and map data (50% progress)
            await updateProgress(0.50)
            let mappedData = processHealthData(healthData)
            
            // Step 3: Sync with backend API (75% progress)
            await updateProgress(0.75)
            let syncSuccess = await syncWithBackend(mappedData)
            
            // Step 4: Complete (100% progress)
            await updateProgress(1.0)
            
            await MainActor.run {
                if syncSuccess {
                    backgroundSyncStatus = .success
                    lastBackgroundSync = Date()
                } else {
                    backgroundSyncStatus = .error("Sync failed")
                    errorMessage = "Failed to sync with backend"
                }
            }
            
            completion(syncSuccess)
            
        } catch {
            await MainActor.run {
                backgroundSyncStatus = .error(error.localizedDescription)
                errorMessage = error.localizedDescription
            }
            completion(false)
        }
    }
    
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            syncProgress = progress
        }
    }
    
    // MARK: - HealthKit Data Reading
    
    private func readHealthKitData() async -> [HKSample] {
        return await withCheckedContinuation { continuation in
            var allSamples: [HKSample] = []
            let group = DispatchGroup()
            
            // Read step count
            group.enter()
            healthKitManager?.readStepCount { samples in
                allSamples.append(contentsOf: samples)
                group.leave()
            }
            
            // Read heart rate
            group.enter()
            healthKitManager?.readHeartRate { samples in
                allSamples.append(contentsOf: samples)
                group.leave()
            }
            
            // Read workouts
            group.enter()
            healthKitManager?.readWorkouts { workouts in
                allSamples.append(contentsOf: workouts)
                group.leave()
            }
            
            // Read nutrition data
            group.enter()
            healthKitManager?.readNutritionData { samples in
                allSamples.append(contentsOf: samples)
                group.leave()
            }
            
            // Read sleep data
            group.enter()
            healthKitManager?.readSleepData { samples in
                allSamples.append(contentsOf: samples)
                group.leave()
            }
            
            group.notify(queue: .main) {
                continuation.resume(returning: allSamples)
            }
        }
    }
    
    // MARK: - Data Processing
    
    private func processHealthData(_ samples: [HKSample]) -> [[String: Any]] {
        let mappedMetrics = HealthDataMapper.mapSamplesToUnifiedSchema(samples: samples)
        return HealthDataMapper.serializeForAPI(metrics: mappedMetrics)
    }
    
    // MARK: - Backend API Sync
    
    private func syncWithBackend(_ data: [[String: Any]]) async -> Bool {
        guard !data.isEmpty else {
            print("No data to sync")
            return true
        }
        
        // Check if user is authenticated
        guard NetworkManager.shared.isAuthenticated else {
            print("User not authenticated, skipping sync")
            return false
        }
        
        do {
            // Convert data to HealthMetricUnified format
            let metrics = data.compactMap { dict -> HealthDataMapper.HealthMetricUnified? in
                guard let metricType = dict["metric_type"] as? String,
                      let value = dict["value"] as? Double,
                      let unit = dict["unit"] as? String,
                      let sourceType = dict["source_type"] as? String,
                      let recordedAtString = dict["recorded_at"] as? String,
                      let recordedAt = ISO8601DateFormatter().date(from: recordedAtString) else {
                    return nil
                }
                
                return HealthDataMapper.HealthMetricUnified(
                    metricType: metricType,
                    value: value,
                    unit: unit,
                    sourceType: sourceType,
                    recordedAt: recordedAt,
                    sourceApp: dict["source_app"] as? String,
                    deviceName: dict["device_name"] as? String,
                    metadata: dict["metadata"] as? [String: Any]
                )
            }
            
            // Upload to backend
            let response = try await NetworkManager.shared.uploadHealthKitData(metrics)
            
            print("Successfully synced \(response.processed_count) health metrics")
            print("Sync ID: \(response.sync_id)")
            
            if response.failed_count > 0 {
                print("Failed to sync \(response.failed_count) metrics")
                if let errors = response.errors {
                    print("Errors: \(errors)")
                }
            }
            
            return response.failed_count == 0
            
        } catch {
            print("Backend sync failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Manual Sync
    
    func performManualSync() {
        Task {
            await performBackgroundSync { success in
                print("Manual sync completed: \(success)")
            }
        }
    }
    
    // MARK: - Sync Status Management
    
    func resetSyncStatus() {
        backgroundSyncStatus = .idle
        syncProgress = 0.0
        errorMessage = nil
    }
    
    // MARK: - Network Connectivity
    
    private func isNetworkAvailable() -> Bool {
        // In a real implementation, you would check network reachability
        // For now, we'll assume network is available
        return true
    }
    
    // MARK: - Data Conflict Resolution
    
    private func resolveDataConflicts(_ newData: [[String: Any]], existingData: [[String: Any]]) -> [[String: Any]] {
        // Implement conflict resolution logic
        // For now, we'll prefer newer data
        var resolvedData = existingData
        
        for newItem in newData {
            if let newTimestamp = newItem["recorded_at"] as? String,
               let newDate = ISO8601DateFormatter().date(from: newTimestamp) {
                
                // Check if we have existing data for the same metric type and time
                let existingIndex = resolvedData.firstIndex { existingItem in
                    guard let existingTimestamp = existingItem["recorded_at"] as? String,
                          let existingDate = ISO8601DateFormatter().date(from: existingTimestamp),
                          let existingMetricType = existingItem["metric_type"] as? String,
                          let newMetricType = newItem["metric_type"] as? String else {
                        return false
                    }
                    
                    return existingMetricType == newMetricType &&
                           abs(existingDate.timeIntervalSince(newDate)) < 60 // Within 1 minute
                }
                
                if let index = existingIndex {
                    // Replace with newer data
                    resolvedData[index] = newItem
                } else {
                    // Add new data
                    resolvedData.append(newItem)
                }
            }
        }
        
        return resolvedData
    }
    
    // MARK: - Incremental Sync
    
    private func getLastSyncTimestamp() -> Date? {
        return UserDefaults.standard.object(forKey: "lastHealthKitSync") as? Date
    }
    
    private func setLastSyncTimestamp(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "lastHealthKitSync")
    }
    
    private func filterDataSinceLastSync(_ data: [[String: Any]]) -> [[String: Any]] {
        guard let lastSync = getLastSyncTimestamp() else {
            // First sync, return all data
            return data
        }
        
        return data.filter { item in
            guard let timestampString = item["recorded_at"] as? String,
                  let timestamp = ISO8601DateFormatter().date(from: timestampString) else {
                return false
            }
            
            return timestamp > lastSync
        }
    }
    
    // MARK: - Error Handling
    
    private func handleSyncError(_ error: Error) {
        print("Sync error: \(error.localizedDescription)")
        
        DispatchQueue.main.async {
            self.backgroundSyncStatus = .error(error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Utility Methods
    
    func getSyncStatusDescription() -> String {
        switch backgroundSyncStatus {
        case .idle:
            return "Ready to sync"
        case .syncing:
            return "Syncing... \(Int(syncProgress * 100))%"
        case .success:
            if let lastSync = lastBackgroundSync {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                return "Last synced: \(formatter.string(from: lastSync))"
            } else {
                return "Sync completed"
            }
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    func canPerformSync() -> Bool {
        return backgroundSyncStatus != .syncing && isNetworkAvailable()
    }
} 