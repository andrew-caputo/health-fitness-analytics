# Health & Fitness Analytics Platform

## Project Overview
A comprehensive health and fitness tracking application that integrates data from multiple sources to provide AI-powered insights and recommendations.

## Documentation
- All project documentation is managed in markdown under `docs/`.
- MkDocs (Material theme) generates a browsable documentation site.
- Documentation is hosted on GitHub Pages and is updated via `mkdocs gh-deploy`.
- The documentation site is a core deliverable for transparency, onboarding, and ongoing development.

## Core Requirements

### Data Sources
1. Apple Health
   - Steps
   - Active energy
   - Resting energy
   - Exercise minutes
   - Sleep
   - Cardio fitness
   - Heart rate
   - Resting heart rate

2. Withings
   - Weight
   - Body composition

3. CSV Import
   - Calories
   - Carbohydrates
   - Protein
   - Fats

### Core Features
1. Data Integration
   - Automated daily sync with Apple Health
   - Real-time Withings data updates
   - CSV data import with validation
   - Data quality monitoring

2. Analytics & Visualization
   - Interactive charts for all metrics
   - Trend analysis
   - Correlation analysis
   - Impact analysis of activity on body composition
   - Macro impact analysis on weight and composition

3. AI Assistant
   - Natural language conversation interface
   - Data-driven insights
   - Goal setting and tracking
   - Personalized recommendations
   - Scientific backing for advice

## Technical Stack

### Frontend
- React 18
- TypeScript
- Tailwind CSS
- Chart.js/D3.js
- React Query
- React Router

### Backend
- Python 3.11+
- FastAPI
- SQLAlchemy
- Pandas
- Scikit-learn
- OpenAI API

### Database
- PostgreSQL
- TimescaleDB
- Redis

### Cloud Infrastructure (GCP)
- Cloud Run
- Cloud SQL
- BigQuery
- Vertex AI
- Cloud Storage
- Cloud CDN

## Project Goals
1. Create a seamless data integration experience
2. Provide actionable insights through AI
3. Deliver an intuitive and engaging user interface
4. Ensure data security and privacy
5. Maintain high performance and reliability
6. Achieve robust containerization and dependency management for backend services
7. Enforce code quality and maintainability with linting and best practices
8. Maintain comprehensive, browsable documentation for all project aspects

## Success Metrics
1. Data accuracy and completeness
2. User engagement with AI assistant
3. System performance and reliability
4. User satisfaction and retention
5. Insight quality and usefulness 