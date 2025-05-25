# System Architecture

## Overview

This document describes the overall architecture of the Health & Fitness Analytics platform, including backend, frontend, data integrations, and cloud deployment.

## Components

- **Backend**: FastAPI, SQLAlchemy, Alembic, PostgreSQL
- **Frontend**: React, TypeScript, Vite
- **Data Integrations**: Apple Health, Withings, CSV
- **AI/Analytics**: Trend detection, chat interface
- **Deployment**: GCP, Docker

## Data Flow

1. Data is ingested from Apple Health, Withings, and CSV uploads.
2. Data is stored in a normalized PostgreSQL schema.
3. Backend exposes RESTful APIs for CRUD, sync, and analytics.
4. Frontend consumes APIs for visualization and user interaction.
5. AI/analytics modules process data for insights and chat responses.

## Component Relationships

- Data sources → Backend → Database
- Backend → Frontend (API)
- Backend → AI/Analytics
- Frontend → User

See other docs for details on each component. 