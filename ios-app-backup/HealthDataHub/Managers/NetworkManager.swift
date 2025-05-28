import Foundation
import Combine

@MainActor
class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var networkError: String?
    
    private let baseURL = "http://localhost:8001/api/v1"  // Updated for local backend on port 8001
    private var accessToken: String?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - User Model
    
    struct User: Codable {
        let id: Int
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
        let grant_type: String = "password"
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
        accessToken = nil
        UserDefaults.standard.removeObject(forKey: "access_token")
        UserDefaults.standard.removeObject(forKey: "user_data")
        
        // Update UI state
        isAuthenticated = false
        currentUser = nil
        
        // Optionally call backend logout endpoint
        do {
            let _: [String: String] = try await performRequest(
                endpoint: "/mobile/auth/logout",
                method: "POST",
                requiresAuth: true
            )
        } catch {
            print("Logout API call failed: \(error)")
        }
    }
    
    func refreshToken() async throws -> Bool {
        guard accessToken != nil else {
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
        guard accessToken != nil else {
            throw NetworkError.notAuthenticated
        }
        
        let response: [String: Any] = try await performRequest(
            endpoint: "/mobile/auth/verify",
            method: "GET",
            requiresAuth: true
        )
        
        return response["valid"] as? Bool ?? false
    }
    
    // MARK: - HealthKit Data Upload
    
    struct HealthKitMetric: Codable {
        let metric_type: String
        let value: Double
        let unit: String
        let source_type: String = "healthkit"
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
        let errors: [String]?
    }
    
    func getSyncStatus() async throws -> SyncStatus {
        return try await performRequest(
            endpoint: "/mobile/healthkit/sync-status",
            method: "GET",
            requiresAuth: true
        )
    }
    
    func triggerManualSync() async throws -> [String: Any] {
        return try await performRequest(
            endpoint: "/mobile/healthkit/sync",
            method: "POST",
            requiresAuth: true
        )
    }
    
    // MARK: - User Profile
    
    struct UserProfile: Codable {
        let id: Int
        let email: String
        let created_at: String?
        let total_metrics: Int
        let connected_sources: Int
        let last_sync: String?
        let healthkit_enabled: Bool
    }
    
    func getUserProfile() async throws -> UserProfile {
        return try await performRequest(
            endpoint: "/mobile/user/profile",
            method: "GET",
            requiresAuth: true
        )
    }
    
    // MARK: - Network Requests
    
    private func performRequest<T: Codable, U: Codable>(
        endpoint: String,
        method: String,
        body: U? = nil,
        requiresAuth: Bool = false
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth {
            guard let token = accessToken else {
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
        
        if httpResponse.statusCode == 401 {
            await logout()
            throw NetworkError.notAuthenticated
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw NetworkError.serverError(detail)
            }
            throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Decoding error: \(error)")
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
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw NetworkError.serverError(detail)
            }
            throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    // MARK: - Token Management
    
    private func handleAuthenticationSuccess(_ response: LoginResponse) async {
        accessToken = response.access_token
        currentUser = response.user
        isAuthenticated = true
        
        // Store token and user data
        UserDefaults.standard.set(response.access_token, forKey: "access_token")
        if let userData = try? JSONEncoder().encode(response.user) {
            UserDefaults.standard.set(userData, forKey: "user_data")
        }
    }
    
    private func loadStoredToken() {
        if let token = UserDefaults.standard.string(forKey: "access_token") {
            accessToken = token
            
            if let userData = UserDefaults.standard.data(forKey: "user_data"),
               let user = try? JSONDecoder().decode(User.self, from: userData) {
                currentUser = user
                isAuthenticated = true
                
                // Verify token is still valid
                Task {
                    do {
                        let isValid = try await verifyToken()
                        if !isValid {
                            await logout()
                        }
                    } catch {
                        await logout()
                    }
                }
            }
        }
    }
    
    // MARK: - Error Handling
    
    enum NetworkError: LocalizedError {
        case invalidURL
        case notAuthenticated
        case invalidResponse
        case decodingError
        case serverError(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .notAuthenticated:
                return "Not authenticated"
            case .invalidResponse:
                return "Invalid response"
            case .decodingError:
                return "Failed to decode response"
            case .serverError(let message):
                return message
            }
        }
    }
} 