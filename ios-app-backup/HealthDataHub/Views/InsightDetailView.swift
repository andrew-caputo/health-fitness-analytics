import SwiftUI
import Charts

struct InsightDetailView: View {
    let insight: HealthInsight
    @Environment(\.dismiss) private var dismiss
    @State private var showingRecommendations = true
    @State private var showingSupportingData = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header Card
                    headerCard
                    
                    // Description
                    descriptionSection
                    
                    // Metrics Involved
                    metricsSection
                    
                    // Data Sources
                    dataSourcesSection
                    
                    // Recommendations
                    recommendationsSection
                    
                    // Supporting Data
                    if showingSupportingData {
                        supportingDataSection
                    }
                    
                    // Actions
                    actionsSection
                }
                .padding()
            }
            .navigationTitle("Insight Details")
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
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.insightType.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text(insight.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    PriorityBadge(priority: insight.priority)
                    
                    VStack(spacing: 2) {
                        Text("Confidence")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(insight.confidenceScore * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(confidenceColor)
                    }
                }
            }
            
            // Confidence bar
            ProgressView(value: insight.confidenceScore)
                .progressViewStyle(LinearProgressViewStyle(tint: confidenceColor))
                .scaleEffect(x: 1, y: 2, anchor: .center)
            
            HStack {
                Text("Generated: \(insight.createdAt, style: .date)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("ID: \(insight.id)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .monospaced()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analysis")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(insight.description)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Metrics Analyzed")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(insight.metricsInvolved, id: \.self) { metric in
                    HStack {
                        Image(systemName: metricIcon(metric))
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        Text(formatMetricName(metric))
                            .font(.caption)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var dataSourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Sources")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(insight.dataSources, id: \.self) { source in
                HStack {
                    Image(systemName: dataSourceIcon(source))
                        .foregroundColor(.green)
                        .frame(width: 20)
                    
                    Text(source)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Actionable Recommendations")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        showingRecommendations.toggle()
                    }
                }) {
                    Image(systemName: showingRecommendations ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
            
            if showingRecommendations {
                ForEach(Array(insight.actionableRecommendations.enumerated()), id: \.offset) { index, recommendation in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.blue)
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recommendation)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                            
                            if index == 0 {
                                Text("Start with this first")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .italic()
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var supportingDataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Supporting Data")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        showingSupportingData.toggle()
                    }
                }) {
                    Image(systemName: showingSupportingData ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
            }
            
            if showingSupportingData {
                // This would contain charts, statistics, or other supporting data
                VStack(alignment: .leading, spacing: 8) {
                    Text("Technical Details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("This insight was generated using advanced statistical analysis and machine learning algorithms. The confidence score reflects the reliability of the pattern detection.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Mock chart or data visualization would go here
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .frame(height: 100)
                        .overlay(
                            Text("Data Visualization")
                                .foregroundColor(.blue)
                        )
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                // Share insight
                shareInsight()
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Insight")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Button(action: {
                // Mark as helpful
                markAsHelpful()
            }) {
                HStack {
                    Image(systemName: "hand.thumbsup")
                    Text("Mark as Helpful")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(10)
            }
            
            Button(action: {
                withAnimation {
                    showingSupportingData.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal")
                    Text(showingSupportingData ? "Hide Technical Details" : "Show Technical Details")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(10)
            }
        }
    }
    
    private var confidenceColor: Color {
        switch insight.confidenceScore {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
    
    private func metricIcon(_ metric: String) -> String {
        switch metric.lowercased() {
        case let m where m.contains("step"): return "figure.walk"
        case let m where m.contains("sleep"): return "bed.double"
        case let m where m.contains("heart"): return "heart"
        case let m where m.contains("weight"): return "scalemass"
        case let m where m.contains("calorie"): return "flame"
        case let m where m.contains("workout"): return "dumbbell"
        default: return "chart.line.uptrend.xyaxis"
        }
    }
    
    private func dataSourceIcon(_ source: String) -> String {
        switch source.lowercased() {
        case let s where s.contains("apple"): return "applelogo"
        case let s where s.contains("fitbit"): return "watch"
        case let s where s.contains("garmin"): return "watch"
        case let s where s.contains("withings"): return "scalemass"
        case let s where s.contains("myfitnesspal"): return "fork.knife"
        default: return "app.connected.to.app.below.fill"
        }
    }
    
    private func formatMetricName(_ metric: String) -> String {
        return metric
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
    
    private func shareInsight() {
        // Implement sharing functionality
        print("Sharing insight: \(insight.title)")
    }
    
    private func markAsHelpful() {
        // Implement feedback functionality
        print("Marked insight as helpful: \(insight.id)")
    }
}

#Preview {
    InsightDetailView(
        insight: HealthInsight(
            id: "1",
            insightType: "trend",
            priority: "high",
            title: "Sleep Duration Declining",
            description: "Your sleep duration has decreased by 15% over the past 2 weeks. This may impact your energy and recovery. The analysis shows a consistent downward trend that started around January 1st.",
            dataSources: ["Apple Health", "Sleep Cycle"],
            metricsInvolved: ["sleep_duration", "sleep_quality"],
            confidenceScore: 0.89,
            actionableRecommendations: [
                "Set a consistent bedtime routine and stick to it every night",
                "Limit screen time at least 1 hour before your target bedtime",
                "Create a sleep-friendly environment (cool, dark, quiet)",
                "Consider tracking what activities or stressors might be affecting your sleep"
            ],
            createdAt: Date()
        )
    )
} 