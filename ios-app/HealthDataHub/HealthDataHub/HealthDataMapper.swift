import Foundation
import HealthKit

struct HealthDataMapper {
    
    // MARK: - Unified Health Metric Structure
    
    struct HealthMetricUnified {
        let metricType: String
        let value: Double
        let unit: String
        let sourceType: String
        let recordedAt: Date
        let metadata: [String: Any]?
        let sourceApp: String?
        let deviceName: String?
        
        init(metricType: String, value: Double, unit: String, sourceType: String, recordedAt: Date, metadata: [String: Any]? = nil, sourceApp: String? = nil, deviceName: String? = nil) {
            self.metricType = metricType
            self.value = value
            self.unit = unit
            self.sourceType = sourceType
            self.recordedAt = recordedAt
            self.metadata = metadata
            self.sourceApp = sourceApp
            self.deviceName = deviceName
        }
    }
    
    // MARK: - Mapping Functions
    
    static func mapToUnifiedSchema(sample: HKSample) -> HealthMetricUnified? {
        let sourceApp = sample.source.name
        let deviceName = sample.device?.name
        let metadata = sample.metadata
        
        switch sample.sampleType {
        // Activity & Fitness
        case HKQuantityType.quantityType(forIdentifier: .stepCount):
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            return HealthMetricUnified(
                metricType: "activity_steps",
                value: quantitySample.quantity.doubleValue(for: .count()),
                unit: "steps",
                sourceType: "healthkit",
                recordedAt: sample.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            )
            
        case HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning):
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            return HealthMetricUnified(
                metricType: "activity_distance",
                value: quantitySample.quantity.doubleValue(for: .meter()),
                unit: "meters",
                sourceType: "healthkit",
                recordedAt: sample.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            )
            
        case HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned):
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            return HealthMetricUnified(
                metricType: "activity_calories",
                value: quantitySample.quantity.doubleValue(for: .kilocalorie()),
                unit: "kcal",
                sourceType: "healthkit",
                recordedAt: sample.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            )
            
        case HKQuantityType.quantityType(forIdentifier: .appleExerciseTime):
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            return HealthMetricUnified(
                metricType: "activity_exercise_time",
                value: quantitySample.quantity.doubleValue(for: .minute()),
                unit: "minutes",
                sourceType: "healthkit",
                recordedAt: sample.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            )
            
        // Body Measurements
        case HKQuantityType.quantityType(forIdentifier: .bodyMass):
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            return HealthMetricUnified(
                metricType: "body_weight",
                value: quantitySample.quantity.doubleValue(for: .gramUnit(with: .kilo)),
                unit: "kg",
                sourceType: "healthkit",
                recordedAt: sample.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            )
            
        case HKQuantityType.quantityType(forIdentifier: .height):
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            return HealthMetricUnified(
                metricType: "body_height",
                value: quantitySample.quantity.doubleValue(for: .meter()),
                unit: "meters",
                sourceType: "healthkit",
                recordedAt: sample.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            )
            
        case HKQuantityType.quantityType(forIdentifier: .bodyMassIndex):
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            return HealthMetricUnified(
                metricType: "body_bmi",
                value: quantitySample.quantity.doubleValue(for: .count()),
                unit: "kg/m²",
                sourceType: "healthkit",
                recordedAt: sample.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            )
            
