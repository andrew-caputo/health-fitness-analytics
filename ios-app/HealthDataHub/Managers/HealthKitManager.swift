import Foundation
import HealthKit
import Combine

@MainActor
class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var connectedApps: [String] = []
    @Published var lastSyncDate: Date?
    @Published var syncStatus: SyncStatus = .idle
    
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
        
        // This would typically sync with your backend API
        // For now, we'll just update the last sync date
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.lastSyncDate = Date()
            self?.syncStatus = .success
            
            // Reset to idle after showing success
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self?.syncStatus = .idle
            }
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
} 