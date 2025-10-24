# Multi-stage build for optimized image size
FROM node:18-alpine AS frontend-builder

WORKDIR /app

# Copy package files and install dependencies
COPY package.json ./
COPY package-lock.json* ./
RUN npm install

# Copy TypeScript source and build
COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build

# Production stage
FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    default-libmysqlclient-dev \
    pkg-config \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Python requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .
COPY database_setup.sql .
COPY config/ ./config/
COPY scripts/ ./scripts/
COPY templates/ ./templates/
COPY static/ ./static/

# Copy built frontend from builder stage
COPY --from=frontend-builder /app/static/js/app.js ./static/js/

# Create non-root user
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:5000/ || exit 1

# Run with gunicorn
CMD ["gunicorn", "--workers", "3", "--bind", "0.0.0.0:5000", "--timeout", "120", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
