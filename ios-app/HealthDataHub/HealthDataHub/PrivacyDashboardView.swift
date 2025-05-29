import SwiftUI

struct PrivacyDashboardView: View {
    var body: some View {
        List {
            Section("Data Privacy") {
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading) {
                        Text("Data Encryption")
                            .font(.headline)
                        
                        Text("All your health data is encrypted and secure")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Image(systemName: "eye.slash.fill")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("Private by Design")
                            .font(.headline)
                        
                        Text("Your data is never shared without permission")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Data Controls") {
                NavigationLink("Data Retention Settings") {
                    Text("Data Retention Settings")
                }
                
                NavigationLink("Data Export") {
                    Text("Export Your Data")
                }
                
                NavigationLink("Delete Account") {
                    Text("Delete Account")
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        PrivacyDashboardView()
    }
} 