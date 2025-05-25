# Backend

## Overview

The backend is built with FastAPI, SQLAlchemy, and Alembic, using PostgreSQL for data storage. Poetry manages dependencies.

## Structure

- **API**: RESTful endpoints for authentication, users, health metrics, goals, and data sources
- **Models**: SQLAlchemy ORM models for users, metrics, goals, data sources, sync logs
- **Data Sources**: Integrations for Apple Health, Withings, and CSV
- **Sync Logic**: Scheduled and manual sync, OAuth2 flows, data mapping

## Key Patterns

- JWT authentication
- Modular API routers
- Alembic migrations
- Environment-based config

See `architecture.md` and `data_integrations.md` for more. 