import Foundation
import SwiftUI

// MARK: - Connected Health App Models

struct ConnectedHealthApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let iconURL: String?
    let description: String
    let categories: [String]
    let isActive: Bool
    let lastSyncDate: Date
    let dataPointsCount: Int
    let recentDataPoints: [DataPoint]
    
    struct DataPoint {
        let type: String
        let value: String
        let timestamp: String
    }
}

// MARK: - Data Source Models

struct DataSource: Identifiable {
    let id = UUID()
    let name: String
    let type: DataSourceType
    let isConnected: Bool
    let lastSync: Date?
    let syncStatus: SyncConfiguration.SyncStatus
    let dataTypes: [String]
    let permissions: [PermissionType]
    let icon: String
    let color: Color
    let description: String
}

// MARK: - Data Source Priority Models

struct DataSourcePriority: Identifiable {
    let id = UUID()
    let sourceName: String
    let dataType: String
    let priority: Int
    let isEnabled: Bool
    let conflictResolution: ConflictResolution
    
    enum ConflictResolution: String, CaseIterable {
        case useFirst = "use_first"
        case useSecond = "use_second"
        case merge = "merge"
        case askUser = "ask_user"
        
        var displayName: String {
            switch self {
            case .useFirst: return "Use First Source"
            case .useSecond: return "Use Second Source"
            case .merge: return "Merge Data"
            case .askUser: return "Ask User"
            }
        }
    }
}

// MARK: - Sync Models

struct SyncConfiguration: Identifiable {
    let id = UUID()
    let sourceName: String
    let isEnabled: Bool
    let frequency: SyncFrequency
    let dataTypes: [String]
    let lastSync: Date?
    let nextSync: Date?
    let status: SyncStatus
    
    enum SyncFrequency: String, CaseIterable {
        case realTime = "real_time"
        case hourly = "hourly"
        case daily = "daily"
        case weekly = "weekly"
        case manual = "manual"
        
        var displayName: String {
            switch self {
            case .realTime: return "Real-time"
            case .hourly: return "Hourly"
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .manual: return "Manual"
            }
        }
    }
    
    enum SyncStatus: String {
        case idle = "idle"
        case syncing = "syncing"
        case success = "success"
        case error = "error"
        case paused = "paused"
        
        var displayName: String {
            switch self {
            case .idle: return "Ready"
            case .syncing: return "Syncing"
            case .success: return "Success"
            case .error: return "Error"
            case .paused: return "Paused"
            }
        }
        
        var color: String {
            switch self {
            case .idle: return "gray"
            case .syncing: return "blue"
            case .success: return "green"
            case .error: return "red"
            case .paused: return "orange"
            }
        }
    }
}

// MARK: - Data Conflict Models

struct DataConflict: Identifiable {
    let id = UUID()
    let dataType: String
    let timestamp: Date
    let conflictingSources: [ConflictingSource]
    let recommendedResolution: String
    let isResolved: Bool
    let resolvedBy: String?
    let resolvedAt: Date?
    
    struct ConflictingSource {
        let sourceName: String
        let value: String
        let confidence: Double
        let metadata: [String: String]
    }
}

// MARK: - Permission Models

struct AppPermission: Identifiable {
    let id = UUID()
    let appName: String
    let bundleIdentifier: String
    let permissions: [HealthPermission]
    let isEnabled: Bool
    let lastAccessed: Date?
    
    struct HealthPermission {
        let dataType: String
        let accessLevel: AccessLevel
        let isGranted: Bool
        
        enum AccessLevel: String, CaseIterable {
            case read = "read"
            case write = "write"
            case readWrite = "read_write"
            
            var displayName: String {
                switch self {
                case .read: return "Read"
                case .write: return "Write"
                case .readWrite: return "Read & Write"
                }
            }
        }
    }
}

// MARK: - Supporting Enums

enum DataSourceType: String, CaseIterable {
    case healthKit = "healthkit"
    case fitness = "fitness"
    case nutrition = "nutrition"
    case sleep = "sleep"
    case wearable = "wearable"
    case manual = "manual"
    
    var displayName: String {
        switch self {
        case .healthKit: return "Health Kit"
        case .fitness: return "Fitness App"
        case .nutrition: return "Nutrition App"
        case .sleep: return "Sleep Tracker"
        case .wearable: return "Wearable Device"
        case .manual: return "Manual Entry"
        }
    }
}

enum PermissionType: String, CaseIterable {
    case read = "read"
    case write = "write"
    case share = "share"
    
    var displayName: String {
        switch self {
        case .read: return "Read"
        case .write: return "Write"
        case .share: return "Share"
        }
    }
}