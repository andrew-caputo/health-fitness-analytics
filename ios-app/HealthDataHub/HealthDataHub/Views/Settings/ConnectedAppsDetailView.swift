import SwiftUI

struct ConnectedAppsDetailView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @EnvironmentObject var healthDataManager: HealthDataManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "app.connected.to.app.below.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    
                    Text("Connected Apps")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text(healthDataManager.isAuthorized ? "Connected" : "Not Connected")
                            .font(.subheadline)
                            .foregroundColor(healthDataManager.isAuthorized ? .green : .orange)
                        
                        Image(systemName: healthDataManager.isAuthorized ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(healthDataManager.isAuthorized ? .green : .orange)
                    }
                    
                    if !healthDataManager.isAuthorized {
                        Button("Enable HealthKit") {
                            healthDataManager.requestHealthKitPermissions()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                
                // Connected Apps List
                List {
                    if healthDataManager.connectedApps.isEmpty {
                        Text("No connected apps found")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(healthDataManager.connectedApps, id: \.self) { app in
                            HStack {
                                Image(systemName: "app.fill")
                                    .foregroundColor(.blue)
                                
                                Text(app)
                                
                                Spacer()
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Connected Apps")
            .onAppear {
                healthDataManager.updateConnectedApps()
            }
            .refreshable {
                healthDataManager.updateConnectedApps()
            }
        }
    }
}

#Preview {
    NavigationView {
        ConnectedAppsDetailView()
    }
} 