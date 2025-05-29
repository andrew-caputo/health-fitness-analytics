import SwiftUI

struct AIInsightsDashboardView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @State private var healthScore: HealthScore?
    @State private var insights: [HealthInsight] = []
    @State private var recommendations: [Recommendation] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Health Score Card
                    if let score = healthScore {
                        healthScoreCard(score)
                    }
                    
                    // AI Insights Section
                    insightsSection
                    
                    // Recommendations Section
                    recommendationsSection
                }
                .padding()
            }
            .navigationTitle("AI Insights")
            .refreshable {
                await loadAIData()
            }
            .task {
                await loadAIData()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func healthScoreCard(_ score: HealthScore) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text("Health Score")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(Int(score.overallScore))")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor(score.overallScore))
            }
            
            // Component scores grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(score.componentScores, id: \.category) { component in
                    VStack(spacing: 4) {
                        Text(component.category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(component.score))")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(scoreColor(component.score))
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Insights")
                .font(.headline)
                .fontWeight(.semibold)
            
            if isLoading {
                ProgressView("Loading insights...")
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if insights.isEmpty {
                Text("No insights available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ForEach(insights.prefix(5), id: \.id) { insight in
                    InsightCard(insight: insight)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)
                .fontWeight(.semibold)
            
            if recommendations.isEmpty {
                Text("No recommendations available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                ForEach(recommendations.prefix(3), id: \.id) { recommendation in
                    RecommendationCard(recommendation: recommendation)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100:
            return .green
        case 60..<80:
            return .orange
        default:
            return .red
        }
    }
    
    private func loadAIData() async {
        isLoading = true
        errorMessage = ""
        
        do {
            // Load health score
            healthScore = try await fetchHealthScore()
            
            // Load insights
            insights = try await fetchInsights()
            
            // Load recommendations
            recommendations = try await fetchRecommendations()
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    private func fetchHealthScore() async throws -> HealthScore {
        guard let url = URL(string: "\(networkManager.baseURL)/ai/health-score") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(networkManager.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        return try JSONDecoder().decode(HealthScore.self, from: data)
    }
    
    private func fetchInsights() async throws -> [HealthInsight] {
        guard let url = URL(string: "\(networkManager.baseURL)/ai/insights") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(networkManager.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        return try JSONDecoder().decode([HealthInsight].self, from: data)
    }
    
    private func fetchRecommendations() async throws -> [Recommendation] {
        guard let url = URL(string: "\(networkManager.baseURL)/ai/recommendations") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(networkManager.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        
        return try JSONDecoder().decode([Recommendation].self, from: data)
    }
}

// MARK: - Supporting Views

struct InsightCard: View {
    let insight: HealthInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(insight.priority)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor(insight.priority))
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            
            Text(insight.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high":
            return .red
        case "medium":
            return .orange
        default:
            return .blue
        }
    }
}

struct RecommendationCard: View {
    let recommendation: Recommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(recommendation.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(recommendation.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Data Models

struct HealthScore: Codable {
    let overallScore: Double
    let componentScores: [ComponentScore]
    let timestamp: String
}

struct ComponentScore: Codable {
    let category: String
    let score: Double
    let description: String
}

struct HealthInsight: Codable {
    let id: String
    let title: String
    let description: String
    let priority: String
    let category: String
    let confidence: Double
    let timestamp: String
}

struct Recommendation: Codable {
    let id: String
    let title: String
    let description: String
    let category: String
    let confidence: Double
    let priority: String
}

#Preview {
    AIInsightsDashboardView()
} 