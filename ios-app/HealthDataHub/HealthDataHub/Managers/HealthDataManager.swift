import Foundation
import HealthKit
import UIKit
import Combine

@MainActor
class HealthDataManager: ObservableObject {
    // HealthKit store
    internal let healthStore = HKHealthStore()
    
    // Network manager for backend data sources
    private let networkManager = NetworkManager.shared
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var connectedApps: [String] = []
    @Published var detailedConnectedApps: [ConnectedHealthApp] = []
    @Published var lastSyncDate: Date?
    @Published var syncStatus: SyncStatus = .idle
    
    // User preferences
    @Published var userPreferences: UserDataSourcePreferences?
    
    // Real Health Data
    @Published var todaySteps: Int = 0
    @Published var todayActiveCalories: Int = 0
    @Published var currentHeartRate: Int = 0
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
    
    init() {
        checkHealthKitAvailability()
        checkAuthorizationStatus()
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
                    self?.isAuthorized = true
                    self?.checkAuthorizationStatus()
                    self?.startObservingHealthData()
                    print("HealthKit authorization granted")
                } else {
                    print("HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        authorizationStatus = healthStore.authorizationStatus(for: stepCountType)
        isAuthorized = authorizationStatus == .sharingAuthorized
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
        syncStatus = .syncing
        
        Task {
            await loadUserPreferences()
            await readHealthDataBasedOnPreferences()
        }
    }
    
    private func loadUserPreferences() async {
        do {
            let response = try await networkManager.getUserDataSourcePreferences()
            self.userPreferences = response.preferences
        } catch {
            print("Failed to load user preferences: \(error)")
            // Fall back to default preferences (Apple Health for all)
            self.userPreferences = UserDataSourcePreferences(
                activity_source: "Apple Health",
                sleep_source: "Apple Health", 
                nutrition_source: "Apple Health",
                body_composition_source: "Apple Health",
                heart_health_source: "Apple Health"
            )
        }
    }
    
    @MainActor
    private func readHealthDataBasedOnPreferences() async {
        guard let preferences = userPreferences else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        await withTaskGroup(of: Void.self) { group in
            // Read activity data from preferred source
            group.addTask {
                await self.readActivityData(from: preferences.activity_source ?? "Apple Health", 
                                          startDate: today, endDate: tomorrow)
            }
            
            // Read sleep data from preferred source
            group.addTask {
                await self.readSleepData(from: preferences.sleep_source ?? "Apple Health",
                                       startDate: yesterday, endDate: today)
            }
            
            // Read nutrition data from preferred source
            group.addTask {
                await self.readNutritionData(from: preferences.nutrition_source ?? "Apple Health",
                                           startDate: today, endDate: tomorrow)
            }
            
            // Read body composition data from preferred source
            group.addTask {
                await self.readBodyCompositionData(from: preferences.body_composition_source ?? "Apple Health",
                                                 startDate: today, endDate: tomorrow)
            }
            
            // Read heart rate data from preferred heart rate source (defaults to activity source)
            group.addTask {
                await self.readHeartRateData(from: preferences.heart_health_source ?? preferences.activity_source ?? "Apple Health",
                                           startDate: today, endDate: tomorrow)
            }
        }
        
        syncStatus = .success
        lastSyncDate = Date()
    }
    
    private func readActivityData(from source: String, startDate: Date, endDate: Date) async {
        switch source {
        case "Apple Health":
            await readActivityFromHealthKit(startDate: startDate, endDate: endDate)
        case "Withings", "Oura", "Fitbit", "WHOOP", "Strava", "FatSecret", "CSV":
            await readActivityFromBackend(source: source, startDate: startDate, endDate: endDate)
        default:
            print("Unknown activity source: \(source), falling back to Apple Health")
            await readActivityFromHealthKit(startDate: startDate, endDate: endDate)
        }
    }
    
    private func readSleepData(from source: String, startDate: Date, endDate: Date) async {
        switch source {
        case "Apple Health":
            await readSleepFromHealthKit(startDate: startDate, endDate: endDate)
        case "Withings", "Oura", "Fitbit", "WHOOP", "CSV":
            await readSleepFromBackend(source: source, startDate: startDate, endDate: endDate)
        default:
            print("Unknown sleep source: \(source), falling back to Apple Health")
            await readSleepFromHealthKit(startDate: startDate, endDate: endDate)
        }
    }
    
    private func readNutritionData(from source: String, startDate: Date, endDate: Date) async {
        switch source {
        case "Apple Health":
            await readNutritionFromHealthKit(startDate: startDate, endDate: endDate)
        case "FatSecret", "CSV":
            await readNutritionFromBackend(source: source, startDate: startDate, endDate: endDate)
        default:
            print("Unknown nutrition source: \(source), falling back to Apple Health")
            await readNutritionFromHealthKit(startDate: startDate, endDate: endDate)
        }
    }
    
    private func readBodyCompositionData(from source: String, startDate: Date, endDate: Date) async {
        switch source {
        case "Apple Health":
            await readBodyCompositionFromHealthKit(startDate: startDate, endDate: endDate)
        case "Withings", "Fitbit", "WHOOP", "CSV":
            await readBodyCompositionFromBackend(source: source, startDate: startDate, endDate: endDate)
        default:
            print("Unknown body composition source: \(source), falling back to Apple Health")
            await readBodyCompositionFromHealthKit(startDate: startDate, endDate: endDate)
        }
    }
    
    private func readHeartRateData(from source: String, startDate: Date, endDate: Date) async {
        switch source {
        case "Apple Health":
            await readHeartRateFromHealthKit(startDate: startDate, endDate: endDate)
        case "Withings", "Oura", "Fitbit", "WHOOP", "Strava":
            await readHeartRateFromBackend(source: source, startDate: startDate, endDate: endDate)
        default:
            print("Unknown heart rate source: \(source), falling back to Apple Health")
            await readHeartRateFromHealthKit(startDate: startDate, endDate: endDate)
        }
    }
    
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
        // Body composition reading logic would go here
        print("Reading body composition data from HealthKit")
    }
    
