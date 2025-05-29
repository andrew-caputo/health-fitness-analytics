import SwiftUI

struct LoginView: View {
    @StateObject private var networkManager = NetworkManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isRegistering = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // App Logo and Title
                    VStack(spacing: 16) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                        
                        Text("Health Data Hub")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Connect all your health apps in one place")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Login/Register Form
                    VStack(spacing: 20) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            TextField("Enter your email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            SecureField("Enter your password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // Confirm Password Field (only for registration)
                        if isRegistering {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Confirm Password")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                SecureField("Confirm your password", text: $confirmPassword)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        
                        // Action Button
                        Button(action: {
                            Task {
                                await handleAuthentication()
                            }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                
                                Text(isRegistering ? "Create Account" : "Sign In")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(isLoading || !isFormValid)
                        
                        // Toggle between login and register
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isRegistering.toggle()
                                clearForm()
                            }
                        }) {
                            Text(isRegistering ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 20)
                    
                    // Features Preview
                    if !isRegistering {
                        VStack(spacing: 16) {
                            Text("What you'll get:")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            VStack(spacing: 12) {
                                FeatureRow(icon: "heart.fill", title: "HealthKit Integration", description: "Access data from 100+ health apps")
                                FeatureRow(icon: "icloud.fill", title: "Automatic Sync", description: "Your data stays up to date")
                                FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "AI Insights", description: "Personalized health analytics")
                                FeatureRow(icon: "lock.fill", title: "Privacy First", description: "Your data stays secure")
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        if isRegistering {
            return !email.isEmpty && 
                   !password.isEmpty && 
                   !confirmPassword.isEmpty && 
                   password == confirmPassword &&
                   password.count >= 6 &&
                   email.contains("@")
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
    
    // MARK: - Methods
    
    private func handleAuthentication() async {
        isLoading = true
        errorMessage = ""
        
        do {
            if isRegistering {
                guard password == confirmPassword else {
                    throw AuthError.passwordMismatch
                }
                
                guard password.count >= 6 else {
                    throw AuthError.passwordTooShort
                }
                
                _ = try await networkManager.register(email: email, password: password)
            } else {
                _ = try await networkManager.login(email: email, password: password)
            }
            
            // Success - the app will automatically navigate due to authentication state change
            
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
    
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        errorMessage = ""
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case passwordMismatch
    case passwordTooShort
    
    var errorDescription: String? {
        switch self {
        case .passwordMismatch:
            return "Passwords don't match"
        case .passwordTooShort:
            return "Password must be at least 6 characters"
        }
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
} 