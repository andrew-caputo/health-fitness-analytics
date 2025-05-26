# Testing

## Overview

Testing ensures reliability and maintainability for both backend and frontend.

## Backend
- Use `pytest` for unit and integration tests
- Coverage reporting with `pytest-cov`
- Test database setup for isolation (see below)

### Test Database & Isolation
- All backend tests run against a dedicated PostgreSQL test database (`health_fitness_test`)
- The test database URL is set via the `TEST_DATABASE_URL` environment variable (defaults to `postgresql://postgres:postgres@localhost:5432/health_fitness_test`)
- Tables are created at the start of the test session and dropped at the end
- Each test runs in a transaction that is rolled back after the test, ensuring a clean state
- The FastAPI `get_db` dependency is overridden in tests to use the test session
- To run tests:
  1. Ensure PostgreSQL is running and the test database exists
  2. Run: `pytest backend/tests/ --disable-warnings -v`

## Frontend
- Use `Jest` and `React Testing Library`
- Component and integration tests
- Mock API calls

## CI Integration
- Run tests on every PR/commit (CI setup TBD)

## Best Practices
- Write tests for new features and bugfixes
- Maintain high coverage
- Use fixtures and mocks for isolation 