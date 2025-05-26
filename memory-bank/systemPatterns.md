# System Patterns

## Architecture Overview

### Frontend Architecture
```
src/
├── components/
│   ├── common/
│   ├── dashboard/
│   ├── charts/
│   ├── data-sources/
│   └── ai-assistant/
├── hooks/
├── services/
│   ├── api/
│   ├── auth/
│   └── data-sources/
├── store/
│   ├── user/
│   ├── health-data/
│   └── preferences/
└── utils/
```

### Backend Architecture
```
backend/
├── api/
│   ├── v1/
│   │   ├── endpoints/
│   │   │   ├── data_sources/
│   │   │   │   ├── apple_health/
│   │   │   │   ├── withings/
│   │   │   │   ├── oura/
│   │   │   │   ├── myfitnesspal/
│   │   │   │   ├── fitbit/
│   │   │   │   ├── strava/
│   │   │   │   ├── whoop/
│   │   │   │   ├── cronometer/
│   │   │   │   └── csv/
│   │   │   ├── auth/
│   │   │   ├── users/
│   │   │   ├── health_metrics/
│   │   │   └── preferences/
│   │   ├── middleware/
│   │   └── validators/
├── core/
│   ├── data_sources/
│   │   ├── common/
│   │   ├── apple_health/
│   │   ├── withings/
│   │   ├── oura/
│   │   ├── myfitnesspal/
│   │   ├── fitbit/
│   │   ├── strava/
│   │   ├── whoop/
│   │   ├── cronometer/
│   │   └── csv/
│   ├── services/
│   │   ├── aggregation/
│   │   ├── sync/
│   │   └── preferences/
│   ├── models/
│   └── utils/
├── data/
│   ├── collectors/
│   ├── processors/
│   ├── aggregators/
│   └── analyzers/
└── ai/
    ├── models/
    ├── prompts/
    └── processors/
```

### Mobile App Architecture (iOS)
```
iOS/
├── Views/
│   ├── Dashboard/
│   ├── DataSources/
│   ├── Settings/
│   └── Onboarding/
├── Services/
│   ├── HealthKit/
│   ├── API/
│   └── Sync/
├── Models/
│   ├── HealthData/
│   ├── User/
│   └── Preferences/
└── Utils/
```

## Design Patterns

### Multi-Source Data Integration Patterns

1. **Data Source Abstraction**
   - Common interface for all data sources
   - Standardized data models across sources
   - Unified authentication flow pattern
   - Consistent error handling

2. **User Preference Management**
   - Category-based source selection
   - Priority and fallback configuration
   - Real-time preference updates
   - Conflict resolution rules

3. **Data Aggregation Strategy**
   - Primary/secondary source hierarchy
   - Data quality scoring
   - Temporal conflict resolution
   - Cross-source validation

### Frontend Patterns
1. **Component Composition**
   - Atomic design principles
   - Data source agnostic components
   - Reusable visualization components
   - Source attribution display

2. **State Management**
   - React Query for multi-source server state
   - Context API for user preferences
   - Local state for UI interactions
   - Optimistic updates for source switching

3. **Data Flow**
   - Unidirectional data flow
   - Custom hooks for multi-source data fetching
   - Error boundary implementation per source
   - Loading states for each data source

### Backend Patterns
1. **Multi-Source Service Layer**
   - Repository pattern for each data source
   - Service layer for business logic aggregation
   - Factory pattern for source-specific services
   - Strategy pattern for data source selection
   - Use Poetry for dependency management in Docker
   - Do not mount over /app/backend in production
   - Enforce absolute imports for all internal modules
   - Run linter (ruff) regularly

2. **OAuth2 Integration Pattern**
   - Standardized OAuth2 flow for all sources
   - Token management and refresh
   - State management for security
   - Webhook handling for real-time updates
   - Proven implementation across Withings, Oura, and Fitbit

3. **Data Processing Pipeline**
   - ETL pipeline for each data source
   - Data normalization and standardization
   - Quality scoring and validation
   - Conflict resolution algorithms
   - Background processing with rate limiting

## Database Design

