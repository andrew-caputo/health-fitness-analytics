FROM python:3.13-slim

WORKDIR /app

COPY pyproject.toml poetry.lock ./
COPY backend /app/backend
RUN ls -l /app/backend && find /app/backend
RUN pip install poetry && poetry install --only main

CMD ["poetry", "run", "uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"] 