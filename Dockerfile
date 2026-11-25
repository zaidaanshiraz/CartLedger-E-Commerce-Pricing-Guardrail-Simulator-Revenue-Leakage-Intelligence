# ==============================================================================
# DOCKERFILE — CartLedger (E-Commerce Revenue, PVM Bridge & SQL Case Files)
# ==============================================================================
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/
COPY scripts/ ./scripts/
COPY sql/ ./sql/
COPY views/ ./views/
COPY web/ ./web/

# Build indexed SQLite warehouse at image build time
RUN python scripts/build_ecommerce_db.py

RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser

EXPOSE 8001

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD sh -c 'curl -f http://localhost:${PORT:-8001}/api/health || exit 1'

CMD ["sh", "-c", "uvicorn app.api_server:app --host 0.0.0.0 --port ${PORT:-8001}"]