### Multi-Source Schema Patterns
1. **User Preferences**
   ```sql
   user_data_source_preferences (
     user_id, activity_source, sleep_source,
     nutrition_source, body_composition_source,
     priority_rules, conflict_resolution
   )
   ```

2. **Source-Specific Tables**
   ```sql
   withings_data, oura_data, fitbit_data,
   strava_data, whoop_data, myfitnesspal_data,
   cronometer_data, apple_health_data, csv_data
   ```

3. **Unified Health Metrics**
   ```sql
   health_metrics (
     user_id, metric_type, value, timestamp,
     data_source, quality_score, is_primary
   )
   ```

### Time Series Data Patterns
1. **Multi-Source TimescaleDB**
   - Partitioning by time and source
   - Efficient cross-source queries
   - Source-specific indexing

2. **Data Aggregation Tables**
   - Pre-computed multi-source metrics
   - Conflict-resolved data views
   - Performance optimization

## Security Patterns

### Multi-Source Authentication
1. **OAuth2 Management**
   - Separate OAuth2 flows for each source
   - Token isolation and encryption
   - Refresh token rotation
   - Scope management per source

2. **Data Source Authorization**
   - Granular permissions per source
   - User consent management
   - Data access auditing
   - Source-specific rate limiting

### Privacy & Compliance
1. **Data Isolation**
   - Source-specific data encryption
   - Selective data sharing
   - User-controlled data retention
   - GDPR compliance per source

## Performance Patterns

### Multi-Source Optimization
1. **Parallel Data Fetching**
   - Concurrent API calls to multiple sources
   - Async processing pipelines
   - Source-specific rate limiting
   - Intelligent retry mechanisms

2. **Caching Strategy**
   - Source-specific cache layers
   - Cross-source data correlation cache
   - User preference caching
   - Intelligent cache invalidation

3. **Data Aggregation Optimization**
   - Pre-computed cross-source metrics
   - Materialized views for common queries
   - Incremental aggregation updates
   - Source priority-based processing

### Scaling Strategy
1. **Horizontal Scaling**
   - Source-specific service scaling
   - Load balancing per data source
   - Auto-scaling based on source load
   - Geographic distribution

2. **Data Partitioning**
   - User-based sharding
   - Source-based partitioning
   - Time-based partitioning
   - Read/write splitting per source

## Mobile Integration Patterns

### iOS HealthKit Integration
1. **Native Data Access**
   - HealthKit framework integration
   - Background sync capabilities
   - Permission management
   - Data type mapping

2. **Real-Time Sync**
   - Push notification triggers
   - Background app refresh
   - Conflict resolution on device
   - Offline data handling

## Monitoring Patterns

### Multi-Source Observability
1. **Source-Specific Monitoring**
   - API health checks per source
   - Sync success rates
   - Data quality metrics
   - Error tracking by source

2. **Cross-Source Analytics**
   - Data correlation monitoring
   - User preference analytics
   - Source adoption metrics
   - Performance comparison

3. **User Experience Monitoring**
   - Source selection patterns
   - Sync satisfaction metrics
   - Mobile app usage analytics
   - Cross-platform behavior tracking

## Data Source Specific Patterns

### OAuth2 Sources (Withings, Oura, Fitbit - IMPLEMENTED)
- Standardized authentication flow with secure state management
- Automatic token refresh with expiration handling
- Rate limiting compliance with retry logic
- Background data synchronization
- Comprehensive error handling and recovery
- Proven pattern ready for WHOOP, Strava, MyFitnessPal, Cronometer

### File-Based Sources (Apple Health, CSV - IMPLEMENTED)
- Secure file upload and processing
- Background processing queues with job tracking
- Data validation pipelines with error reporting
- Progress tracking and user feedback
- XML parsing for Apple Health exports
- Column mapping for CSV imports

### API-Only Sources (Strava, MyFitnessPal - READY)
- RESTful API integration following OAuth2 pattern
- Pagination handling for large datasets
- Data transformation layers for unified schema
- Error recovery mechanisms with intelligent retry
- Rate limiting compliance per source requirements 