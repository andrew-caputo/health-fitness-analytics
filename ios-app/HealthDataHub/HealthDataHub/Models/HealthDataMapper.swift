import Foundation
import HealthKit

struct HealthDataMapper {
    
    // MARK: - Unified Health Metric Structure
    
    struct HealthMetricUnified: Codable {
        let metricType: String
        let value: Double
        let unit: String
        let sourceType: String
        let recordedAt: Date
        let metadata: [String: String]?
        let sourceApp: String?
        let deviceName: String?
        
        init(metricType: String, value: Double, unit: String, sourceType: String, recordedAt: Date, metadata: [String: Any]? = nil, sourceApp: String? = nil, deviceName: String? = nil) {
            self.metricType = metricType
            self.value = value
            self.unit = unit
            self.sourceType = sourceType
            self.recordedAt = recordedAt
            // Convert [String: Any] to [String: String] for Codable compliance
            self.metadata = metadata?.compactMapValues { value in
                if let stringValue = value as? String {
                    return stringValue
                } else {
                    return String(describing: value)
                }
            }
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
                metricType: "nutrition_carbohydrates",
                value: quantitySample.quantity.doubleValue(for: .gram()),
                unit: "g",
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
                unit: "g",
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
                unit: "g",
                sourceType: "healthkit",
                recordedAt: sample.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            )
            
        case HKQuantityType.quantityType(forIdentifier: .dietaryFiber):
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            return HealthMetricUnified(
                metricType: "nutrition_fiber",
                value: quantitySample.quantity.doubleValue(for: .gram()),
                unit: "g",
                sourceType: "healthkit",
                recordedAt: sample.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            )
            
        case HKQuantityType.quantityType(forIdentifier: .dietarySugar):
            guard let quantitySample = sample as? HKQuantitySample else { return nil }
            return HealthMetricUnified(
                metricType: "nutrition_sugar",
                value: quantitySample.quantity.doubleValue(for: .gram()),
                unit: "g",
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
    
    // MARK: - Workout Mapping
    
    static func mapWorkoutToUnifiedSchema(workout: HKWorkout) -> [HealthMetricUnified] {
        var metrics: [HealthMetricUnified] = []
        
        let sourceApp = workout.source.name
        let deviceName = workout.device?.name
        let metadata = workout.metadata
        
        // Workout duration
        metrics.append(HealthMetricUnified(
            metricType: "workout_duration",
            value: workout.duration,
            unit: "seconds",
            sourceType: "healthkit",
            recordedAt: workout.startDate,
            metadata: metadata,
            sourceApp: sourceApp,
            deviceName: deviceName
        ))
        
        // Total energy burned
        if let totalEnergyBurned = workout.totalEnergyBurned {
            metrics.append(HealthMetricUnified(
                metricType: "workout_calories",
                value: totalEnergyBurned.doubleValue(for: .kilocalorie()),
                unit: "kcal",
                sourceType: "healthkit",
                recordedAt: workout.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            ))
        }
        
        // Total distance
        if let totalDistance = workout.totalDistance {
            metrics.append(HealthMetricUnified(
                metricType: "workout_distance",
                value: totalDistance.doubleValue(for: .meter()),
                unit: "meters",
                sourceType: "healthkit",
                recordedAt: workout.startDate,
                metadata: metadata,
                sourceApp: sourceApp,
                deviceName: deviceName
            ))
        }
        
        return metrics
    }
    
    // MARK: - Sleep Mapping
    
    static func mapSleepToUnifiedSchema(sleep: HKCategorySample) -> HealthMetricUnified? {
        let sourceApp = sleep.source.name
        let deviceName = sleep.device?.name
        let metadata = sleep.metadata
        
        let duration = sleep.endDate.timeIntervalSince(sleep.startDate)
        
        return HealthMetricUnified(
            metricType: "sleep_duration",
            value: duration / 3600, // Convert to hours
            unit: "hours",
            sourceType: "healthkit",
            recordedAt: sleep.startDate,
            metadata: metadata,
            sourceApp: sourceApp,
            deviceName: deviceName
        )
    }
    
    // MARK: - Data Attribution
    
    struct DataAttribution {
        let sourceApp: String
        let sourceBundleIdentifier: String
        let deviceName: String?
        let sourceVersion: String?
        let recordedAt: Date
    }
    
    static func extractAttribution(from sample: HKSample) -> DataAttribution {
        return DataAttribution(
            sourceApp: sample.source.name,
            sourceBundleIdentifier: sample.source.bundleIdentifier,
            deviceName: sample.device?.name,
            sourceVersion: sample.sourceRevision.version,
            recordedAt: sample.startDate
        )
    }
    
    // MARK: - Batch Processing
    
    static func mapSamplesToUnifiedSchema(samples: [HKSample]) -> [HealthMetricUnified] {
        return samples.compactMap { sample in
            if let workout = sample as? HKWorkout {
                return mapWorkoutToUnifiedSchema(workout: workout)
            } else if let sleepSample = sample as? HKCategorySample, 
                      sample.sampleType == HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
                return [mapSleepToUnifiedSchema(sleep: sleepSample)].compactMap { $0 }
            } else {
                return [mapToUnifiedSchema(sample: sample)].compactMap { $0 }
            }
        }.flatMap { $0 }
    }
    
    // MARK: - JSON Serialization
    
    static func serializeForAPI(metrics: [HealthMetricUnified]) -> [[String: Any]] {
        return metrics.map { metric in
            var dict: [String: Any] = [
                "metric_type": metric.metricType,
                "value": metric.value,
                "unit": metric.unit,
                "source_type": metric.sourceType,
                "recorded_at": ISO8601DateFormatter().string(from: metric.recordedAt)
            ]
            
            if let sourceApp = metric.sourceApp {
                dict["source_app"] = sourceApp
            }
            
            if let deviceName = metric.deviceName {
                dict["device_name"] = deviceName
            }
            
            if let metadata = metric.metadata {
                dict["metadata"] = metadata
            }
            
            return dict
        }
    }
} 