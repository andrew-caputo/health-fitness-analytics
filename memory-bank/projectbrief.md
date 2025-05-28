# Health & Fitness Analytics Platform

## Project Overview
A comprehensive health and fitness tracking application that integrates data from multiple sources to provide AI-powered insights and recommendations. The platform supports user-selectable data sources across four key health categories: Activity, Sleep, Nutrition, and Body Composition.

## Documentation
- All project documentation is managed in markdown under `docs/`.
- MkDocs (Material theme) generates a browsable documentation site.
- Documentation is hosted on GitHub Pages and is updated via `mkdocs gh-deploy`.
- The documentation site is a core deliverable for transparency, onboarding, and ongoing development.

## Core Requirements

### Multi-Source Data Integration
The platform integrates with 9 major health data sources, allowing users to select their preferred source for each health category:

#### Data Source Coverage Matrix
| Data Source | Activity | Sleep | Nutrition | Body Composition |
|-------------|----------|-------|-----------|------------------|
| **Apple Health** | ✅ Steps, Heart Rate, Workouts, Active Energy | ✅ Sleep Analysis, Time in Bed | ✅ Dietary Energy, Water | ✅ Weight, Body Fat %, BMI |
| **Withings** | ✅ Steps, Heart Rate, Activities | ✅ Sleep Duration, Sleep Stages | ❌ | ✅ Weight, Body Fat %, Muscle Mass, BMI |
| **CSV** | ✅ Custom Activity Data | ✅ Custom Sleep Data | ✅ Custom Nutrition Data | ✅ Custom Body Metrics |
| **Oura** | ✅ Steps, Heart Rate, Activity Score | ✅ Sleep Score, Sleep Stages, REM/Deep Sleep | ❌ | ❌ |
| **MyFitnessPal** | ✅ Exercise Logging | ❌ | ✅ Comprehensive Food Database, Macros, Micros | ❌ |
| **Fitbit** | ✅ Steps, Heart Rate, Active Minutes, Workouts | ✅ Sleep Stages, Sleep Score | ❌ | ✅ Weight, Body Fat % |
| **Strava** | ✅ Workouts, Heart Rate, Power, Pace | ❌ | ❌ | ❌ |
| **Whoop** | ✅ Strain Score, Heart Rate, Workouts | ✅ Sleep Performance, Recovery Score | ❌ | ✅ Height, Weight, Max HR |
| **Cronometer** | ❌ | ❌ | ✅ Comprehensive Nutrition (84+ nutrients), Macros, Micros | ✅ Weight, Body Fat % |

### User-Selectable Data Sources
Users can choose their preferred data source for each health category:
- **Activity Source**: Apple Health, Oura, Strava, Whoop, Fitbit, Withings, CSV
- **Sleep Source**: Apple Health, Oura, Whoop, Fitbit, Withings, CSV
- **Nutrition Source**: MyFitnessPal, Cronometer, Apple Health, CSV
- **Body Composition Source**: Withings, Apple Health, Fitbit, Cronometer, Whoop, CSV

### Core Features
1. **Multi-Source Data Integration**
   - OAuth2 authentication for all supported APIs
   - Real-time data synchronization
   - User preference management for source selection
   - Conflict resolution and data prioritization
   - CSV import with validation for custom data

2. **Analytics & Visualization**
   - Interactive charts for all metrics across sources
   - Cross-source trend analysis
   - Correlation analysis between different data types
   - Impact analysis of activity on body composition
   - Comprehensive health insights dashboard

3. **AI Assistant**
   - Natural language conversation interface
   - Multi-source data-driven insights
   - Goal setting and tracking across all categories
   - Personalized recommendations based on complete health picture
   - Scientific backing for advice using comprehensive data

4. **Mobile Application (iOS)**
   - Native iOS app with HealthKit integration
   - Data source selection and management
   - Real-time sync capabilities
   - Push notifications for goals and insights

## Technical Stack

### Frontend
- React 18 (Web Dashboard)
- Swift/SwiftUI (iOS Mobile App)
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
- OAuth2 integrations for all data sources

### Database
- PostgreSQL
- TimescaleDB
- Redis
- User preference management
- Multi-source data aggregation

### Cloud Infrastructure (GCP)
- Cloud Run
- Cloud SQL
- BigQuery
- Vertex AI
- Cloud Storage
- Cloud CDN

## Project Goals
1. Create a universal health data integration platform
2. Provide users flexibility to choose their preferred devices/apps
3. Deliver comprehensive insights from multiple data sources
4. Build an intuitive mobile-first experience
5. Ensure data security and privacy across all integrations
6. Maintain high performance with multiple data sources
7. Achieve robust containerization and dependency management
8. Enforce code quality and maintainability with linting and best practices
9. Maintain comprehensive, browsable documentation for all integrations

## Success Metrics
1. Support for 9 major health data sources
2. 100% coverage of Activity, Sleep, Nutrition, Body Composition categories
3. User adoption across multiple data source combinations
4. Data accuracy and completeness from all sources
5. User engagement with comprehensive health insights
6. System performance with multi-source data aggregation
7. User satisfaction with flexible source selection
8. Mobile app adoption and usage rates

## Project Status
**Phase 4D Week 8 COMPLETE**: Comprehensive AI-powered health coaching platform ready for Phase 5 local testing and production deployment.

### Current Capabilities
- **Backend**: 102+ API endpoints with 8 AI engines (Goal Optimization, Achievement System, Health Coaching)
- **iOS App**: Complete advanced features with AI-powered coaching interface
- **Data Sources**: 9/9 integrations including HealthKit access to 100+ health apps
- **AI Features**: Goal optimization, achievement tracking, health coaching systems

### Phase 5 Focus: Local Testing & Core Production
- **Week 1**: Local testing with iPhone and real health data validation
- **Week 2**: Core feature enhancement and polish based on real usage
- **Week 3**: Simple production deployment and TestFlight beta testing
- **Week 4**: Performance optimization, basic monetization, and App Store submission

### Deferred Features (Future Phases)
- Professional health monitoring and healthcare provider integration
- Medical integration and electronic health records (EHR)
- Real-time health monitoring and emergency alert systems
- Third-party developer platform and API marketplace
- Advanced technology integration (AR/VR, blockchain, IoT) 