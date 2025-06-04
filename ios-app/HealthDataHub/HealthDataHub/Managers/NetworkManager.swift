import Foundation
import UIKit
import Combine

class NetworkManager: ObservableObject {
    static let shared = NetworkManager()
    
    @Published var isOnline = true
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    private let baseURL = "http://192.168.2.120:8001"
    private var session: URLSession
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Configure URLSession with proper timeouts to prevent app freezing
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0 // 10 second timeout for requests
        config.timeoutIntervalForResource = 30.0 // 30 second timeout for entire resource
        config.waitsForConnectivity = false // Don't wait indefinitely for network
        
        self.session = URLSession(configuration: config)
        startNetworkMonitoring()
    }
    
    private func startNetworkMonitoring() {
        // Network monitoring implementation
    }
    
    // MARK: - Generic Request Method
    
    func request<T: Codable, U: Codable>(
        endpoint: String,
        method: HTTPMethod,
        body: T? = nil
    ) async throws -> U {
        let url = URL(string: baseURL + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(U.self, from: data)
    }
    
    // MARK: - Request Method Without Body (for GET/DELETE)
    
    func requestWithoutBody<T: Codable>(
        endpoint: String,
        method: HTTPMethod
    ) async throws -> T {
        let url = URL(string: baseURL + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Explicitly do NOT set httpBody for GET/DELETE requests
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                // Try to extract error message from response
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    print("API Error: \(detail)")
                }
                throw NetworkError.httpError(httpResponse.statusCode)
            }
            
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Network request failed for \(endpoint): \(error)")
            throw error
        }
    }
    
    // MARK: - Form Request Method for OAuth2
    
    func performFormRequest<T: Codable>(
        endpoint: String,
        formData: [String: String]
    ) async throws -> T {
        let url = URL(string: baseURL + endpoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Properly URL encode the form data
        let formString = formData.compactMap { key, value in
            guard let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return nil
            }
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        
        request.httpBody = formString.data(using: .utf8)
        
        print("🔐 Making login request to: \(url)")
        print("🔐 Form data: \(formString)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw NetworkError.invalidResponse
            }
            
            print("🔐 Login response status: \(httpResponse.statusCode)")
            
            guard 200...299 ~= httpResponse.statusCode else {
                // Try to extract error message from response
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let detail = errorData["detail"] as? String {
                    print("❌ API Error: \(detail)")
                    throw NetworkError.httpError(httpResponse.statusCode)
                }
                print("❌ HTTP Error: \(httpResponse.statusCode)")
                throw NetworkError.httpError(httpResponse.statusCode)
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "Invalid UTF-8"
            print("✅ Login response: \(responseString)")
            
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("❌ Network request failed for \(endpoint): \(error)")
            throw error
        }
    }
    
    // MARK: - Authentication Methods
    
    func login(email: String, password: String) async throws -> String {
        // Use form data for OAuth2 compatibility
        let formData = [
            "username": email,  // FastAPI OAuth2 uses 'username' field
            "password": password,
            "grant_type": "password"
        ]
        
        struct LoginResponse: Codable {
            let access_token: String
            let token_type: String
        }
        
        let response: LoginResponse = try await performFormRequest(
            endpoint: "/api/v1/auth/login",
            formData: formData
        )
        
        // Store token
        try storeToken(response.access_token, key: "access_token")
        
        await MainActor.run { // Ensure UI update is on main thread
            self.isAuthenticated = true
        }
        // We should also fetch the user profile here and set self.currentUser
        // For now, just returning token as per original logic
        return response.access_token
    }
    
    func logout() async throws {
        // Clear stored tokens locally
        clearTokens()

        // Invalidate the current session and cancel its tasks
        session.invalidateAndCancel()
        
        // Create a new, pristine URLSessionConfiguration instance
        let newConfiguration = URLSessionConfiguration.default
        // Optionally: You could further customize newConfiguration here if needed, e.g.:
        // newConfiguration.timeoutIntervalForRequest = 30 // seconds
        // newConfiguration.waitsForConnectivity = true
        // newConfiguration.urlCache = nil // Explicitly clear cache for the new configuration
        // newConfiguration.httpCookieStorage = nil // Explicitly clear cookies for the new configuration
        
        // Create a new URLSession instance with the fresh configuration
        self.session = URLSession(configuration: newConfiguration)

        // Update published properties on the main thread
        await MainActor.run {
            isAuthenticated = false
            currentUser = nil
        }
        
        // Note: Backend doesn't have a formal logout endpoint for session invalidation,
        // so we just clear local state and fully reset the URL session and its configuration.
    }
    
    func verifyToken() async throws -> Bool {
        // For now, just check if we have a token stored
        // In a production app, you'd want to verify with the server
        guard let token = getAuthToken(), !token.isEmpty else {
            return false
        }
        
        // Try a simple authenticated request to verify token
        do {
            // Use the health endpoint to verify token validity
            let url = URL(string: baseURL + "/health")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }
            
            return 200...299 ~= httpResponse.statusCode
        } catch {
            return false
        }
    }
    
    func register(email: String, password: String, name: String) async throws -> String {
        struct RegisterRequest: Codable {
            let email: String
            let password: String
        }
        
        struct RegisterResponse: Codable {
            let id: String
            let email: String
            let created_at: String?
        }
        
        let registerRequest = RegisterRequest(email: email, password: password)
        let _: RegisterResponse = try await request(
            endpoint: "/api/v1/auth/register",
            method: .POST,
            body: registerRequest
        )
        
        // After successful registration, log the user in
        return try await login(email: email, password: password)
    }
    
    // MARK: - Data Methods
    
    func uploadHealthData<T: Codable>(_ data: T) async throws {
        let requestData = HealthDataRequest(
            data: data,
            timestamp: Date(),
            source: "ios_app"
        )
        
        let _: UploadResponse = try await request(
            endpoint: "/data/upload",
            method: .POST,
            body: requestData
        )
    }
    
    func syncData() async throws {
        let requestData = SyncRequest(deviceId: getDeviceId())
        
        let _: SyncResponse = try await request(
            endpoint: "/data/sync",
            method: .POST,
            body: requestData
        )
    }
    
    func uploadHealthKitData(_ metrics: [HealthDataMapper.HealthMetricUnified]) async throws -> BatchUploadResponse {
        let requestData = BatchHealthDataRequest(metrics: metrics)
        
        let response: BatchUploadResponse = try await request(
            endpoint: "/data/batch-upload",
            method: .POST,
            body: requestData
        )
        
        return response
    }
    
    // MARK: - Data Source Preferences Methods
    
    func getAvailableDataSources() async throws -> [PreferenceDataSource] {
        let response: [PreferenceDataSource] = try await requestWithoutBody(
            endpoint: "/api/v1/preferences/available-sources",
            method: .GET
        )
        return response
    }
    
    func getUserDataSourcePreferences() async throws -> UserPreferencesResponse {
        let response: UserPreferencesResponse = try await requestWithoutBody(
            endpoint: "/api/v1/preferences/",
            method: .GET
        )
        return response
    }
    
    func updateUserDataSourcePreferences(_ preferences: UserDataSourcePreferences) async throws -> UserDataSourcePreferences {
        let response: UserDataSourcePreferences = try await request(
            endpoint: "/api/v1/preferences/",
            method: .PUT,
            body: preferences
        )
        return response
    }
    
    func createUserDataSourcePreferences(_ preferences: UserDataSourcePreferences) async throws -> UserDataSourcePreferences {
        let response: UserDataSourcePreferences = try await request(
            endpoint: "/api/v1/preferences/",
            method: .POST,
            body: preferences
        )
        return response
    }
    
    func getCategorySourceInfo(category: HealthCategory) async throws -> CategorySourceInfo {
        let response: CategorySourceInfo = try await requestWithoutBody(
            endpoint: "/api/v1/preferences/category/\(category.rawValue)/sources",
            method: .GET
        )
        return response
    }
    
    func setPreferredSourceForCategory(category: HealthCategory, sourceName: String) async throws {
        let _: EmptyResponse = try await requestWithoutBody(
            endpoint: "/api/v1/preferences/category/\(category.rawValue)/set-preferred?source_name=\(sourceName)",
            method: .POST
        )
    }
    
    func deleteUserDataSourcePreferences() async throws {
        let _: EmptyResponse = try await requestWithoutBody(
            endpoint: "/api/v1/preferences/",
            method: .DELETE
        )
    }
    
    // MARK: - Helper Methods
    
    private func getAuthToken() -> String? {
        return KeychainManager.shared.getToken(for: "access_token")
    }
    
    private func storeToken(_ token: String, key: String) throws {
        try KeychainManager.shared.storeToken(token, for: key)
    }
    
    private func clearTokens() {
        KeychainManager.shared.deleteToken(for: "access_token")
        KeychainManager.shared.deleteToken(for: "refresh_token")
    }
    
    private func getDeviceId() -> String {
        if let deviceId = UserDefaults.standard.string(forKey: "device_id") {
            return deviceId
        }
        
        let newDeviceId = UUID().uuidString
        UserDefaults.standard.set(newDeviceId, forKey: "device_id")
        return newDeviceId
    }
    
    // MARK: - Data Source API Methods
    
    // CRITICAL: These methods replace the mock data generation with real backend API calls
    
    // Withings API methods
    func fetchWithingsActivityData(startDate: Date, endDate: Date) async throws -> ActivityDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let endpoint = "/api/v1/data-sources/withings/activity?start_date=\(dateFormatter.string(from: startDate))&end_date=\(dateFormatter.string(from: endDate))"
        return try await requestWithoutBody(endpoint: endpoint, method: .GET)
    }
    
    func fetchWithingsSleepData(startDate: Date, endDate: Date) async throws -> SleepDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let endpoint = "/api/v1/data-sources/withings/sleep?start_date=\(dateFormatter.string(from: startDate))&end_date=\(dateFormatter.string(from: endDate))"
        return try await requestWithoutBody(endpoint: endpoint, method: .GET)
    }
    
    func fetchWithingsHeartRateData(startDate: Date, endDate: Date) async throws -> HeartRateDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let endpoint = "/api/v1/data-sources/withings/heart-rate?start_date=\(dateFormatter.string(from: startDate))&end_date=\(dateFormatter.string(from: endDate))"
        return try await requestWithoutBody(endpoint: endpoint, method: .GET)
    }
    
    func fetchWithingsBodyCompositionData(startDate: Date, endDate: Date) async throws -> BodyCompositionDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let endpoint = "/api/v1/data-sources/withings/body-composition?start_date=\(dateFormatter.string(from: startDate))&end_date=\(dateFormatter.string(from: endDate))"
        return try await requestWithoutBody(endpoint: endpoint, method: .GET)
    }
    
    // Oura API methods
    func fetchOuraActivityData(startDate: Date, endDate: Date) async throws -> ActivityDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let endpoint = "/api/v1/data-sources/oura/activity?start_date=\(dateFormatter.string(from: startDate))&end_date=\(dateFormatter.string(from: endDate))"
        return try await requestWithoutBody(endpoint: endpoint, method: .GET)
    }
    
    func fetchOuraSleepData(startDate: Date, endDate: Date) async throws -> SleepDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let endpoint = "/api/v1/data-sources/oura/sleep?start_date=\(dateFormatter.string(from: startDate))&end_date=\(dateFormatter.string(from: endDate))"
        return try await requestWithoutBody(endpoint: endpoint, method: .GET)
    }
    
    func fetchOuraHeartRateData(startDate: Date, endDate: Date) async throws -> HeartRateDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let endpoint = "/api/v1/data-sources/oura/heart-rate?start_date=\(dateFormatter.string(from: startDate))&end_date=\(dateFormatter.string(from: endDate))"
        return try await requestWithoutBody(endpoint: endpoint, method: .GET)
    }
    
    // Fitbit API methods
    func fetchFitbitActivityData(startDate: Date, endDate: Date) async throws -> ActivityDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let endpoint = "/api/v1/data-sources/fitbit/activity?start_date=\(dateFormatter.string(from: startDate))&end_date=\(dateFormatter.string(from: endDate))"
        return try await requestWithoutBody(endpoint: endpoint, method: .GET)
    }
    
    func fetchFitbitSleepData(startDate: Date, endDate: Date) async throws -> SleepDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let endpoint = "/api/v1/data-sources/fitbit/sleep?start_date=\(dateFormatter.string(from: startDate))&end_date=\(dateFormatter.string(from: endDate))"
        return try await requestWithoutBody(endpoint: endpoint, method: .GET)
    }
    
    func fetchFitbitHeartRateData(startDate: Date, endDate: Date) async throws -> HeartRateDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let endpoint = "/api/v1/data-sources/fitbit/heart-rate?start_date=\(dateFormatter.string(from: startDate))&end_date=\(dateFormatter.string(from: endDate))"
        return try await requestWithoutBody(endpoint: endpoint, method: .GET)
    }
    
    func fetchFitbitBodyCompositionData(startDate: Date, endDate: Date) async throws -> BodyCompositionDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let endpoint = "/api/v1/data-sources/fitbit/body-composition?start_date=\(dateFormatter.string(from: startDate))&end_date=\(dateFormatter.string(from: endDate))"
        return try await requestWithoutBody(endpoint: endpoint, method: .GET)
    }
    
    // WHOOP API methods
    func fetchWhoopActivityData(startDate: Date, endDate: Date) async throws -> ActivityDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let endpoint = "/api/v1/data-sources/whoop/activity?start_date=\(dateFormatter.string(from: startDate))&end_date=\(dateFormatter.string(from: endDate))"
        return try await requestWithoutBody(endpoint: endpoint, method: .GET)
    }
    
    func fetchWhoopSleepData(startDate: Date, endDate: Date) async throws -> SleepDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let endpoint = "/api/v1/data-sources/whoop/sleep?start_date=\(dateFormatter.string(from: startDate))&end_date=\(dateFormatter.string(from: endDate))"
        return try await requestWithoutBody(endpoint: endpoint, method: .GET)
    }
    
    func fetchWhoopHeartRateData(startDate: Date, endDate: Date) async throws -> HeartRateDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let endpoint = "/api/v1/data-sources/whoop/heart-rate?start_date=\(dateFormatter.string(from: startDate))&end_date=\(dateFormatter.string(from: endDate))"
        return try await requestWithoutBody(endpoint: endpoint, method: .GET)
    }
    
    func fetchWhoopBodyCompositionData(startDate: Date, endDate: Date) async throws -> BodyCompositionDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let endpoint = "/api/v1/data-sources/whoop/body-composition?start_date=\(dateFormatter.string(from: startDate))&end_date=\(dateFormatter.string(from: endDate))"
        return try await requestWithoutBody(endpoint: endpoint, method: .GET)
    }
    
    // Strava API methods
    func fetchStravaActivityData(startDate: Date, endDate: Date) async throws -> ActivityDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let endpoint = "/api/v1/data-sources/strava/activity?start_date=\(dateFormatter.string(from: startDate))&end_date=\(dateFormatter.string(from: endDate))"
        return try await requestWithoutBody(endpoint: endpoint, method: .GET)
    }
    
    func fetchStravaHeartRateData(startDate: Date, endDate: Date) async throws -> HeartRateDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let endpoint = "/api/v1/data-sources/strava/heart-rate?start_date=\(dateFormatter.string(from: startDate))&end_date=\(dateFormatter.string(from: endDate))"
        return try await requestWithoutBody(endpoint: endpoint, method: .GET)
    }
    
    // FatSecret API methods
    func fetchFatSecretNutritionData(startDate: Date, endDate: Date) async throws -> NutritionDataResponse {
        let dateFormatter = ISO8601DateFormatter()
        let endpoint = "/api/v1/data-sources/fatsecret/nutrition?start_date=\(dateFormatter.string(from: startDate))&end_date=\(dateFormatter.string(from: endDate))"
        return try await requestWithoutBody(endpoint: endpoint, method: .GET)
    }
}

