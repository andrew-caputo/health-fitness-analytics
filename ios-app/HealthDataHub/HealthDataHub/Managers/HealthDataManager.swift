import Foundation
import HealthKit
import UIKit
import Combine
import os.log

@MainActor
class HealthDataManager: ObservableObject {
    // Singleton instance
    static let shared = HealthDataManager()
    
    // HealthKit store
    internal let healthStore = HKHealthStore()
    
    // Network manager for backend data sources
    private let networkManager = NetworkManager.shared
    
    // Unified logging
    private let logger = Logger(subsystem: "com.healthdatahub.app", category: "HealthDataManager")
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var connectedApps: [String] = []
    @Published var detailedConnectedApps: [ConnectedHealthApp] = []
    @Published var lastSyncDate: Date?
    @Published var syncStatus: SyncStatus = .idle
    
    // Authorization state management
    private var lastAuthorizationCheck: Date?
    private var authorizationCheckCooldown: TimeInterval = 3.0 // 3 seconds between checks
    private var pendingAuthorizationUpdate: Bool = false
    
    // User preferences
    @Published var userPreferences: UserDataSourcePreferences?
    
    // Real Health Data
    @Published var todaySteps: Int = 0
    @Published var todayActiveCalories: Int = 0
    @Published var currentHeartRate: Int = 0
    @Published var currentWeight: Double = 0.0 // in pounds
    @Published var lastNightSleep: TimeInterval = 0 // in seconds
    @Published var todayNutritionCalories: Int = 0
    
    enum SyncStatus {
        case idle
        case syncing
        case success
        case error(String)
    }
    
    // MARK: - Health Data Types
    
