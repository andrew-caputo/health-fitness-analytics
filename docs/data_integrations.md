# Data Integrations

## Overview

This document covers integration with Apple Health, Withings, and CSV nutrition data.

## Apple Health
- Metrics: Steps, energy, exercise, sleep, cardio fitness, heart rate
- Sync: Manual/automated, OAuth2 (if applicable), data mapping

## Withings
- Metrics: Weight, body composition
- Sync: OAuth2, scheduled/manual, data mapping

## CSV Nutrition
- Metrics: Calories, carbs, protein, fats
- Sync: File upload, parsing, mapping

## Data Mapping
- All data normalized to internal schema
- Sync logs and error handling

See `backend.md` for implementation details. 