        case HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage):
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            return HealthMetricUnified(
                metricType: "body_fat_percentage",
                value: quantitySample.quantity.doubleValue(for: .percent()) * 100,
                unit: "percent",
                sourceType: "healthkit",
                recordedAt: sample.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            )
            
        // Heart Health
        case HKQuantityType.quantityType(forIdentifier: .heartRate):
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            return HealthMetricUnified(
                metricType: "heart_rate",
                value: quantitySample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                unit: "bpm",
                sourceType: "healthkit",
                recordedAt: sample.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            )
            
        case HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN):
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            return HealthMetricUnified(
                metricType: "heart_rate_variability",
                value: quantitySample.quantity.doubleValue(for: .secondUnit(with: .milli)),
                unit: "ms",
                sourceType: "healthkit",
                recordedAt: sample.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            )
            
        case HKQuantityType.quantityType(forIdentifier: .restingHeartRate):
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            return HealthMetricUnified(
                metricType: "resting_heart_rate",
                value: quantitySample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                unit: "bpm",
                sourceType: "healthkit",
                recordedAt: sample.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            )
            
        // Nutrition
        case HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed):
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            return HealthMetricUnified(
                metricType: "nutrition_calories",
                value: quantitySample.quantity.doubleValue(for: .kilocalorie()),
                unit: "kcal",
                sourceType: "healthkit",
                recordedAt: sample.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            )
            
        case HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates):
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            return HealthMetricUnified(
                metricType: "nutrition_carbs",
                value: quantitySample.quantity.doubleValue(for: .gram()),
                unit: "grams",
                sourceType: "healthkit",
                recordedAt: sample.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            )
            
        case HKQuantityType.quantityType(forIdentifier: .dietaryProtein):
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            return HealthMetricUnified(
                metricType: "nutrition_protein",
                value: quantitySample.quantity.doubleValue(for: .gram()),
                unit: "grams",
                sourceType: "healthkit",
                recordedAt: sample.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            )
            
        case HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal):
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            return HealthMetricUnified(
                metricType: "nutrition_fat",
                value: quantitySample.quantity.doubleValue(for: .gram()),
                unit: "grams",
                sourceType: "healthkit",
                recordedAt: sample.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            )
            
        // Sleep
        case HKCategoryType.categoryType(forIdentifier: .sleepAnalysis):
            guard let categorySample = sample as? HKCategorySample else { return nil }
            let sleepValue = categorySample.value
            let duration = categorySample.endDate.timeIntervalSince(categorySample.startDate) / 3600 // Convert to hours
            
            let sleepStage: String
            switch HKCategoryValueSleepAnalysis(rawValue: sleepValue) {
            case .inBed:
                sleepStage = "sleep_time_in_bed"
            case .asleepCore, .asleepDeep, .asleepREM:
                sleepStage = "sleep_duration"
            case .awake:
                sleepStage = "sleep_awake_time"
            default:
                sleepStage = "sleep_unknown"
            }
            
            return HealthMetricUnified(
                metricType: sleepStage,
                value: duration,
                unit: "hours",
                sourceType: "healthkit",
                recordedAt: sample.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            )
            
        default:
            return nil
        }
    }
    
    // MARK: - Sleep Analysis Helpers
    
    static func processSleepData(_ samples: [HKCategorySample]) -> [HealthMetricUnified] {
        var results: [HealthMetricUnified] = []
        
        // Group samples by date
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let groupedSamples = Dictionary(grouping: samples) { sample in
            dateFormatter.string(from: sample.startDate)
        }
        
        for (_, dailySamples) in groupedSamples {
            var totalSleepTime: TimeInterval = 0
            var totalInBedTime: TimeInterval = 0
            var totalAwakeTime: TimeInterval = 0
            
            for sample in dailySamples {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                
                switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                case .inBed:
                    totalInBedTime += duration
                case .asleepCore, .asleepDeep, .asleepREM:
                    totalSleepTime += duration
                case .awake:
                    totalAwakeTime += duration
                default:
                    break
                }
            }
            
            if let firstSample = dailySamples.first {
                if totalSleepTime > 0 {
                    results.append(HealthMetricUnified(
                        metricType: "sleep_duration",
                        value: totalSleepTime / 3600,
                        unit: "hours",
                        sourceType: "healthkit",
                        recordedAt: firstSample.startDate,
                        metadata: nil,
                        sourceApp: firstSample.source.name,
                        deviceName: firstSample.device?.name
                    ))
                }
                
                if totalInBedTime > 0 {
                    results.append(HealthMetricUnified(
                        metricType: "sleep_time_in_bed",
                        value: totalInBedTime / 3600,
                        unit: "hours",
                        sourceType: "healthkit",
                        recordedAt: firstSample.startDate,
                        metadata: nil,
                        sourceApp: firstSample.source.name,
                        deviceName: firstSample.device?.name
                    ))
                }
                
                if totalAwakeTime > 0 {
                    results.append(HealthMetricUnified(
                        metricType: "sleep_awake_time",
                        value: totalAwakeTime / 3600,
                        unit: "hours",
                        sourceType: "healthkit",
                        recordedAt: firstSample.startDate,
                        metadata: nil,
                        sourceApp: firstSample.source.name,
                        deviceName: firstSample.device?.name
                    ))
                }
                
                // Calculate sleep efficiency
                if totalInBedTime > 0 && totalSleepTime > 0 {
                    let efficiency = (totalSleepTime / totalInBedTime) * 100
                    results.append(HealthMetricUnified(
                        metricType: "sleep_efficiency",
                        value: efficiency,
                        unit: "percent",
                        sourceType: "healthkit",
                        recordedAt: firstSample.startDate,
                        metadata: nil,
                        sourceApp: firstSample.source.name,
                        deviceName: firstSample.device?.name
                    ))
                }
            }
        }
        
        return results
    }
    
    // MARK: - Batch Processing
    
    static func convertToUnifiedMetrics(_ samples: [HKSample]) -> [HealthMetricUnified] {
        var unifiedMetrics: [HealthMetricUnified] = []
        
        // Separate sleep samples for special processing
        let sleepSamples = samples.compactMap { $0 as? HKCategorySample }
            .filter { $0.categoryType.identifier == HKCategoryTypeIdentifier.sleepAnalysis.rawValue }
        
        let otherSamples = samples.filter { sample in
            !sleepSamples.contains { $0.uuid == sample.uuid }
        }
        
        // Process regular samples
        for sample in otherSamples {
            if let metric = mapToUnifiedSchema(sample: sample) {
                unifiedMetrics.append(metric)
            }
        }
        
        // Process sleep samples
        unifiedMetrics.append(contentsOf: processSleepData(sleepSamples))
        
        return unifiedMetrics
    }
}

// MARK: - HealthKit Extensions

extension HealthDataMapper {
    
    static func getAllSupportedTypes() -> Set<HKSampleType> {
        var types = Set<HKSampleType>()
        
        // Activity & Fitness
        if let stepCount = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepCount)
        }
        if let distance = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let calories = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(calories)
        }
        if let exerciseTime = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exerciseTime)
        }
        
        // Body Measurements
        if let weight = HKQuantityType.quantityType(forIdentifier: .bodyMass) {
            types.insert(weight)
        }
        if let height = HKQuantityType.quantityType(forIdentifier: .height) {
            types.insert(height)
        }
        if let bmi = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) {
            types.insert(bmi)
        }
        if let bodyFat = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.insert(bodyFat)
        }
        
        // Heart Health
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }
        if let restingHR = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHR)
        }
        
        // Nutrition
        if let nutritionCalories = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            types.insert(nutritionCalories)
        }
        if let carbs = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            types.insert(carbs)
        }
        if let protein = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            types.insert(protein)
        }
        if let fat = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) {
            types.insert(fat)
        }
        
        // Sleep
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }
        
        return types
    }
} 