    private func readHeartRateFromHealthKit(startDate: Date, endDate: Date) async {
        await readCurrentHeartRateFromHealthKit(startDate: startDate, endDate: endDate)
    }
    
    // MARK: - Specific HealthKit Data Reading Methods
    
    private func readTodayStepsFromHealthKit(startDate: Date, endDate: Date) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
                continuation.resume()
                return
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: stepCountType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                DispatchQueue.main.async {
                    let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                    self.todaySteps = Int(steps)
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func readTodayActiveCaloriesFromHealthKit(startDate: Date, endDate: Date) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
                continuation.resume()
                return
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let query = HKStatisticsQuery(quantityType: activeEnergyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                DispatchQueue.main.async {
                    let calories = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                    self.todayActiveCalories = Int(calories)
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func readCurrentHeartRateFromHealthKit(startDate: Date, endDate: Date) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
                continuation.resume()
                return
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                DispatchQueue.main.async {
                    if let heartRateSample = samples?.first as? HKQuantitySample {
                        let heartRate = heartRateSample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                        self.currentHeartRate = Int(heartRate)
                    }
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func readLastNightSleepFromHealthKit(startDate: Date, endDate: Date) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
                continuation.resume()
                return
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                DispatchQueue.main.async {
                    let sleepSamples = samples as? [HKCategorySample] ?? []
                    let totalSleepTime = sleepSamples.reduce(0) { total, sample in
                        return total + sample.endDate.timeIntervalSince(sample.startDate)
                    }
                    self.lastNightSleep = totalSleepTime
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
    
    // MARK: - Source-Specific Data Fetching (Mock Implementation)
    
    // Withings methods
    private func fetchWithingsActivityData(startDate: Date, endDate: Date) async {
        // Withings typically provides lower step counts but higher accuracy
        let withingsSteps = Int.random(in: 6000...8000)
        let withingsCalories = Int.random(in: 300...450)
        
        await MainActor.run {
            self.todaySteps = withingsSteps
            self.todayActiveCalories = withingsCalories
        }
        print("✅ Fetched Withings activity: \(withingsSteps) steps, \(withingsCalories) calories")
    }
    
    private func fetchWithingsSleepData(startDate: Date, endDate: Date) async {
        // Withings Sleep sensor provides detailed sleep analysis
        let withingsSleep = TimeInterval.random(in: 6.5*3600...8.5*3600) // 6.5-8.5 hours
        
        await MainActor.run {
            self.lastNightSleep = withingsSleep
        }
        print("✅ Fetched Withings sleep: \(withingsSleep/3600) hours")
    }
    
    private func fetchWithingsHeartRateData(startDate: Date, endDate: Date) async {
        let withingsHeartRate = Int.random(in: 65...75) // Withings tends to show lower resting HR
        
        await MainActor.run {
            self.currentHeartRate = withingsHeartRate
        }
        print("✅ Fetched Withings heart rate: \(withingsHeartRate) BPM")
    }
    
    private func fetchWithingsBodyCompositionData(startDate: Date, endDate: Date) async {
        print("✅ Fetched Withings body composition data")
    }
    
    // Oura methods
    private func fetchOuraActivityData(startDate: Date, endDate: Date) async {
        // Oura focuses on recovery, typically shows lower activity
        let ouraSteps = Int.random(in: 5000...7000)
        let ouraCalories = Int.random(in: 250...400)
        
        await MainActor.run {
            self.todaySteps = ouraSteps
            self.todayActiveCalories = ouraCalories
        }
        print("✅ Fetched Oura activity: \(ouraSteps) steps, \(ouraCalories) calories")
    }
    
    private func fetchOuraSleepData(startDate: Date, endDate: Date) async {
        // Oura is known for excellent sleep tracking
        let ouraSleep = TimeInterval.random(in: 7*3600...9*3600) // 7-9 hours
        
        await MainActor.run {
            self.lastNightSleep = ouraSleep
        }
        print("✅ Fetched Oura sleep: \(ouraSleep/3600) hours")
    }
    
    private func fetchOuraHeartRateData(startDate: Date, endDate: Date) async {
        let ouraHeartRate = Int.random(in: 60...70) // Oura shows recovery-focused HR
        
        await MainActor.run {
            self.currentHeartRate = ouraHeartRate
        }
        print("✅ Fetched Oura heart rate: \(ouraHeartRate) BPM")
    }
    
    // Fitbit methods
    private func fetchFitbitActivityData(startDate: Date, endDate: Date) async {
        // Fitbit typically shows higher step counts
        let fitbitSteps = Int.random(in: 8000...12000)
        let fitbitCalories = Int.random(in: 400...600)
        
        await MainActor.run {
            self.todaySteps = fitbitSteps
            self.todayActiveCalories = fitbitCalories
        }
        print("✅ Fetched Fitbit activity: \(fitbitSteps) steps, \(fitbitCalories) calories")
    }
    
    private func fetchFitbitSleepData(startDate: Date, endDate: Date) async {
        let fitbitSleep = TimeInterval.random(in: 6*3600...8*3600) // 6-8 hours
        
        await MainActor.run {
            self.lastNightSleep = fitbitSleep
        }
        print("✅ Fetched Fitbit sleep: \(fitbitSleep/3600) hours")
    }
    
    private func fetchFitbitHeartRateData(startDate: Date, endDate: Date) async {
        let fitbitHeartRate = Int.random(in: 70...80) // Fitbit often shows slightly higher
        
        await MainActor.run {
            self.currentHeartRate = fitbitHeartRate
        }
        print("✅ Fetched Fitbit heart rate: \(fitbitHeartRate) BPM")
    }
    
    private func fetchFitbitBodyCompositionData(startDate: Date, endDate: Date) async {
        print("✅ Fetched Fitbit body composition data")
    }
    
    // WHOOP methods
    private func fetchWhoopActivityData(startDate: Date, endDate: Date) async {
        // WHOOP focuses on strain, usually shows moderate activity
        let whoopSteps = Int.random(in: 6000...9000)
        let whoopCalories = Int.random(in: 350...500)
        
        await MainActor.run {
            self.todaySteps = whoopSteps
            self.todayActiveCalories = whoopCalories
        }
        print("✅ Fetched WHOOP activity: \(whoopSteps) steps, \(whoopCalories) calories")
    }
    
    private func fetchWhoopSleepData(startDate: Date, endDate: Date) async {
        let whoopSleep = TimeInterval.random(in: 7.5*3600...9.5*3600) // WHOOP emphasizes recovery
        
        await MainActor.run {
            self.lastNightSleep = whoopSleep
        }
        print("✅ Fetched WHOOP sleep: \(whoopSleep/3600) hours")
    }
    
    private func fetchWhoopHeartRateData(startDate: Date, endDate: Date) async {
        let whoopHeartRate = Int.random(in: 55...65) // WHOOP shows recovery-focused metrics
        
        await MainActor.run {
            self.currentHeartRate = whoopHeartRate
        }
        print("✅ Fetched WHOOP heart rate: \(whoopHeartRate) BPM")
    }
    
    private func fetchWhoopBodyCompositionData(startDate: Date, endDate: Date) async {
        print("✅ Fetched WHOOP body composition data")
    }
    
    // Strava methods
    private func fetchStravaActivityData(startDate: Date, endDate: Date) async {
        // Strava focuses on workouts, may show higher intensity metrics
        let stravaSteps = Int.random(in: 7000...15000) // Wide range due to workout focus
        let stravaCalories = Int.random(in: 500...800)
        
        await MainActor.run {
            self.todaySteps = stravaSteps
            self.todayActiveCalories = stravaCalories
        }
        print("✅ Fetched Strava activity: \(stravaSteps) steps, \(stravaCalories) calories")
    }
    
    private func fetchStravaHeartRateData(startDate: Date, endDate: Date) async {
        let stravaHeartRate = Int.random(in: 75...90) // Exercise-focused, typically higher
        
        await MainActor.run {
            self.currentHeartRate = stravaHeartRate
        }
        print("✅ Fetched Strava heart rate: \(stravaHeartRate) BPM")
    }
    
    // FatSecret methods
    private func fetchFatSecretNutritionData(startDate: Date, endDate: Date) async {
        let fatSecretCalories = Int.random(in: 1800...2200)
        
        await MainActor.run {
            self.todayNutritionCalories = fatSecretCalories
        }
        print("✅ Fetched FatSecret nutrition: \(fatSecretCalories) calories")
    }
} 