# System Patterns

## Architecture Overview

### Frontend Architecture
```
src/
├── components/
│   ├── common/
│   ├── dashboard/
│   ├── charts/
│   └── ai-assistant/
├── hooks/
├── services/
├── store/
└── utils/
```

### Backend Architecture
```
backend/
├── api/
│   ├── routes/
│   ├── middleware/
│   └── validators/
├── core/
│   ├── services/
│   ├── models/
│   └── utils/
├── data/
│   ├── collectors/
│   ├── processors/
│   └── analyzers/
└── ai/
    ├── models/
    ├── prompts/
    └── processors/
```

## Design Patterns

### Frontend Patterns
1. **Component Composition**
   - Atomic design principles
   - Reusable component library
   - Container/Presenter pattern

2. **State Management**
   - React Query for server state
   - Context API for global state
   - Local state for component-specific data

3. **Data Flow**
   - Unidirectional data flow
   - Custom hooks for data fetching
   - Error boundary implementation

### Backend Patterns
1. **Service Layer**
   - Repository pattern for data access
   - Service layer for business logic
   - Factory pattern for service creation
   - Use Poetry for dependency management in Docker
   - Do not mount over /app/backend in production to avoid overwriting installed dependencies
   - Enforce absolute imports for all internal modules
   - Run linter (ruff) regularly; address critical issues before endpoint testing

2. **Data Processing**
   - Pipeline pattern for data processing
   - Strategy pattern for different data sources
   - Observer pattern for real-time updates

3. **API Design**
   - RESTful endpoints
   - GraphQL for complex queries
   - WebSocket for real-time features

## Database Design

### Schema Patterns
1. **Time Series Data**
   - TimescaleDB for metrics
   - Partitioning by time
   - Efficient querying patterns

2. **User Data**
   - Normalized user tables
   - Secure credential storage
   - Audit logging

3. **Analytics Data**
   - Aggregated metrics
   - Cached results
   - Materialized views

## Security Patterns

### Authentication
1. **OAuth2 Implementation**
   - Apple Health integration
   - Withings API integration
   - JWT token management

2. **Authorization**
   - Role-based access control
   - Resource-based permissions
   - API key management

### Data Security
1. **Encryption**
   - Data at rest
   - Data in transit
   - Key management

2. **Privacy**
   - Data anonymization
   - Access logging
   - Compliance controls

## Performance Patterns

### Caching Strategy
1. **Multi-level Cache**
   - Redis for hot data
   - CDN for static assets
   - Browser caching

2. **Query Optimization**
   - Indexed queries
   - Materialized views
   - Query result caching

### Scaling Strategy
1. **Horizontal Scaling**
   - Stateless services
   - Load balancing
   - Auto-scaling

2. **Data Partitioning**
   - Time-based partitioning
   - User-based sharding
   - Read/write splitting

## Monitoring Patterns

### Observability
1. **Logging**
   - Structured logging
   - Log aggregation
   - Error tracking

2. **Metrics**
   - Performance metrics
   - Business metrics
   - Health checks

3. **Tracing**
   - Distributed tracing
   - Request tracking
   - Performance profiling 