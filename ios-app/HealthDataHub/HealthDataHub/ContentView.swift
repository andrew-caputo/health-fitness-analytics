import SwiftUI

struct ContentView: View {
    @State private var connectionStatus = "Not tested"
    @State private var isConnecting = false
    @State private var backendResponse: String = ""
    @State private var authToken: String = ""
    @State private var isAuthenticated = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 60))
                    
                    Text("Health Data Hub")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Backend Connectivity Test")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Connection Status
                VStack(spacing: 15) {
                    HStack {
                        Image(systemName: connectionStatus == "Connected" ? "checkmark.circle.fill" : 
                              connectionStatus == "Failed" ? "xmark.circle.fill" : "circle")
                            .foregroundColor(connectionStatus == "Connected" ? .green : 
                                           connectionStatus == "Failed" ? .red : .gray)
                        
                        Text("Backend Status: \(connectionStatus)")
                            .font(.headline)
                    }
                    
                    if isConnecting {
                        ProgressView("Testing connection...")
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
                
                // Test Buttons
                VStack(spacing: 15) {
                    Button(action: testHealthEndpoint) {
                        HStack {
                            Image(systemName: "stethoscope")
                            Text("Test Health Endpoint")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isConnecting)
                    
                    Button(action: testAuthentication) {
                        HStack {
                            Image(systemName: "key.fill")
                            Text("Test Authentication")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isConnecting)
                    
                    if isAuthenticated {
                        Button(action: testProtectedEndpoint) {
                            HStack {
                                Image(systemName: "lock.shield")
                                Text("Test Protected Endpoint")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isConnecting)
                    }
                }
                
                // Response Display
                if !backendResponse.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Backend Response:")
                                .font(.headline)
                            
                            Text(backendResponse)
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    .frame(maxHeight: 200)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Connectivity Test")
        }
    }
    
    private func testHealthEndpoint() {
        isConnecting = true
        connectionStatus = "Testing..."
        backendResponse = ""
        
        guard let url = URL(string: "http://localhost:8001/health") else {
            connectionStatus = "Failed"
            backendResponse = "Invalid URL"
            isConnecting = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isConnecting = false
                
                if let error = error {
                    connectionStatus = "Failed"
                    backendResponse = "Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        connectionStatus = "Connected"
                        if let data = data,
                           let jsonString = String(data: data, encoding: .utf8) {
                            backendResponse = "Status: \(httpResponse.statusCode)\n\nResponse:\n\(jsonString)"
                        } else {
                            backendResponse = "Status: \(httpResponse.statusCode)\n\nNo data received"
                        }
                    } else {
                        connectionStatus = "Failed"
                        backendResponse = "HTTP Status: \(httpResponse.statusCode)"
                    }
                } else {
                    connectionStatus = "Failed"
                    backendResponse = "Invalid response"
                }
            }
        }.resume()
    }
    
    private func testAuthentication() {
        isConnecting = true
        backendResponse = ""
        
        guard let url = URL(string: "http://localhost:8001/api/v1/auth/login") else {
            backendResponse = "Invalid URL"
            isConnecting = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let formData = "username=test@healthanalytics.com&password=testpassword123"
        request.httpBody = formData.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isConnecting = false
                
                if let error = error {
                    backendResponse = "Auth Error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        if let data = data,
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let token = json["access_token"] as? String {
                            authToken = token
                            isAuthenticated = true
                            backendResponse = "Authentication successful!\n\nToken received: \(String(token.prefix(20)))..."
                        } else {
                            backendResponse = "Status: \(httpResponse.statusCode)\n\nNo token received"
                        }
                    } else {
                        backendResponse = "Auth failed with status: \(httpResponse.statusCode)"
                        if let data = data,
                           let errorString = String(data: data, encoding: .utf8) {
                            backendResponse += "\n\nError: \(errorString)"
                        }
                    }
                }
            }
        }.resume()
    }
    
    private func testProtectedEndpoint() {
        isConnecting = true
        backendResponse = ""
        
        guard let url = URL(string: "http://localhost:8001/api/v1/users/me") else {
            backendResponse = "Invalid URL"
            isConnecting = false
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isConnecting = false
                
                if let error = error {
                    backendResponse = "Protected endpoint error: \(error.localizedDescription)"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        if let data = data,
                           let jsonString = String(data: data, encoding: .utf8) {
                            backendResponse = "Protected endpoint success!\n\nUser data:\n\(jsonString)"
                        } else {
                            backendResponse = "Status: \(httpResponse.statusCode)\n\nNo data received"
                        }
                    } else {
                        backendResponse = "Protected endpoint failed: \(httpResponse.statusCode)"
                        if let data = data,
                           let errorString = String(data: data, encoding: .utf8) {
                            backendResponse += "\n\nError: \(errorString)"
                        }
                    }
                }
            }
        }.resume()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 