import Foundation
import Combine
import UIKit

@MainActor
class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var networkError: String?
    
    let baseURL = "http://localhost:8001/api/v1"  // Made public for access from other views
    var accessToken: String? {  // Made public for access from other views
        get { _accessToken }
    }
    private var _accessToken: String?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - User Model
    
    struct User: Codable {
        let id: String
        let email: String
        let created_at: String?
    }
    
    struct LoginResponse: Codable {
        let access_token: String
        let token_type: String
        let expires_in: Int
        let user: User
    }
    
    struct RegisterRequest: Codable {
        let email: String
        let password: String
    }
    
    struct LoginRequest: Codable {
        let username: String  // FastAPI OAuth2 uses 'username' field
        let password: String
        var grant_type: String = "password"
    }
    
    // MARK: - Error Response Model
    
    struct APIErrorResponse: Codable {
        let detail: String
        let correlation_id: String?
    }
    
    // MARK: - Initialization
    
    private init() {
        loadStoredToken()
    }
    
    // MARK: - Authentication
    
    func register(email: String, password: String) async throws -> Bool {
        let request = RegisterRequest(email: email, password: password)
        
        let response: LoginResponse = try await performRequest(
            endpoint: "/mobile/auth/register",
            method: "POST",
            body: request,
            requiresAuth: false
        )
        
        await handleAuthenticationSuccess(response)
        return true
    }
    
    func login(email: String, password: String) async throws -> Bool {
        let loginData = [
            "username": email,
            "password": password,
            "grant_type": "password"
        ]
        
        let response: LoginResponse = try await performFormRequest(
            endpoint: "/mobile/auth/login",
            formData: loginData
        )
        
        await handleAuthenticationSuccess(response)
        return true
    }
    
    func logout() async {
        // Clear stored token
        _accessToken = nil
        UserDefaults.standard.removeObject(forKey: "access_token")
        UserDefaults.standard.removeObject(forKey: "user_data")
        
        // Update UI state
        isAuthenticated = false
        currentUser = nil
        
        // Optionally call backend logout endpoint
        do {
            struct LogoutResponse: Codable {
                let success: Bool
            }
            
            let _: LogoutResponse = try await performRequest(
                endpoint: "/mobile/auth/logout",
                method: "POST",
                requiresAuth: true
            )
        } catch {
            print("Logout API call failed: \(error)")
        }
    }
    
    func refreshToken() async throws -> Bool {
        guard _accessToken != nil else {
            throw NetworkError.notAuthenticated
        }
        
        let response: LoginResponse = try await performRequest(
            endpoint: "/mobile/auth/refresh",
            method: "POST",
            requiresAuth: true
        )
        
        await handleAuthenticationSuccess(response)
        return true
    }
    
    func verifyToken() async throws -> Bool {
        guard _accessToken != nil else {
            throw NetworkError.notAuthenticated
        }
        
        struct TokenVerifyResponse: Codable {
            let valid: Bool
        }
        
        let response: TokenVerifyResponse = try await performRequest(
            endpoint: "/mobile/auth/verify",
            method: "GET",
            requiresAuth: true
        )
        
        return response.valid
    }
    
    // MARK: - HealthKit Data Upload
    
    struct HealthKitMetric: Codable {
        let metric_type: String
        let value: Double
        let unit: String
        var source_type: String = "healthkit"
        let recorded_at: String
        let source_app: String?
        let device_name: String?
        let metadata: [String: String]?
    }
    
    struct HealthKitBatchUpload: Codable {
        let metrics: [HealthKitMetric]
        let device_info: [String: String]?
        let sync_timestamp: String
    }
    
    struct BatchUploadResponse: Codable {
        let sync_id: String
        let status: String
        let processed_count: Int
        let failed_count: Int
        let total_count: Int
        let errors: [String]?
        let next_sync_recommended: String
    }
    
    func uploadHealthKitData(_ metrics: [HealthDataMapper.HealthMetricUnified]) async throws -> BatchUploadResponse {
        let healthKitMetrics = metrics.map { metric in
            HealthKitMetric(
                metric_type: metric.metricType,
                value: metric.value,
                unit: metric.unit,
                recorded_at: ISO8601DateFormatter().string(from: metric.recordedAt),
                source_app: metric.sourceApp,
                device_name: metric.deviceName,
                metadata: metric.metadata as? [String: String]
            )
        }
        
        let deviceInfo = [
            "ios_version": UIDevice.current.systemVersion,
            "device_model": UIDevice.current.model,
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ]
        
        let uploadData = HealthKitBatchUpload(
            metrics: healthKitMetrics,
            device_info: deviceInfo,
            sync_timestamp: ISO8601DateFormatter().string(from: Date())
        )
        
        return try await performRequest(
            endpoint: "/mobile/healthkit/batch-upload",
            method: "POST",
            body: uploadData,
            requiresAuth: true
        )
    }
    
    // MARK: - Sync Status
    
    struct SyncStatus: Codable {
        let status: String
        let processed_count: Int
        let failed_count: Int
        let last_sync: String?
        let next_sync_recommended: String?
    }
    
    func getSyncStatus() async throws -> SyncStatus {
        return try await performRequest(
            endpoint: "/mobile/sync/status",
            method: "GET",
            requiresAuth: true
        )
    }
    
    // MARK: - Helper Methods
    
    private func loadStoredToken() {
        if let token = UserDefaults.standard.string(forKey: "access_token") {
            _accessToken = token
            isAuthenticated = true
            
            // Load user data
            if let userData = UserDefaults.standard.data(forKey: "user_data"),
               let user = try? JSONDecoder().decode(User.self, from: userData) {
                currentUser = user
            }
        }
    }
    
    private func handleAuthenticationSuccess(_ response: LoginResponse) async {
        _accessToken = response.access_token
        currentUser = response.user
        isAuthenticated = true
        
        // Store token and user data
        UserDefaults.standard.set(response.access_token, forKey: "access_token")
        if let userData = try? JSONEncoder().encode(response.user) {
            UserDefaults.standard.set(userData, forKey: "user_data")
        }
    }
    
    private func performRequest<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: Codable? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth {
            guard let token = _accessToken else {
                throw NetworkError.notAuthenticated
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            // Try to decode error response for better error messages
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw NetworkError.apiError(errorResponse.detail)
            }
            
            if httpResponse.statusCode == 401 {
                await logout()
                throw NetworkError.notAuthenticated
            }
            throw NetworkError.serverError(httpResponse.statusCode)
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }
    
    private func performFormRequest<T: Codable>(
        endpoint: String,
        formData: [String: String]
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let formString = formData.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        request.httpBody = formString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            // Try to decode error response for better error messages
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw NetworkError.apiError(errorResponse.detail)
            }
            
            if httpResponse.statusCode == 401 {
                throw NetworkError.notAuthenticated
            }
            throw NetworkError.serverError(httpResponse.statusCode)
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }
}

// MARK: - Error Types

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case notAuthenticated
    case invalidResponse
    case serverError(Int)
    case decodingError
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
} 