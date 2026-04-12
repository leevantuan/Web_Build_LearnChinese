# ============================================================
# MeloTTS Audio Generation Service
# Image size: ~2.5GB (Python + ML models)
# ============================================================
FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libsndfile1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy source
COPY . /app

# Install & pre-download models
RUN pip install --no-cache-dir -e .
RUN python -m unidic download
RUN python melo/init_downloads.py

# Create audio volume
RUN mkdir -p /app/audio

EXPOSE 8888

CMD ["python", "./melo/app.py", "--host", "0.0.0.0", "--port", "8888"]
