# ============================================================
# MeloTTS Audio Service — CHI TIENG TRUNG (CPU-only)
# Giam tu ~5GB xuong ~1.5GB bang cach:
#   - PyTorch CPU-only (khong CUDA)
#   - Chi download model ZH
#   - Bo gradio, gruut (DE/ES/FR), Korean, Japanese packages
#   - Dung Flask API thay Gradio UI
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

# Install PyTorch CPU-only (~800MB thay vi ~5GB CUDA)
RUN pip install --no-cache-dir \
    torch==2.1.0+cpu \
    torchaudio==2.1.0+cpu \
    --index-url https://download.pytorch.org/whl/cpu

# Install CHI nhung package can cho tieng Trung
RUN pip install --no-cache-dir \
    flask click \
    txtsplit cached_path \
    "transformers==4.27.4" \
    "num2words==0.5.12" \
    "unidic_lite==1.0.8" \
    "unidic==1.1.0" \
    "mecab-python3==1.0.9" \
    "fugashi==1.3.0" \
    "anyascii==0.3.2" \
    "librosa==0.9.1" \
    "pydub==0.25.1" \
    "unidecode==1.3.7" \
    "pypinyin==0.50.0" \
    "cn2an==0.5.22" \
    "jieba==0.42.1" \
    "langid==1.1.6" \
    tqdm \
    "loguru==0.7.2"

# Install MeloTTS package (khong cai lai dependencies)
RUN pip install --no-cache-dir --no-deps -e .

# Download unidic dictionary
RUN python -m unidic download

# Download CHI model ZH (khong download EN/ES/FR/JP/KR)
RUN python melo/init_downloads.py

# Create audio volume
RUN mkdir -p /app/audio

EXPOSE 8888

# Dung Flask API server (nhe hon Gradio)
CMD ["python", "./melo/api_server.py", "--host", "0.0.0.0", "--port", "8888"]
