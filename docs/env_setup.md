# Environment Setup

## Prerequisites
- Python 3.10+
- Node.js 18+
- Poetry (for Python deps)
- Docker (for local stack)
- MkDocs (for documentation)

## Setup Steps
1. Clone the repo
2. `cd health-fitness-analytics`
3. `poetry install` (backend)
4. `cd frontend && npm install` (frontend)
5. Copy `.env.example` to `.env` and set variables
6. `docker compose up` to start local stack

## Documentation
- Install MkDocs and Material theme: `pip install mkdocs-material`
- Serve docs locally: `mkdocs serve`
- Build static site: `mkdocs build`
- Deploy to GitHub Pages: `mkdocs gh-deploy`

## Environment Variables
- See `.env.example` for required variables
- Never commit secrets 