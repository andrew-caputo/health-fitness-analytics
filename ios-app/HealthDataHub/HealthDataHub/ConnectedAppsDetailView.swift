import SwiftUI

struct ConnectedAppsDetailView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    
    var body: some View {
        List {
            Section("HealthKit Integration") {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading) {
                        Text("Apple HealthKit")
                            .font(.headline)
                        
                        Text(healthKitManager.isAuthorized ? "Connected" : "Not Connected")
                            .font(.caption)
                            .foregroundColor(healthKitManager.isAuthorized ? .green : .orange)
                    }
                    
                    Spacer()
                    
                    if !healthKitManager.isAuthorized {
                        Button("Connect") {
                            healthKitManager.requestHealthKitPermissions()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            
            Section("Connected Health Apps") {
                if healthKitManager.connectedApps.isEmpty {
                    Text("No connected apps found")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(healthKitManager.connectedApps, id: \.self) { app in
                        HStack {
                            Image(systemName: "app.fill")
                                .foregroundColor(.blue)
                            
                            Text(app)
                                .font(.headline)
                            
                            Spacer()
                            
                            Text("Connected")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
            }
            
            Section {
                Button("Refresh Connected Apps") {
                    healthKitManager.fetchConnectedApps()
                }
            }
        }
        .navigationTitle("Connected Apps")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            healthKitManager.fetchConnectedApps()
        }
    }
}

#Preview {
    NavigationView {
        ConnectedAppsDetailView()
    }
} 