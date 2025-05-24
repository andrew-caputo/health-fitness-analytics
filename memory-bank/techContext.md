# Technical Context

## Development Environment

### Required Tools
- Node.js 18+
- Python 3.11+
- PostgreSQL 15+
- Redis 7+
- Docker
- Git

### IDE Setup
- VS Code with extensions:
  - Python
  - TypeScript
  - ESLint
  - Prettier
  - Docker
  - GitLens

## Dependencies

### Frontend Dependencies
```json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "typescript": "^5.0.0",
    "tailwindcss": "^3.3.0",
    "chart.js": "^4.0.0",
    "react-query": "^4.0.0",
    "react-router-dom": "^6.0.0",
    "axios": "^1.0.0"
  },
  "devDependencies": {
    "vite": "^4.0.0",
    "eslint": "^8.0.0",
    "prettier": "^3.0.0",
    "jest": "^29.0.0",
    "@testing-library/react": "^14.0.0"
  }
}
```

### Backend Dependencies
```toml
[tool.poetry.dependencies]
python = "^3.11"
fastapi = "^0.100.0"
uvicorn = "^0.23.0"
sqlalchemy = "^2.0.0"
pandas = "^2.0.0"
scikit-learn = "^1.3.0"
openai = "^1.0.0"
python-jose = "^3.3.0"
passlib = "^1.7.4"
python-multipart = "^0.0.6"
redis = "^5.0.0"
httpx = "^0.24.0"
```

## API Integrations

### Apple HealthKit
- Framework: HealthKit
- Authentication: OAuth2
- Data Types:
  - Steps
  - Energy
  - Exercise
  - Sleep
  - Heart Rate
  - Cardio Fitness

### Withings API
- Base URL: https://wbsapi.withings.net
- Authentication: OAuth2
- Endpoints:
  - /measure
  - /body
  - /sleep
  - /activity

### OpenAI API
- Model: GPT-4
- Endpoint: https://api.openai.com/v1/chat/completions
- Features:
  - Chat completion
  - Context management
  - Response streaming

## Database Schema

### TimescaleDB Tables
```sql
-- Health Metrics
CREATE TABLE health_metrics (
    time TIMESTAMPTZ NOT NULL,
    user_id UUID NOT NULL,
    metric_type VARCHAR(50) NOT NULL,
    value DOUBLE PRECISION NOT NULL,
    source VARCHAR(50) NOT NULL
);

-- User Data
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

-- User Goals
CREATE TABLE user_goals (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    goal_type VARCHAR(50) NOT NULL,
    target_value DOUBLE PRECISION NOT NULL,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL
);
```

## Development Workflow

### Git Workflow
1. Feature branches from main
2. Pull request reviews
3. Automated testing
4. Staging deployment
5. Production deployment

### CI/CD Pipeline
1. Code linting
2. Unit tests
3. Integration tests
4. Build artifacts
5. Deploy to GCP

## Deployment

### GCP Services
1. Cloud Run
   - Backend API
   - Worker processes
   - Background jobs

2. Cloud SQL
   - PostgreSQL instance
   - TimescaleDB extension
   - Automated backups

3. Cloud Storage
   - Static assets
   - User uploads
   - Backup storage

4. Cloud CDN
   - Static content delivery
   - API caching
   - Edge optimization

## Monitoring

### Tools
1. Cloud Monitoring
   - Service metrics
   - Custom metrics
   - Alerting

2. Cloud Logging
   - Application logs
   - Access logs
   - Error tracking

3. Error Reporting
   - Exception tracking
   - Stack traces
   - Error grouping

## Docker & Poetry Backend Setup
- The backend Dockerfile uses Poetry for dependency management and installs all dependencies in the Poetry-managed environment.
- The build context is set to the project root, and the Dockerfile is in the root directory.
- The backend code is copied into /app/backend in the container.
- The backend service in docker-compose.yml should NOT mount ./backend:/app/backend in production, as this overwrites installed dependencies.
- Always use 'poetry run' for Python commands in the container to access the correct environment.

## Backend Import & Linting Practices
- All backend internal imports now use absolute paths (e.g., from backend.core.models import ...)
- Relative imports have been removed to avoid module resolution issues in Docker/Poetry
- Linter (ruff) is used to enforce code quality; 137 issues found, plan to address critical ones before endpoint testing 