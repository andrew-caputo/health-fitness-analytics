import Foundation
import SwiftUI

@MainActor
class MainDashboardViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var dashboardData: DashboardData?
    @Published var lastRefreshed: Date = Date()
    
    init() {
        loadDashboardData()
    }
    
    func loadDashboardData() {
        // Stub implementation - load sample dashboard data
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.dashboardData = DashboardData(
                greeting: self.getGreeting(),
                todaySteps: 8532,
                sleepHours: 7.4,
                heartRate: 72,
                activeCalories: 425
            )
            self.lastRefreshed = Date()
            self.isLoading = false
        }
    }
    
    func refreshDashboard() {
        loadDashboardData()
    }
    
    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<22:
            return "Good evening"
        default:
            return "Good night"
        }
    }
}

struct DashboardData {
    let greeting: String
    let todaySteps: Int
    let sleepHours: Double
    let heartRate: Int
    let activeCalories: Int
} 