// MARK: - Supporting Types

struct EmptyRequest: Codable {}

struct HealthDataRequest<T: Codable>: Codable {
    let data: T
    let timestamp: Date
    let source: String
}

struct UploadResponse: Codable {
    let success: Bool
}

struct SyncRequest: Codable {
    let deviceId: String
}

struct SyncResponse: Codable {
    let success: Bool
}

struct BatchHealthDataRequest: Codable {
    let metrics: [HealthDataMapper.HealthMetricUnified]
}

struct BatchUploadResponse: Codable {
    let processed_count: Int
    let failed_count: Int
    let sync_id: String
    let errors: [String]?
}

struct User: Codable {
    let id: String
    let email: String
    let name: String
    let createdAt: String
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case encodingError(Error)
    case noData
    case unauthorized
    case networkUnavailable
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        case .unauthorized:
            return "Unauthorized access"
        case .networkUnavailable:
            return "Network unavailable"
        }
    }
}

// MARK: - Keychain Manager

class KeychainManager {
    static let shared = KeychainManager()
    private init() {}
    
    func storeToken(_ token: String, for key: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToStore
        }
    }
    
    func getToken(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    func deleteToken(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: Error {
    case unableToStore
    case unableToRetrieve
    case unableToDelete
}

// MARK: - Data Source API Response Models

struct ActivityDataResponse: Codable {
    let steps: Int?
    let activeCalories: Int?
    let distance: Double?
    let source: String?
    let timestamp: Date?
}

struct SleepDataResponse: Codable {
    let sleepDuration: TimeInterval?
    let deepSleep: TimeInterval?
    let lightSleep: TimeInterval?
    let remSleep: TimeInterval?
    let source: String?
    let timestamp: Date?
}

struct HeartRateDataResponse: Codable {
    let heartRate: Int?
    let restingHeartRate: Int?
    let maxHeartRate: Int?
    let source: String?
    let timestamp: Date?
}

struct NutritionDataResponse: Codable {
    let calories: Int?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let source: String?
    let timestamp: Date?
}

struct BodyCompositionDataResponse: Codable {
    let weight: Double?
    let bodyFat: Double?
    let muscleMass: Double?
    let bmi: Double?
    let source: String?
    let timestamp: Date?
    let dataPoints: [BodyCompositionDataPoint]?
}

struct BodyCompositionDataPoint: Codable {
    let metric: String
    let value: Double
    let unit: String
    let timestamp: Date
} 