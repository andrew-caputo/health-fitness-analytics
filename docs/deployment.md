# Deployment

## Overview

This document covers deployment to Google Cloud Platform (GCP) using Docker and documentation deployment to GitHub Pages.

## Steps
1. Build Docker images for backend and frontend
2. Push images to GCP Container Registry
3. Configure GCP services (Cloud Run, SQL, etc.)
4. Set environment variables and secrets
5. Run database migrations (Alembic)

## Documentation Deployment
- Build and deploy docs to GitHub Pages: `mkdocs gh-deploy`
- Docs will be available at `https://<your-github-username>.github.io/<your-repo-name>/`

## Local Development
- Use Docker Compose for local stack
- See `env_setup.md` for details

## Best Practices
- Automate deployments
- Use separate environments (dev, prod)
- Monitor and log deployments 