    private let healthDataTypesToRead: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        
        // Activity & Fitness
        if let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepCount)
        }
        if let distanceWalkingRunning = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distanceWalkingRunning)
        }
        if let activeEnergyBurned = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergyBurned)
        }
        if let exerciseTime = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exerciseTime)
        }
        types.insert(HKWorkoutType.workoutType())
        
        // Body Measurements
        if let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        if let height = HKQuantityType.quantityType(forIdentifier: .height) {
            types.insert(height)
        }
        if let bodyMassIndex = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) {
            types.insert(bodyMassIndex)
        }
        if let bodyFatPercentage = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.insert(bodyFatPercentage)
        }
        
        // Heart Health
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let heartRateVariability = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(heartRateVariability)
        }
        if let restingHeartRate = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHeartRate)
        }
        
        // Nutrition
        if let dietaryEnergyConsumed = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            types.insert(dietaryEnergyConsumed)
        }
        if let dietaryCarbohydrates = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            types.insert(dietaryCarbohydrates)
        }
        if let dietaryProtein = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            types.insert(dietaryProtein)
        }
        if let dietaryFatTotal = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) {
            types.insert(dietaryFatTotal)
        }
        if let dietaryFiber = HKQuantityType.quantityType(forIdentifier: .dietaryFiber) {
            types.insert(dietaryFiber)
        }
        if let dietarySugar = HKQuantityType.quantityType(forIdentifier: .dietarySugar) {
            types.insert(dietarySugar)
        }
        
        // Sleep
        if let sleepAnalysis = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepAnalysis)
        }
        
        // Mindfulness
        if let mindfulSession = HKCategoryType.categoryType(forIdentifier: .mindfulSession) {
            types.insert(mindfulSession)
        }
        
        return types
    }()
    
    // MARK: - Initialization
    
    private init() {
        checkHealthKitAvailability()
        print("🚀 HealthDataManager initialized - delaying authorization check for proper timing...")
        // Don't check permissions immediately - iOS needs time to process grants
        // Permissions will be checked when actually needed or explicitly requested
    }
    
    // MARK: - HealthKit Availability
    
    private func checkHealthKitAvailability() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device")
            return
        }
    }
    
    // MARK: - Authorization
    
    func requestHealthKitPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available")
            return
        }
        
        healthStore.requestAuthorization(toShare: nil, read: healthDataTypesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ HealthKit authorization request completed successfully")
                    // Use delayed checking to allow iOS to process the grants
                    self?.checkAuthorizationStatusWithRetry(delay: 2.0)
                    self?.startObservingHealthData()
                } else {
                    print("❌ HealthKit authorization request failed: \(error?.localizedDescription ?? "Unknown error")")
                    // Still check what permissions we might have gotten
                    self?.checkAuthorizationStatusWithRetry(delay: 1.0)
                }
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        // Keep old method for compatibility but redirect to enhanced version
        checkOverallAuthorizationStatus()
    }
    
    // MARK: - Enhanced Authorization Checking
    
    func refreshAuthorizationStatus() {
        checkOverallAuthorizationStatus()
    }
    
    func checkAuthorizationStatusWithRetry(delay: TimeInterval = 1.0) {
        print("⏰ Scheduling permission check with \(delay)s delay for iOS to process grants...")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.checkOverallAuthorizationStatus()
        }
    }
    
    private func checkOverallAuthorizationStatus() {
        print("🔍 Checking HealthKit authorization via data capability test...")
        
        // Use data-based detection instead of unreliable permission API on real devices
        testDataAccessCapability()
    }
    
    private func testDataAccessCapability() {
        print("🧪 Testing actual HealthKit data access capability...")
        
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available on this device")
            updateAuthorizationStatus(isAuthorized: false)
            return
        }
        
        // Test reading basic data types that are commonly granted
        let testGroup = DispatchGroup()
        var successfulReads = 0
        let totalTests = 3
        
        // Test Steps (most commonly granted)
        testGroup.enter()
        testReadSteps { success in
            if success { 
                successfulReads += 1
                print("✅ Steps data access: SUCCESS")
            } else {
                print("❌ Steps data access: FAILED")
            }
            testGroup.leave()
        }
        
        // Test Heart Rate
        testGroup.enter()
        testReadHeartRate { success in
            if success { 
                successfulReads += 1
                print("✅ Heart Rate data access: SUCCESS")
            } else {
                print("❌ Heart Rate data access: FAILED")
            }
            testGroup.leave()
        }
        
        // Test Sleep
        testGroup.enter()
        testReadSleep { success in
            if success { 
                successfulReads += 1
                print("✅ Sleep data access: SUCCESS")
            } else {
                print("❌ Sleep data access: FAILED")
            }
            testGroup.leave()
        }
        
        testGroup.notify(queue: .main) {
            let hasDataAccess = successfulReads >= 1 // At least one successful read indicates authorization
            print("📊 Data Access Test Results:")
            print("   ✅ Successful reads: \(successfulReads)/\(totalTests)")
            print("   🎯 Data Access Capability: \(hasDataAccess ? "AVAILABLE" : "NOT AVAILABLE")")
            
            self.updateAuthorizationStatus(isAuthorized: hasDataAccess)
        }
    }
    
    // MARK: - Data Access Test Methods
    
    private func testReadSteps(completion: @escaping (Bool) -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(false)
            return
        }
        
        let now = Date()
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now
        let predicate = HKQuery.predicateForSamples(withStart: oneHourAgo, end: now, options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: stepType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: nil
        ) { _, samples, error in
            DispatchQueue.main.async {
                completion(error == nil) // Success if no error, regardless of data presence
            }
        }
        
        healthStore.execute(query)
    }
    
    private func testReadHeartRate(completion: @escaping (Bool) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(false)
            return
        }
        
        let now = Date()
        let oneHourAgo = Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now
        let predicate = HKQuery.predicateForSamples(withStart: oneHourAgo, end: now, options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: nil
        ) { _, samples, error in
            DispatchQueue.main.async {
                completion(error == nil) // Success if no error, regardless of data presence
            }
        }
        
        healthStore.execute(query)
    }
    
    private func testReadSleep(completion: @escaping (Bool) -> Void) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(false)
            return
        }
        
        let now = Date()
        let oneDayAgo = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        let predicate = HKQuery.predicateForSamples(withStart: oneDayAgo, end: now, options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: predicate,
            limit: 1,
            sortDescriptors: nil
        ) { _, samples, error in
            DispatchQueue.main.async {
                completion(error == nil) // Success if no error, regardless of data presence
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Permission Helper Methods
    
    private func getCoreHealthDataTypes() -> [HKObjectType] {
        var types: [HKObjectType] = []
        
        // Core activity data
        if let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.append(stepCount)
        }
        if let activeCalories = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.append(activeCalories)
        }
        
        // Core health metrics
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.append(heartRate)
        }
        if let bodyMass = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.append(bodyMass)
        }
        
        // Sleep data
        if let sleepAnalysis = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.append(sleepAnalysis)
        }
        
        // Workouts
        types.append(HKWorkoutType.workoutType())
        
        return types
    }
    
    private func getHealthTypeDisplayName(_ type: HKObjectType) -> String {
        switch type {
        case HKQuantityType.quantityType(forIdentifier: .stepCount):
            return "Steps"
        case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
            return "Active Calories"
        case HKQuantityType.quantityType(forIdentifier: .heartRate):
            return "Heart Rate"
        case HKQuantityType.quantityType(forIdentifier: .bodyMass):
            return "Weight"
        case HKCategoryType.categoryType(forIdentifier: .sleepAnalysis):
            return "Sleep"
        case HKWorkoutType.workoutType():
            return "Workouts"
        default:
            return "Unknown"
        }
    }
    
    private func getStatusDisplayName(_ status: HKAuthorizationStatus) -> String {
        switch status {
        case .sharingAuthorized:
            return "✅ Authorized"
        case .sharingDenied:
            return "❌ Denied"
        case .notDetermined:
            return "⏳ Not Determined"
        @unknown default:
            return "❓ Unknown"
        }
    }
    
    func hasRequiredPermissions() -> Bool {
        // Return current authorization status based on recent data access capability test
        // This is more reliable than checking permission API on real devices
        return isAuthorized
    }
    
    func getPermissionStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        return healthStore.authorizationStatus(for: type)
    }
    
    private func updateAuthorizationStatus(isAuthorized: Bool) {
        // Prevent rapid authorization status switching
        guard !pendingAuthorizationUpdate else {
            print("⏸️ Authorization update already pending, skipping...")
            return
        }
        
        // Check cooldown period
        if let lastCheck = lastAuthorizationCheck {
            let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
            if timeSinceLastCheck < authorizationCheckCooldown {
                print("⏸️ Authorization check cooldown active (\(String(format: "%.1f", timeSinceLastCheck))s ago), skipping...")
                return
            }
        }
        
        // Only update if status actually changed
        guard self.isAuthorized != isAuthorized else {
            print("📱 Authorization status unchanged: \(isAuthorized ? "Connected" : "Not Connected")")
            return
        }
        
        print("📱 Updating HealthKit authorization status: \(isAuthorized ? "Connected" : "Not Connected")")
        
        pendingAuthorizationUpdate = true
        lastAuthorizationCheck = Date()
        
        // Debounce the update slightly to allow for any competing updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isAuthorized = isAuthorized
            if isAuthorized {
                self?.authorizationStatus = .sharingAuthorized
            } else {
                self?.authorizationStatus = .notDetermined
            }
            self?.pendingAuthorizationUpdate = false
            print("✅ Authorization status update completed: \(isAuthorized ? "Connected" : "Not Connected")")
        }
    }
    
    // MARK: - Data Reading
    
    func readStepCount(completion: @escaping ([HKQuantitySample]) -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion([])
            return
        }
        
        let query = HKSampleQuery(
            sampleType: stepType,
            predicate: nil,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            if let error = error {
                print("Error reading step count: \(error.localizedDescription)")
                completion([])
                return
            }
            
            let stepSamples = samples as? [HKQuantitySample] ?? []
            completion(stepSamples)
        }
        
        healthStore.execute(query)
    }
    
    func readHeartRate(completion: @escaping ([HKQuantitySample]) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion([])
            return
        }
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            if let error = error {
                print("Error reading heart rate: \(error.localizedDescription)")
                completion([])
                return
            }
            
            let heartRateSamples = samples as? [HKQuantitySample] ?? []
            completion(heartRateSamples)
        }
        
        healthStore.execute(query)
    }
    
    func readWorkouts(completion: @escaping ([HKWorkout]) -> Void) {
        let workoutType = HKWorkoutType.workoutType()
        
        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: nil,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            if let error = error {
                print("Error reading workouts: \(error.localizedDescription)")
                completion([])
                return
            }
            
            let workouts = samples as? [HKWorkout] ?? []
            completion(workouts)
        }
        
        healthStore.execute(query)
    }
    
    func readNutritionData(completion: @escaping ([HKQuantitySample]) -> Void) {
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            completion([])
            return
        }
        
        let query = HKSampleQuery(
            sampleType: caloriesType,
            predicate: nil,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            if let error = error {
                print("Error reading nutrition data: \(error.localizedDescription)")
                completion([])
                return
            }
            
            let nutritionSamples = samples as? [HKQuantitySample] ?? []
            completion(nutritionSamples)
        }
        
        healthStore.execute(query)
    }
    
    func readSleepData(completion: @escaping ([HKCategorySample]) -> Void) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion([])
            return
        }
        
        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: nil,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            if let error = error {
                print("Error reading sleep data: \(error.localizedDescription)")
                completion([])
                return
            }
            
            let sleepSamples = samples as? [HKCategorySample] ?? []
            completion(sleepSamples)
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Observer Queries
    
    private func startObservingHealthData() {
        // Observe step count changes
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            startObserving(type: stepType)
        }
        
        // Observe heart rate changes
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            startObserving(type: heartRateType)
        }
        
        // Observe workout changes
        startObserving(type: HKWorkoutType.workoutType())
        
        // Observe nutrition changes
        if let caloriesType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            startObserving(type: caloriesType)
        }
        
        // Observe sleep changes
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            startObserving(type: sleepType)
        }
    }
    
    private func startObserving(type: HKSampleType) {
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completionHandler, error in
            if let error = error {
                print("Observer query error for \(type.identifier): \(error.localizedDescription)")
                completionHandler()
                return
            }
            
            DispatchQueue.main.async {
                self?.syncLatestData()
            }
            
            completionHandler()
        }
        
        healthStore.execute(query)
        
        // Enable background delivery
        healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { success, error in
            if let error = error {
                print("Background delivery error for \(type.identifier): \(error.localizedDescription)")
            } else if success {
                print("Background delivery enabled for \(type.identifier)")
            }
        }
    }
    
    // MARK: - Data Sync
    
    func syncLatestData() {
        print("🔄 === SYNC LATEST DATA STARTED ===")
        logger.info("🔄 === SYNC LATEST DATA STARTED ===")
        syncStatus = .syncing
        
        Task {
            await loadUserPreferences()
            await readHealthDataBasedOnPreferences()
        }
    }
    
    private func loadUserPreferences() async {
        print("📋 Loading user preferences...")
        logger.info("📋 Loading user preferences...")
        do {
            let response = try await networkManager.getUserDataSourcePreferences()
            self.userPreferences = response.preferences
            print("✅ User preferences loaded: \(String(describing: self.userPreferences))")
            logger.info("✅ User preferences loaded: \(String(describing: self.userPreferences))")
        } catch {
            print("❌ Failed to load user preferences: \(error)")
            logger.error("❌ Failed to load user preferences: \(error.localizedDescription)")
            // Fall back to default preferences (Apple Health for all)
            self.userPreferences = UserDataSourcePreferences(
                activity_source: "apple_health",
                sleep_source: "apple_health", 
                nutrition_source: "apple_health",
                body_composition_source: "apple_health",
                heart_health_source: "apple_health"
            )
            print("📋 Using fallback preferences: apple_health for all categories")
            logger.info("📋 Using fallback preferences: apple_health for all categories")
        }
    }
    
    @MainActor
    private func readHealthDataBasedOnPreferences() async {
        print("📊 === READING HEALTH DATA BASED ON PREFERENCES ===")
        guard let preferences = userPreferences else { 
            print("❌ No preferences available, aborting data read")
            return 
        }
        
        print("📊 Current data before sync - Steps: \(todaySteps), Calories: \(todayActiveCalories), HR: \(currentHeartRate), Sleep: \(lastNightSleep)")
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        print("📅 Date ranges - Today: \(today) to \(tomorrow), Yesterday: \(yesterday) to \(today)")
        
        await withTaskGroup(of: Void.self) { group in
            // Read activity data from preferred source
            group.addTask {
                let activitySource = preferences.activity_source ?? "apple_health"
                print("🏃 Starting activity data read from: \(activitySource)")
                await self.readActivityData(from: activitySource, 
                                          startDate: today, endDate: tomorrow)
            }
            
            // Read sleep data from preferred source
            group.addTask {
                let sleepSource = preferences.sleep_source ?? "apple_health"
                print("😴 Starting sleep data read from: \(sleepSource)")
                await self.readSleepData(from: sleepSource,
                                       startDate: yesterday, endDate: today)
            }
            
            // Read nutrition data from preferred source
            group.addTask {
                let nutritionSource = preferences.nutrition_source ?? "apple_health"
                print("🍎 Starting nutrition data read from: \(nutritionSource)")
                await self.readNutritionData(from: nutritionSource,
                                           startDate: today, endDate: tomorrow)
            }
            
            // Read body composition data from preferred source
            group.addTask {
                let bodySource = preferences.body_composition_source ?? "apple_health"
                print("⚖️ Starting body composition data read from: \(bodySource)")
                await self.readBodyCompositionData(from: bodySource,
                                                 startDate: today, endDate: tomorrow)
            }
            
            // Read heart rate data from preferred heart rate source (defaults to activity source)
            group.addTask {
                let heartSource = preferences.heart_health_source ?? preferences.activity_source ?? "apple_health"
                print("❤️ Starting heart rate data read from: \(heartSource)")
                await self.readHeartRateData(from: heartSource,
                                           startDate: today, endDate: tomorrow)
            }
        }
        
        print("📊 Data after sync - Steps: \(todaySteps), Calories: \(todayActiveCalories), HR: \(currentHeartRate), Sleep: \(lastNightSleep)")
        print("🔄 === SYNC LATEST DATA COMPLETED ===")
        
        syncStatus = .success
        lastSyncDate = Date()
        
        // If we successfully read data, we must be authorized
        if !isAuthorized {
            print("🔄 Data sync successful - updating authorization status to Connected")
            updateAuthorizationStatus(isAuthorized: true)
        }
    }
    
    private func readActivityData(from source: String, startDate: Date, endDate: Date) async {
        print("📊 Reading activity data from source: '\(source)'")
        let sourceKey = source.lowercased().replacingOccurrences(of: " ", with: "_")
        
        switch sourceKey {
        case "apple_health", "apple", "healthkit":
            print("✅ Using HealthKit for activity data")
            await readActivityFromHealthKit(startDate: startDate, endDate: endDate)
        case "withings", "oura", "fitbit", "whoop", "strava", "fatsecret", "csv":
            print("🔗 Using backend for activity data: \(source)")
            await readActivityFromBackend(source: source, startDate: startDate, endDate: endDate)
        default:
            print("⚠️ Unknown activity source: '\(source)' (normalized: '\(sourceKey)'), falling back to HealthKit")
            await readActivityFromHealthKit(startDate: startDate, endDate: endDate)
        }
    }
    
    private func readSleepData(from source: String, startDate: Date, endDate: Date) async {
        print("😴 Reading sleep data from source: '\(source)'")
        let sourceKey = source.lowercased().replacingOccurrences(of: " ", with: "_")
        
        switch sourceKey {
        case "apple_health", "apple", "healthkit":
            print("✅ Using HealthKit for sleep data")
            await readSleepFromHealthKit(startDate: startDate, endDate: endDate)
        case "withings", "oura", "fitbit", "whoop", "csv":
            print("🔗 Using backend for sleep data: \(source)")
            await readSleepFromBackend(source: source, startDate: startDate, endDate: endDate)
        default:
            print("⚠️ Unknown sleep source: '\(source)' (normalized: '\(sourceKey)'), falling back to HealthKit")
            await readSleepFromHealthKit(startDate: startDate, endDate: endDate)
        }
    }
    
    private func readNutritionData(from source: String, startDate: Date, endDate: Date) async {
        print("🍎 Reading nutrition data from source: '\(source)'")
        let sourceKey = source.lowercased().replacingOccurrences(of: " ", with: "_")
        
        switch sourceKey {
        case "apple_health", "apple", "healthkit":
            print("✅ Using HealthKit for nutrition data")
            await readNutritionFromHealthKit(startDate: startDate, endDate: endDate)
        case "fatsecret", "csv", "myfitnesspal", "cronometer":
            print("🔗 Using backend for nutrition data: \(source)")
            await readNutritionFromBackend(source: source, startDate: startDate, endDate: endDate)
        default:
            print("⚠️ Unknown nutrition source: '\(source)' (normalized: '\(sourceKey)'), falling back to HealthKit")
            await readNutritionFromHealthKit(startDate: startDate, endDate: endDate)
        }
    }
    
    private func readBodyCompositionData(from source: String, startDate: Date, endDate: Date) async {
        print("⚖️ Reading body composition data from source: '\(source)'")
        let sourceKey = source.lowercased().replacingOccurrences(of: " ", with: "_")
        
        switch sourceKey {
        case "apple_health", "apple", "healthkit":
            print("✅ Using HealthKit for body composition data")
            await readBodyCompositionFromHealthKit(startDate: startDate, endDate: endDate)
        case "withings", "fitbit", "whoop", "csv":
            print("🔗 Using backend for body composition data: \(source)")
            await readBodyCompositionFromBackend(source: source, startDate: startDate, endDate: endDate)
        default:
            print("⚠️ Unknown body composition source: '\(source)' (normalized: '\(sourceKey)'), falling back to HealthKit")
            await readBodyCompositionFromHealthKit(startDate: startDate, endDate: endDate)
        }
    }
    
    private func readHeartRateData(from source: String, startDate: Date, endDate: Date) async {
        print("❤️ Reading heart rate data from source: '\(source)'")
        let sourceKey = source.lowercased().replacingOccurrences(of: " ", with: "_")
        
        switch sourceKey {
        case "apple_health", "apple", "healthkit":
            print("✅ Using HealthKit for heart rate data")
            await readHeartRateFromHealthKit(startDate: startDate, endDate: endDate)
        case "withings", "oura", "fitbit", "whoop", "strava":
            print("🔗 Using backend for heart rate data: \(source)")
            await readHeartRateFromBackend(source: source, startDate: startDate, endDate: endDate)
        default:
            print("⚠️ Unknown heart rate source: '\(source)' (normalized: '\(sourceKey)'), falling back to HealthKit")
            await readHeartRateFromHealthKit(startDate: startDate, endDate: endDate)
        }
    }
    
    // MARK: - Specific HealthKit Data Reading Methods
    
    private func readActivityFromHealthKit(startDate: Date, endDate: Date) async {
        await withTaskGroup(of: Void.self) { group in
            // Read steps
            group.addTask {
                await self.readTodayStepsFromHealthKit(startDate: startDate, endDate: endDate)
            }
            
            // Read active calories
            group.addTask {
                await self.readTodayActiveCaloriesFromHealthKit(startDate: startDate, endDate: endDate)
            }
        }
    }
    
    private func readSleepFromHealthKit(startDate: Date, endDate: Date) async {
        await readLastNightSleepFromHealthKit(startDate: startDate, endDate: endDate)
    }
    
    private func readNutritionFromHealthKit(startDate: Date, endDate: Date) async {
        await readTodayNutritionFromHealthKit(startDate: startDate, endDate: endDate)
    }
    
    private func readBodyCompositionFromHealthKit(startDate: Date, endDate: Date) async {
        await readCurrentWeightFromHealthKit()
    }
    
    private func readHeartRateFromHealthKit(startDate: Date, endDate: Date) async {
        await readCurrentHeartRateFromHealthKit(startDate: startDate, endDate: endDate)
    }
    
    // MARK: - Specific HealthKit Data Reading Methods
    
    private func readTodayStepsFromHealthKit(startDate: Date, endDate: Date) async {
        print("🚶‍♂️ Reading steps from HealthKit for date range: \(startDate) to \(endDate)")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
                print("❌ Step count type not available")
                continuation.resume()
                return
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: stepCountType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error reading steps: \(error.localizedDescription)")
                    } else {
                        let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                        print("✅ Successfully read \(Int(steps)) steps")
                        self.todaySteps = Int(steps)
                    }
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func readTodayActiveCaloriesFromHealthKit(startDate: Date, endDate: Date) async {
        print("🔥 Reading active calories from HealthKit for date range: \(startDate) to \(endDate)")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
                print("❌ Active energy type not available")
                continuation.resume()
                return
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: activeEnergyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error reading active calories: \(error.localizedDescription)")
                    } else {
                        let calories = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                        print("✅ Successfully read \(Int(calories)) active calories")
                        self.todayActiveCalories = Int(calories)
                    }
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func readCurrentHeartRateFromHealthKit(startDate: Date, endDate: Date) async {
        print("❤️ Reading heart rate from HealthKit for date range: \(startDate) to \(endDate)")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
                print("❌ Heart rate type not available")
                continuation.resume()
                return
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error reading heart rate: \(error.localizedDescription)")
                    } else if let heartRateSample = samples?.first as? HKQuantitySample {
                        let heartRate = heartRateSample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                        print("✅ Successfully read heart rate: \(Int(heartRate)) BPM")
                        self.currentHeartRate = Int(heartRate)
                    } else {
                        print("⚠️ No heart rate data found")
                    }
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func readLastNightSleepFromHealthKit(startDate: Date, endDate: Date) async {
        print("😴 Reading sleep from HealthKit for date range: \(startDate) to \(endDate)")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
                print("❌ Sleep analysis type not available")
                continuation.resume()
                return
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error reading sleep: \(error.localizedDescription)")
                    } else {
                        let sleepSamples = samples as? [HKCategorySample] ?? []
                        let totalSleepTime = sleepSamples.reduce(0) { total, sample in
                            return total + sample.endDate.timeIntervalSince(sample.startDate)
                        }
                        print("✅ Successfully read sleep: \(totalSleepTime/3600) hours from \(sleepSamples.count) samples")
                        self.lastNightSleep = totalSleepTime
                    }
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func readTodayNutritionFromHealthKit(startDate: Date, endDate: Date) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
                continuation.resume()
                return
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: caloriesType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                DispatchQueue.main.async {
                    let calories = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                    self.todayNutritionCalories = Int(calories)
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func readCurrentWeightFromHealthKit() async {
        print("⚖️ Reading current weight from HealthKit")
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
                print("❌ Body mass type not available")
                continuation.resume()
                return
            }
            
            // Get the most recent weight reading (within last 30 days)
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            let predicate = HKQuery.predicateForSamples(withStart: thirtyDaysAgo, end: Date(), options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            
            let query = HKSampleQuery(sampleType: weightType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Error reading weight: \(error.localizedDescription)")
                    } else if let weightSample = samples?.first as? HKQuantitySample {
                        let weightInPounds = weightSample.quantity.doubleValue(for: HKUnit.pound())
                        print("✅ Successfully read current weight: \(weightInPounds) lbs")
                        self.currentWeight = weightInPounds
                    } else {
                        print("⚠️ No weight data found in the last 30 days")
                        self.currentWeight = 0.0
                    }
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Connected Apps
    
    func updateConnectedApps() {
        // This would analyze HealthKit data sources to identify connected apps
        // For demonstration, we'll show some common apps
        connectedApps = [
            "MyFitnessPal",
            "Cronometer", 
            "Nike Run Club",
            "Sleep Cycle",
            "Headspace",
            "Lose It!",
            "Garmin Connect"
        ]
    }
    
    func updateDetailedConnectedApps() {
        // In a real implementation, this would analyze HealthKit data sources
        // to identify which apps are actually writing data
        detailedConnectedApps = createMockConnectedApps()
    }
    
    private func createMockConnectedApps() -> [ConnectedHealthApp] {
        return [
            ConnectedHealthApp(
                name: "MyFitnessPal",
                bundleIdentifier: "com.myfitnesspal.app",
                iconURL: nil,
                description: "Nutrition tracking and calorie counting app",
                categories: ["nutrition"],
                isActive: true,
                lastSyncDate: Date().addingTimeInterval(-3600), // 1 hour ago
                dataPointsCount: 1247,
                recentDataPoints: [
                    ConnectedHealthApp.DataPoint(
                        type: "Dietary Energy",
                        value: "2,150 cal",
                        timestamp: "2 hours ago"
                    ),
                    ConnectedHealthApp.DataPoint(
                        type: "Protein",
                        value: "125 g",
                        timestamp: "2 hours ago"
                    ),
                    ConnectedHealthApp.DataPoint(
                        type: "Carbohydrates",
                        value: "280 g",
                        timestamp: "2 hours ago"
                    )
                ]
            ),
            
            ConnectedHealthApp(
                name: "Nike Run Club",
                bundleIdentifier: "com.nike.runclub",
                iconURL: nil,
                description: "Running and fitness tracking app",
                categories: ["activity"],
                isActive: true,
                lastSyncDate: Date().addingTimeInterval(-1800), // 30 minutes ago
                dataPointsCount: 892,
                recentDataPoints: [
                    ConnectedHealthApp.DataPoint(
                        type: "Workout",
                        value: "5.2 km run",
                        timestamp: "30 minutes ago"
                    ),
                    ConnectedHealthApp.DataPoint(
                        type: "Active Energy",
                        value: "420 cal",
                        timestamp: "30 minutes ago"
                    ),
                    ConnectedHealthApp.DataPoint(
                        type: "Heart Rate",
                        value: "165 bpm avg",
                        timestamp: "30 minutes ago"
                    )
                ]
            ),
            
            ConnectedHealthApp(
                name: "Sleep Cycle",
                bundleIdentifier: "com.northcube.sleepcycle",
                iconURL: nil,
                description: "Sleep tracking and smart alarm app",
                categories: ["sleep"],
                isActive: true,
                lastSyncDate: Date().addingTimeInterval(-28800), // 8 hours ago
                dataPointsCount: 456,
                recentDataPoints: [
                    ConnectedHealthApp.DataPoint(
                        type: "Sleep Analysis",
                        value: "7h 32m",
                        timestamp: "8 hours ago"
                    ),
                    ConnectedHealthApp.DataPoint(
                        type: "Sleep Quality",
                        value: "85%",
                        timestamp: "8 hours ago"
                    )
                ]
            ),
            
            ConnectedHealthApp(
                name: "Apple Watch",
                bundleIdentifier: "com.apple.watch",
                iconURL: nil,
                description: "Apple's wearable device for health and fitness",
                categories: ["activity", "heart", "body"],
                isActive: true,
                lastSyncDate: Date().addingTimeInterval(-300), // 5 minutes ago
                dataPointsCount: 3421,
                recentDataPoints: [
                    ConnectedHealthApp.DataPoint(
                        type: "Steps",
                        value: "8,247",
                        timestamp: "5 minutes ago"
                    ),
                    ConnectedHealthApp.DataPoint(
                        type: "Heart Rate",
                        value: "72 bpm",
                        timestamp: "5 minutes ago"
                    ),
                    ConnectedHealthApp.DataPoint(
                        type: "Active Energy",
                        value: "1,890 cal",
                        timestamp: "5 minutes ago"
                    )
                ]
            ),
            
            ConnectedHealthApp(
                name: "Headspace",
                bundleIdentifier: "com.headspace.app",
                iconURL: nil,
                description: "Meditation and mindfulness app",
                categories: ["mindfulness"],
                isActive: true,
                lastSyncDate: Date().addingTimeInterval(-7200), // 2 hours ago
                dataPointsCount: 89,
                recentDataPoints: [
                    ConnectedHealthApp.DataPoint(
                        type: "Mindful Session",
                        value: "10 minutes",
                        timestamp: "2 hours ago"
                    )
                ]
            ),
            
            ConnectedHealthApp(
                name: "Cronometer",
                bundleIdentifier: "com.cronometer.app",
                iconURL: nil,
                description: "Comprehensive nutrition tracking app",
                categories: ["nutrition"],
                isActive: false,
                lastSyncDate: Date().addingTimeInterval(-172800), // 2 days ago
                dataPointsCount: 234,
                recentDataPoints: []
            )
        ]
    }
    
    // MARK: - Utility Methods
    
    func getAuthorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        return healthStore.authorizationStatus(for: type)
    }
    
    func openHealthApp() {
        if let url = URL(string: "x-apple-health://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    // MARK: - Backend Data Reading Methods
    
    private func readActivityFromBackend(source: String, startDate: Date, endDate: Date) async {
        do {
            // For demo purposes, using mock data
            // In production, this would fetch from the backend API
            await fetchActivityDataFromBackend(source: source, startDate: startDate, endDate: endDate)
        } catch {
            print("Error reading activity data from \(source): \(error)")
        }
    }
    
    private func readSleepFromBackend(source: String, startDate: Date, endDate: Date) async {
        do {
            await fetchSleepDataFromBackend(source: source, startDate: startDate, endDate: endDate)
        } catch {
            print("Error reading sleep data from \(source): \(error)")
        }
    }
    
    private func readNutritionFromBackend(source: String, startDate: Date, endDate: Date) async {
        do {
            await fetchNutritionDataFromBackend(source: source, startDate: startDate, endDate: endDate)
        } catch {
            print("Error reading nutrition data from \(source): \(error)")
        }
    }
    
    private func readBodyCompositionFromBackend(source: String, startDate: Date, endDate: Date) async {
        do {
            await fetchBodyCompositionDataFromBackend(source: source, startDate: startDate, endDate: endDate)
        } catch {
            print("Error reading body composition data from \(source): \(error)")
        }
    }
    
    private func readHeartRateFromBackend(source: String, startDate: Date, endDate: Date) async {
        do {
            await fetchHeartRateDataFromBackend(source: source, startDate: startDate, endDate: endDate)
        } catch {
            print("Error reading heart rate data from \(source): \(error)")
        }
    }
    
    // MARK: - API Data Fetching Methods
    
    private func fetchActivityDataFromBackend(source: String, startDate: Date, endDate: Date) async {
        // Example implementation for different sources
        switch source {
        case "Withings":
            await fetchWithingsActivityData(startDate: startDate, endDate: endDate)
        case "Oura":
            await fetchOuraActivityData(startDate: startDate, endDate: endDate)
        case "Fitbit":
            await fetchFitbitActivityData(startDate: startDate, endDate: endDate)
        case "WHOOP":
            await fetchWhoopActivityData(startDate: startDate, endDate: endDate)
        case "Strava":
            await fetchStravaActivityData(startDate: startDate, endDate: endDate)
        default:
            print("Activity data not available for source: \(source)")
        }
    }
    
    private func fetchSleepDataFromBackend(source: String, startDate: Date, endDate: Date) async {
        switch source {
        case "Withings":
            await fetchWithingsSleepData(startDate: startDate, endDate: endDate)
        case "Oura":
            await fetchOuraSleepData(startDate: startDate, endDate: endDate)
        case "Fitbit":
            await fetchFitbitSleepData(startDate: startDate, endDate: endDate)
        case "WHOOP":
            await fetchWhoopSleepData(startDate: startDate, endDate: endDate)
        default:
            print("Sleep data not available for source: \(source)")
        }
    }
    
    private func fetchNutritionDataFromBackend(source: String, startDate: Date, endDate: Date) async {
        switch source {
        case "FatSecret":
            await fetchFatSecretNutritionData(startDate: startDate, endDate: endDate)
        default:
            print("Nutrition data not available for source: \(source)")
        }
    }
    
    private func fetchBodyCompositionDataFromBackend(source: String, startDate: Date, endDate: Date) async {
        switch source {
        case "Withings":
            await fetchWithingsBodyCompositionData(startDate: startDate, endDate: endDate)
        case "Fitbit":
            await fetchFitbitBodyCompositionData(startDate: startDate, endDate: endDate)
        case "WHOOP":
            await fetchWhoopBodyCompositionData(startDate: startDate, endDate: endDate)
        default:
            print("Body composition data not available for source: \(source)")
        }
    }
    
    private func fetchHeartRateDataFromBackend(source: String, startDate: Date, endDate: Date) async {
        switch source {
        case "Withings":
            await fetchWithingsHeartRateData(startDate: startDate, endDate: endDate)
        case "Oura":
            await fetchOuraHeartRateData(startDate: startDate, endDate: endDate)
        case "Fitbit":
            await fetchFitbitHeartRateData(startDate: startDate, endDate: endDate)
        case "WHOOP":
            await fetchWhoopHeartRateData(startDate: startDate, endDate: endDate)
        case "Strava":
            await fetchStravaHeartRateData(startDate: startDate, endDate: endDate)
        default:
            print("Heart rate data not available for source: \(source)")
        }
    }
    
    // MARK: - Source-Specific Data Fetching (Real Backend Integration)
    
    // CRITICAL: This section was previously using Int.random() and Double.random()
    // Now replaced with real backend API calls and proper fallback handling
    
    // Withings methods
    private func fetchWithingsActivityData(startDate: Date, endDate: Date) async {
        print("🔗 Fetching Withings activity data from backend API...")
        do {
            // Call real backend API endpoint for Withings activity data with timeout protection
            let response = try await withTimeout(seconds: 8) { [self] in
                try await self.networkManager.fetchWithingsActivityData(startDate: startDate, endDate: endDate)
            }
            
            await MainActor.run {
                self.todaySteps = response.steps ?? self.todaySteps
                self.todayActiveCalories = response.activeCalories ?? self.todayActiveCalories
            }
            print("✅ Fetched real Withings activity: \(response.steps ?? 0) steps, \(response.activeCalories ?? 0) calories")
        } catch {
            print("❌ Error fetching Withings activity data: \(error)")
            // Fallback: Keep existing HealthKit data if backend fails
            print("📱 Using existing HealthKit data as fallback")
        }
    }
    
    private func fetchWithingsSleepData(startDate: Date, endDate: Date) async {
        print("🔗 Fetching Withings sleep data from backend API...")
        do {
            let response = try await networkManager.fetchWithingsSleepData(startDate: startDate, endDate: endDate)
            
            await MainActor.run {
                self.lastNightSleep = response.sleepDuration ?? self.lastNightSleep
            }
            print("✅ Fetched real Withings sleep: \((response.sleepDuration ?? 0)/3600) hours")
        } catch {
            print("❌ Error fetching Withings sleep data: \(error)")
            print("📱 Using existing HealthKit data as fallback")
        }
    }
    
    private func fetchWithingsHeartRateData(startDate: Date, endDate: Date) async {
        print("🔗 Fetching Withings heart rate data from backend API...")
        do {
            let response = try await networkManager.fetchWithingsHeartRateData(startDate: startDate, endDate: endDate)
            
            await MainActor.run {
                self.currentHeartRate = response.heartRate ?? self.currentHeartRate
            }
            print("✅ Fetched real Withings heart rate: \(response.heartRate ?? 0) BPM")
        } catch {
            print("❌ Error fetching Withings heart rate data: \(error)")
            print("📱 Using existing HealthKit data as fallback")
        }
    }
    
    private func fetchWithingsBodyCompositionData(startDate: Date, endDate: Date) async {
        print("🔗 Fetching Withings body composition data from backend API...")
        do {
            let response = try await networkManager.fetchWithingsBodyCompositionData(startDate: startDate, endDate: endDate)
            print("✅ Fetched real Withings body composition data: \(response.dataPoints?.count ?? 0) data points")
        } catch {
            print("❌ Error fetching Withings body composition data: \(error)")
        }
    }
    
    // Oura methods
    private func fetchOuraActivityData(startDate: Date, endDate: Date) async {
        print("🔗 Fetching Oura activity data from backend API...")
        do {
            let response = try await networkManager.fetchOuraActivityData(startDate: startDate, endDate: endDate)
            
            await MainActor.run {
                self.todaySteps = response.steps ?? self.todaySteps
                self.todayActiveCalories = response.activeCalories ?? self.todayActiveCalories
            }
            print("✅ Fetched real Oura activity: \(response.steps ?? 0) steps, \(response.activeCalories ?? 0) calories")
        } catch {
            print("❌ Error fetching Oura activity data: \(error)")
            print("📱 Using existing HealthKit data as fallback")
        }
    }
    
    private func fetchOuraSleepData(startDate: Date, endDate: Date) async {
        print("🔗 Fetching Oura sleep data from backend API...")
        do {
            let response = try await networkManager.fetchOuraSleepData(startDate: startDate, endDate: endDate)
            
            await MainActor.run {
                self.lastNightSleep = response.sleepDuration ?? self.lastNightSleep
            }
            print("✅ Fetched real Oura sleep: \((response.sleepDuration ?? 0)/3600) hours")
        } catch {
            print("❌ Error fetching Oura sleep data: \(error)")
            print("📱 Using existing HealthKit data as fallback")
        }
    }
    
    private func fetchOuraHeartRateData(startDate: Date, endDate: Date) async {
        print("🔗 Fetching Oura heart rate data from backend API...")
        do {
            let response = try await networkManager.fetchOuraHeartRateData(startDate: startDate, endDate: endDate)
            
            await MainActor.run {
                self.currentHeartRate = response.heartRate ?? self.currentHeartRate
            }
            print("✅ Fetched real Oura heart rate: \(response.heartRate ?? 0) BPM")
        } catch {
            print("❌ Error fetching Oura heart rate data: \(error)")
            print("📱 Using existing HealthKit data as fallback")
        }
    }
    
    // Fitbit methods
    private func fetchFitbitActivityData(startDate: Date, endDate: Date) async {
        print("🔗 Fetching Fitbit activity data from backend API...")
        do {
            let response = try await networkManager.fetchFitbitActivityData(startDate: startDate, endDate: endDate)
            
            await MainActor.run {
                self.todaySteps = response.steps ?? self.todaySteps
                self.todayActiveCalories = response.activeCalories ?? self.todayActiveCalories
            }
            print("✅ Fetched real Fitbit activity: \(response.steps ?? 0) steps, \(response.activeCalories ?? 0) calories")
        } catch {
            print("❌ Error fetching Fitbit activity data: \(error)")
            print("📱 Using existing HealthKit data as fallback")
        }
    }
    
    private func fetchFitbitSleepData(startDate: Date, endDate: Date) async {
        print("🔗 Fetching Fitbit sleep data from backend API...")
        do {
            let response = try await networkManager.fetchFitbitSleepData(startDate: startDate, endDate: endDate)
            
            await MainActor.run {
                self.lastNightSleep = response.sleepDuration ?? self.lastNightSleep
            }
            print("✅ Fetched real Fitbit sleep: \((response.sleepDuration ?? 0)/3600) hours")
        } catch {
            print("❌ Error fetching Fitbit sleep data: \(error)")
            print("📱 Using existing HealthKit data as fallback")
        }
    }
    
    private func fetchFitbitHeartRateData(startDate: Date, endDate: Date) async {
        print("🔗 Fetching Fitbit heart rate data from backend API...")
        do {
            let response = try await networkManager.fetchFitbitHeartRateData(startDate: startDate, endDate: endDate)
            
            await MainActor.run {
                self.currentHeartRate = response.heartRate ?? self.currentHeartRate
            }
            print("✅ Fetched real Fitbit heart rate: \(response.heartRate ?? 0) BPM")
        } catch {
            print("❌ Error fetching Fitbit heart rate data: \(error)")
            print("📱 Using existing HealthKit data as fallback")
        }
    }
    
    private func fetchFitbitBodyCompositionData(startDate: Date, endDate: Date) async {
        print("🔗 Fetching Fitbit body composition data from backend API...")
        do {
            let response = try await networkManager.fetchFitbitBodyCompositionData(startDate: startDate, endDate: endDate)
            print("✅ Fetched real Fitbit body composition data: \(response.dataPoints?.count ?? 0) data points")
        } catch {
            print("❌ Error fetching Fitbit body composition data: \(error)")
        }
    }
    
    // WHOOP methods
    private func fetchWhoopActivityData(startDate: Date, endDate: Date) async {
        print("🔗 Fetching WHOOP activity data from backend API...")
        do {
            let response = try await networkManager.fetchWhoopActivityData(startDate: startDate, endDate: endDate)
            
            await MainActor.run {
                self.todaySteps = response.steps ?? self.todaySteps
                self.todayActiveCalories = response.activeCalories ?? self.todayActiveCalories
            }
            print("✅ Fetched real WHOOP activity: \(response.steps ?? 0) steps, \(response.activeCalories ?? 0) calories")
        } catch {
            print("❌ Error fetching WHOOP activity data: \(error)")
            print("📱 Using existing HealthKit data as fallback")
        }
    }
    
    private func fetchWhoopSleepData(startDate: Date, endDate: Date) async {
        print("🔗 Fetching WHOOP sleep data from backend API...")
        do {
            let response = try await networkManager.fetchWhoopSleepData(startDate: startDate, endDate: endDate)
            
            await MainActor.run {
                self.lastNightSleep = response.sleepDuration ?? self.lastNightSleep
            }
            print("✅ Fetched real WHOOP sleep: \((response.sleepDuration ?? 0)/3600) hours")
        } catch {
            print("❌ Error fetching WHOOP sleep data: \(error)")
            print("📱 Using existing HealthKit data as fallback")
        }
    }
    
    private func fetchWhoopHeartRateData(startDate: Date, endDate: Date) async {
        print("🔗 Fetching WHOOP heart rate data from backend API...")
        do {
            let response = try await networkManager.fetchWhoopHeartRateData(startDate: startDate, endDate: endDate)
            
            await MainActor.run {
                self.currentHeartRate = response.heartRate ?? self.currentHeartRate
            }
            print("✅ Fetched real WHOOP heart rate: \(response.heartRate ?? 0) BPM")
        } catch {
            print("❌ Error fetching WHOOP heart rate data: \(error)")
            print("📱 Using existing HealthKit data as fallback")
        }
    }
    
    private func fetchWhoopBodyCompositionData(startDate: Date, endDate: Date) async {
        print("🔗 Fetching WHOOP body composition data from backend API...")
        do {
            let response = try await networkManager.fetchWhoopBodyCompositionData(startDate: startDate, endDate: endDate)
            print("✅ Fetched real WHOOP body composition data: \(response.dataPoints?.count ?? 0) data points")
        } catch {
            print("❌ Error fetching WHOOP body composition data: \(error)")
        }
    }
    
    // Strava methods
    private func fetchStravaActivityData(startDate: Date, endDate: Date) async {
        print("🔗 Fetching Strava activity data from backend API...")
        do {
            let response = try await networkManager.fetchStravaActivityData(startDate: startDate, endDate: endDate)
            
            await MainActor.run {
                self.todaySteps = response.steps ?? self.todaySteps
                self.todayActiveCalories = response.activeCalories ?? self.todayActiveCalories
            }
            print("✅ Fetched real Strava activity: \(response.steps ?? 0) steps, \(response.activeCalories ?? 0) calories")
        } catch {
            print("❌ Error fetching Strava activity data: \(error)")
            print("📱 Using existing HealthKit data as fallback")
        }
    }
    
    private func fetchStravaHeartRateData(startDate: Date, endDate: Date) async {
        print("🔗 Fetching Strava heart rate data from backend API...")
        do {
            let response = try await networkManager.fetchStravaHeartRateData(startDate: startDate, endDate: endDate)
            
            await MainActor.run {
                self.currentHeartRate = response.heartRate ?? self.currentHeartRate
            }
            print("✅ Fetched real Strava heart rate: \(response.heartRate ?? 0) BPM")
        } catch {
            print("❌ Error fetching Strava heart rate data: \(error)")
            print("📱 Using existing HealthKit data as fallback")
        }
    }
    
    // FatSecret methods
    private func fetchFatSecretNutritionData(startDate: Date, endDate: Date) async {
        print("🔗 Fetching FatSecret nutrition data from backend API...")
        do {
            let response = try await networkManager.fetchFatSecretNutritionData(startDate: startDate, endDate: endDate)
            
            await MainActor.run {
                self.todayNutritionCalories = response.calories ?? self.todayNutritionCalories
            }
            print("✅ Fetched real FatSecret nutrition: \(response.calories ?? 0) calories")
        } catch {
            print("❌ Error fetching FatSecret nutrition data: \(error)")
            print("📱 Using existing HealthKit data as fallback")
        }
    }
}

// MARK: - Shared Timeout Utility Error

/// Shared timeout error that can be used across the app
struct TimeoutError: Error {
    var localizedDescription: String {
        return "Operation timed out"
    }
}

// MARK: - Timeout Utility

extension HealthDataManager {
    /// Executes an async operation with a timeout to prevent indefinite hanging
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add the main operation
            group.addTask {
                try await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            // Return the first result (either success or timeout)
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            // Cancel remaining tasks
            group.cancelAll()
            return result
        }
    }
} 