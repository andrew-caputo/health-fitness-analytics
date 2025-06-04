import SwiftUI
import Charts
import HealthKit

struct HealthChartsView: View {
    @StateObject private var viewModel = HealthChartsViewModel()
    @EnvironmentObject var networkManager: NetworkManager
    @EnvironmentObject var healthDataManager: HealthDataManager
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedMetric: HealthMetric = .steps
    @State private var chartData: [ChartDataPoint] = []
    @State private var isLoading = true
    @State private var showingMetricPicker = false
    @State private var showingDataSourceSettings = false
    
    // MARK: - Initializers
    
    init(initialMetric: HealthMetric = .steps) {
        // Use _selectedMetric to set the initial state
        self._selectedMetric = State(initialValue: initialMetric)
    }
    
    enum TimeRange: String, CaseIterable {
        case day = "24H"
        case week = "7D"
        case month = "30D"
        case quarter = "3M"
        case year = "1Y"
        
        var displayName: String {
            switch self {
            case .day: return "24 Hours"
            case .week: return "7 Days"
            case .month: return "30 Days"
            case .quarter: return "3 Months"
            case .year: return "1 Year"
            }
        }
        
        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            }
        }
    }
    
    enum HealthMetric: String, CaseIterable {
        case steps = "Steps"
        case heartRate = "Heart Rate"
        case activeEnergy = "Active Energy"
        case sleep = "Sleep"
        case weight = "Weight"
        case nutrition = "Calories"
        
        var unit: String {
            switch self {
            case .steps: return "steps"
            case .heartRate: return "bpm"
            case .activeEnergy: return "cal"
            case .sleep: return "hours"
            case .weight: return "lbs"
            case .nutrition: return "cal"
            }
        }
        
        var color: Color {
            switch self {
            case .steps: return .blue
            case .heartRate: return .red
            case .activeEnergy: return .orange
            case .sleep: return .purple
            case .weight: return .pink
            case .nutrition: return .green
            }
        }
        
        var icon: String {
            switch self {
            case .steps: return "figure.walk"
            case .heartRate: return "heart.fill"
            case .activeEnergy: return "flame.fill"
            case .sleep: return "bed.double.fill"
            case .weight: return "scalemass.fill"
            case .nutrition: return "fork.knife"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Time Range Selector
                    timeRangeSelector
                    
                    // Metric Selector
                    metricSelector
                    
                    // Main Chart
                    mainChart
                    
                    // Chart Statistics (only show if we have data)
                    if !chartData.isEmpty {
                    chartStatistics
                    }
                    
                    // Data Sources Attribution (only show if we have data)
                    if !chartData.isEmpty {
                    dataSourcesAttribution
                    }
                }
                .padding()
            }
            .navigationTitle("Health Charts")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadChartData()
            }
        }
        .onAppear {
            Task {
                // Request HealthKit permissions if not already granted
                if !healthDataManager.isAuthorized {
                    print("📱 HealthChartsView: Requesting HealthKit permissions...")
                    healthDataManager.requestHealthKitPermissions()
                }
                
                // Sync latest data from HealthKit
                print("🔄 HealthChartsView: Syncing latest health data...")
                healthDataManager.syncLatestData()
                
                // Load chart data after a brief delay to allow sync to complete
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                await loadChartData()
            }
        }
        .sheet(isPresented: $showingMetricPicker) {
            MetricPickerSheet(selectedMetric: $selectedMetric) {
                Task {
                    await loadChartData()
                }
            }
        }
        .sheet(isPresented: $showingDataSourceSettings) {
            NavigationView {
                DataSourceSettingsView()
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingDataSourceSettings = false
                            }
                        }
                }
            }
        }
    }
    
    private var timeRangeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTimeRange = range
                        }
                        Task {
                            await loadChartData()
                        }
                    }) {
                        Text(range.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedTimeRange == range ? selectedMetric.color : Color(.systemGray5))
                            )
                            .foregroundColor(selectedTimeRange == range ? .white : .primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var metricSelector: some View {
        Button(action: {
            showingMetricPicker = true
        }) {
            HStack {
                Image(systemName: selectedMetric.icon)
                    .foregroundColor(selectedMetric.color)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text(selectedMetric.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(selectedTimeRange.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var mainChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend Analysis")
                .font(.headline)
            
            if isLoading {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 250)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.2)
                    )
            } else if chartData.isEmpty {
                // Enhanced "No Data Available" state with clear call-to-action
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 250)
                    .overlay(
                        VStack(spacing: 16) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            VStack(spacing: 8) {
                                Text("No \(selectedMetric.rawValue) Data")
                                .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Connect your health apps to see real data and insights")
                                    .font(.subheadline)
                                .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            // Call-to-action button
                            Button(action: {
                                showingDataSourceSettings = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Connect Data Sources")
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(selectedMetric.color)
                                .cornerRadius(20)
                            }
                        }
                    )
            } else {
                Chart(chartData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value(selectedMetric.rawValue, dataPoint.value)
                    )
                    .foregroundStyle(selectedMetric.color)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value(selectedMetric.rawValue, dataPoint.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [selectedMetric.color.opacity(0.3), selectedMetric.color.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    if let source = dataPoint.source {
                        PointMark(
                            x: .value("Date", dataPoint.date),
                            y: .value(selectedMetric.rawValue, dataPoint.value)
                        )
                        .foregroundStyle(colorForSource(source))
                        .symbolSize(30)
                    }
                }
                .frame(height: 250)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    private var chartStatistics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatisticCard(
                    title: "Average",
                    value: formatValue(averageValue),
                    unit: selectedMetric.unit,
                    color: .blue
                )
                
                StatisticCard(
                    title: "Maximum",
                    value: formatValue(maxValue),
                    unit: selectedMetric.unit,
                    color: .green
                )
                
                StatisticCard(
                    title: "Minimum",
                    value: formatValue(minValue),
                    unit: selectedMetric.unit,
                    color: .orange
                )
            }
        }
    }
    
    private var dataSourcesAttribution: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Sources")
                .font(.headline)
            
            if chartData.isEmpty {
                Text("No data sources available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                let sources = Set(chartData.compactMap { $0.source })
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(Array(sources), id: \.self) { source in
                        HStack {
                            Circle()
                                .fill(colorForSource(source))
                                .frame(width: 12, height: 12)
                            
                            Text(source)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var averageValue: Double {
        guard !chartData.isEmpty else { return 0 }
        return chartData.map { $0.value }.reduce(0, +) / Double(chartData.count)
    }
    
    private var maxValue: Double {
        chartData.map { $0.value }.max() ?? 0
    }
    
    private var minValue: Double {
        chartData.map { $0.value }.min() ?? 0
    }
    
    // MARK: - Helper Methods
    
    private func loadChartData() async {
        await MainActor.run {
        isLoading = true
        }
        
        do {
            // Load real historical data using async HealthKit queries
            let chartData = try await withTimeout(seconds: 30) { // Increased timeout for multiple HealthKit queries
                await generateRealHistoricalData()
            }
        
        await MainActor.run {
                // Set chart data - empty array will trigger "No Data Available" state
                self.chartData = chartData
                self.isLoading = false
                print("📊 Chart loaded with \(chartData.count) data points")
            }
        } catch {
            print("❌ Chart data loading failed or timed out: \(error)")
            // Show empty state on error
            await MainActor.run {
                self.chartData = []
                self.isLoading = false
            }
        }
    }
    
    // Timeout utility for view operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            
            group.cancelAll()
            return result
        }
    }
    
    // Generate historical data ONLY from real HealthKit values - no fake data
    private func generateRealHistoricalData() async -> [ChartDataPoint] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -selectedTimeRange.days, to: endDate) ?? endDate
        
        print("🔍 Loading REAL historical data for \(selectedMetric.rawValue) from \(startDate) to \(endDate)")
        
        // Get user's actual data source preference for attribution
        let userDataSource = getUserDataSourceForMetric(selectedMetric)
        
        // Generate data points for each day in the range using REAL HealthKit queries
        var data: [ChartDataPoint] = []
        
        // Use async concurrent queries for better performance
        await withTaskGroup(of: (Date, Double?).self) { group in
        for i in 0..<selectedTimeRange.days {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                    group.addTask {
                        let value = await self.getRealHealthKitValueForDateAsync(date: date, metric: self.selectedMetric)
                        return (date, value)
                    }
                }
            }
            
            // Collect results
            for await (date, value) in group {
                if let realValue = value, realValue > 0 {
                    data.append(ChartDataPoint(
                        date: date,
                        value: realValue,
                        source: userDataSource
                    ))
                    print("📊 Added real data point: \(date) = \(realValue) \(selectedMetric.unit)")
                }
            }
        }
        
        // Sort by date and return
        let sortedData = data.sorted { $0.date < $1.date }
        print("✅ Generated \(sortedData.count) real historical data points for \(selectedMetric.rawValue)")
        
        return sortedData
    }
    
    // Check if we have real data for a specific metric
    private func hasRealDataForMetric(_ metric: HealthMetric) -> Bool {
        let currentRealValue = getCurrentRealValueForMetric(metric)
        
        // Consider we have real data if the current value is above minimal thresholds
        switch metric {
                case .steps:
            return currentRealValue > 0
                case .heartRate:
            return currentRealValue > 40 // Reasonable minimum heart rate
                case .activeEnergy:
            return currentRealValue > 0
                case .sleep:
            return currentRealValue > 0
                case .weight:
            return currentRealValue > 30 // Reasonable minimum weight in pounds
        case .nutrition:
            return currentRealValue > 0
        }
    }
    
    // Get actual HealthKit data for a specific date and metric - returns nil if no real data
    private func getRealHealthKitValueForDate(date: Date, metric: HealthMetric) -> Double? {
        // This is a synchronous method but we need async HealthKit calls
        // For now, return nil to force async loading in generateRealHistoricalData
        return nil
    }
    
    // NEW: Async method to get real historical HealthKit data for specific dates
    private func getRealHealthKitValueForDateAsync(date: Date, metric: HealthMetric) async -> Double? {
        return await withCheckedContinuation { continuation in
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
            
            switch metric {
            case .steps:
                getRealStepsForDate(startDate: startOfDay, endDate: endOfDay) { value in
                    continuation.resume(returning: value)
                }
            case .heartRate:
                getRealHeartRateForDate(startDate: startOfDay, endDate: endOfDay) { value in
                    continuation.resume(returning: value)
                }
            case .activeEnergy:
                getRealActiveCaloriesForDate(startDate: startOfDay, endDate: endOfDay) { value in
                    continuation.resume(returning: value)
                }
            case .sleep:
                getRealSleepForDate(startDate: startOfDay, endDate: endOfDay) { value in
                    continuation.resume(returning: value)
                }
                case .nutrition:
                getRealNutritionForDate(startDate: startOfDay, endDate: endOfDay) { value in
                    continuation.resume(returning: value)
                }
            case .weight:
                getRealWeightForDate(startDate: startOfDay, endDate: endOfDay) { value in
                    continuation.resume(returning: value)
                }
            }
        }
    }
    
    // MARK: - Real HealthKit Queries for Historical Data
    
    private func getRealStepsForDate(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let stepCountType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: stepCountType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("❌ Error reading steps for \(startDate): \(error.localizedDescription)")
                completion(nil)
            } else {
                let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count())
                print("✅ Read \(steps ?? 0) steps for \(startDate)")
                completion(steps)
            }
        }
        healthDataManager.healthStore.execute(query)
    }
    
    private func getRealActiveCaloriesForDate(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: activeEnergyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("❌ Error reading active calories for \(startDate): \(error.localizedDescription)")
                completion(nil)
            } else {
                let calories = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie())
                print("✅ Read \(calories ?? 0) active calories for \(startDate)")
                completion(calories)
            }
        }
        healthDataManager.healthStore.execute(query)
    }
    
    private func getRealHeartRateForDate(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                print("❌ Error reading heart rate for \(startDate): \(error.localizedDescription)")
                completion(nil)
            } else if let heartRateSamples = samples as? [HKQuantitySample], !heartRateSamples.isEmpty {
                // Calculate average heart rate for the day
                let totalHeartRate = heartRateSamples.reduce(0.0) { sum, sample in
                    sum + sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                }
                let averageHeartRate = totalHeartRate / Double(heartRateSamples.count)
                print("✅ Read average heart rate \(averageHeartRate) for \(startDate) from \(heartRateSamples.count) samples")
                completion(averageHeartRate)
            } else {
                print("⚠️ No heart rate data found for \(startDate)")
                completion(nil)
            }
        }
        healthDataManager.healthStore.execute(query)
    }
    
    private func getRealSleepForDate(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
            if let error = error {
                print("❌ Error reading sleep for \(startDate): \(error.localizedDescription)")
                completion(nil)
            } else {
                let sleepSamples = samples as? [HKCategorySample] ?? []
                let totalSleepTime = sleepSamples.reduce(0) { total, sample in
                    return total + sample.endDate.timeIntervalSince(sample.startDate)
                }
                let sleepHours = totalSleepTime / 3600 // Convert to hours
                print("✅ Read \(sleepHours) hours of sleep for \(startDate) from \(sleepSamples.count) samples")
                completion(sleepHours > 0 ? sleepHours : nil)
            }
        }
        healthDataManager.healthStore.execute(query)
    }
    
    private func getRealNutritionForDate(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: caloriesType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            if let error = error {
                print("❌ Error reading nutrition for \(startDate): \(error.localizedDescription)")
                completion(nil)
            } else {
                let calories = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie())
                print("✅ Read \(calories ?? 0) nutrition calories for \(startDate)")
                completion(calories)
            }
        }
        healthDataManager.healthStore.execute(query)
    }
    
    private func getRealWeightForDate(startDate: Date, endDate: Date, completion: @escaping (Double?) -> Void) {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            print("❌ Unable to create weight quantity type")
            completion(nil)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: weightType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                print("❌ Error reading weight for \(startDate): \(error.localizedDescription)")
                completion(nil)
            } else if let weightSamples = samples as? [HKQuantitySample], let latestWeight = weightSamples.first {
                let weightInPounds = latestWeight.quantity.doubleValue(for: HKUnit.pound())
                print("✅ Read weight \(weightInPounds) lbs for \(startDate)")
                completion(weightInPounds)
            } else {
                print("⚠️ No weight data found for \(startDate)")
                completion(nil)
            }
        }
        healthDataManager.healthStore.execute(query)
    }
    
    // Get user's actual configured data source for the metric
    private func getUserDataSourceForMetric(_ metric: HealthMetric) -> String {
        guard let preferences = healthDataManager.userPreferences else {
            return "Apple Health" // Default fallback
        }
        
        switch metric {
        case .steps, .activeEnergy:
            return formatDataSourceName(preferences.activity_source ?? "apple_health")
        case .heartRate:
            return formatDataSourceName(preferences.heart_health_source ?? preferences.activity_source ?? "apple_health")
        case .sleep:
            return formatDataSourceName(preferences.sleep_source ?? "apple_health")
        case .nutrition:
            return formatDataSourceName(preferences.nutrition_source ?? "apple_health")
        case .weight:
            return formatDataSourceName(preferences.body_composition_source ?? "apple_health")
        }
    }
    
    // Convert backend source names to user-friendly display names
    private func formatDataSourceName(_ source: String) -> String {
        switch source.lowercased() {
        case "apple_health", "apple", "healthkit":
            return "Apple Health"
        case "withings":
            return "Withings"
        case "oura":
            return "Oura"
        case "fitbit":
            return "Fitbit"
        case "whoop":
            return "WHOOP"
        case "strava":
            return "Strava"
        case "myfitnesspal":
            return "MyFitnessPal"
        case "cronometer":
            return "Cronometer"
        case "fatsecret":
            return "FatSecret"
        default:
            return "Apple Health" // Fallback
        }
    }
    
    // Get current real value from HealthDataManager for baseline
    private func getCurrentRealValueForMetric(_ metric: HealthMetric) -> Double {
        let value: Double
        switch metric {
        case .steps:
            value = Double(healthDataManager.todaySteps)
        case .heartRate:
            value = Double(healthDataManager.currentHeartRate)
        case .activeEnergy:
            value = Double(healthDataManager.todayActiveCalories)
        case .sleep:
            value = healthDataManager.lastNightSleep / 3600 // Convert seconds to hours
        case .weight:
            value = Double(healthDataManager.currentWeight) // Get real current weight from HealthDataManager
        case .nutrition:
            value = Double(healthDataManager.todayNutritionCalories)
        }
        
        // Add debugging to see what values we're getting
        print("📊 HealthChartsView: getCurrentRealValueForMetric(\(metric.rawValue)) = \(value)")
        print("📊 HealthDataManager values - Steps: \(healthDataManager.todaySteps), HR: \(healthDataManager.currentHeartRate), Calories: \(healthDataManager.todayActiveCalories), Sleep: \(healthDataManager.lastNightSleep), Nutrition: \(healthDataManager.todayNutritionCalories)")
        print("📊 HealthDataManager authorization status: \(healthDataManager.isAuthorized)")
        
        return value
    }
    
    private func colorForSource(_ source: String) -> Color {
        switch source.lowercased() {
        case "apple health", "apple watch", "apple", "healthkit":
            return .blue
        case "withings":
            return .green
        case "oura":
            return .purple
        case "fitbit":
            return .cyan
        case "whoop":
            return .red
        case "strava":
            return .orange
        case "myfitnesspal":
            return .orange
        case "cronometer":
            return .mint
        case "fatsecret":
            return .yellow
        case "sleep cycle":
            return .purple
        default:
            return .blue // Default to blue for Apple Health
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        switch selectedMetric {
        case .steps:
            return String(format: "%.0f", value)
        case .heartRate:
            return String(format: "%.0f", value)
        case .activeEnergy:
            return String(format: "%.0f", value)
        case .sleep:
            return String(format: "%.1f", value)
        case .weight:
            return String(format: "%.1f", value)
        case .nutrition:
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Supporting Views

struct StatisticCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct MetricPickerSheet: View {
    @Binding var selectedMetric: HealthChartsView.HealthMetric
    let onSelection: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(HealthChartsView.HealthMetric.allCases, id: \.self) { metric in
                    Button(action: {
                        selectedMetric = metric
                        onSelection()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: metric.icon)
                                .foregroundColor(metric.color)
                                .font(.title2)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text(metric.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Measured in \(metric.unit)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedMetric == metric {
                                Image(systemName: "checkmark")
                                    .foregroundColor(metric.color)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Metric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Data Models

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let source: String?
}

// MARK: - Preview

#Preview {
    HealthChartsView()
        .environmentObject(HealthDataManager.shared)
} 