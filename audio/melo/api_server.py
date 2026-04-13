"""
MeloTTS REST API Server cho Docker
Cung cấp endpoint POST /synthesize để Backend gọi generate audio.
"""
from flask import Flask, request, send_file, jsonify
from melo.api import TTS
import os
import io
import tempfile
import subprocess
import uuid
import logging

# Cấu hình logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Tăng âm lượng output
VOLUME_MULTIPLIER = 1.8

# Pre-load model ZH khi startup (tốn ~2-3s)
logger.info("Đang load MeloTTS model ZH...")
models = {}
try:
    models['ZH'] = TTS(language='ZH', device='cpu')
    logger.info("Model ZH đã load xong.")
except Exception as e:
    logger.error(f"Lỗi load model ZH: {e}")

# Lazy load các model khác khi cần
SUPPORTED_LANGUAGES = ['EN', 'ES', 'FR', 'ZH', 'JP', 'KR']

def get_model(language):
    """Lấy model TTS, lazy load nếu chưa có."""
    if language not in models:
        if language not in SUPPORTED_LANGUAGES:
            raise ValueError(f"Ngôn ngữ không hỗ trợ: {language}")
        logger.info(f"Đang load model {language}...")
        models[language] = TTS(language=language, device='cpu')
        logger.info(f"Model {language} đã load xong.")
    return models[language]


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    return jsonify({"status": "ok", "models_loaded": list(models.keys())}), 200


@app.route('/synthesize', methods=['POST'])
def synthesize():
    """
    Generate audio từ text.
    
    Request JSON:
    {
        "text": "你好世界",
        "language": "ZH",
        "speed": 0.8,
        "output_path": "/app/audio/Vocabularies/Topic_xxx/vocab-id/vocab-id_0.8.mp3"  (optional)
    }
    
    Nếu có output_path: lưu file vào path đó, trả JSON {"path": "...", "success": true}
    Nếu không có output_path: trả về file mp3 trực tiếp (binary response)
    """
    try:
        data = request.get_json()
        
        if not data or 'text' not in data:
            return jsonify({"error": "Thiếu trường 'text'", "success": False}), 400
        
        text = data['text']
        language = data.get('language', 'ZH').upper()
        speed = float(data.get('speed', 0.8))
        output_path = data.get('output_path', None)
        
        if not text.strip():
            return jsonify({"error": "Text không được rỗng", "success": False}), 400
        
        logger.info(f"Synthesize: text='{text[:30]}...', lang={language}, speed={speed}")
        
        # Lấy model
        model = get_model(language)
        speaker_ids = model.hps.data.spk2id
        speaker_key = language if language in speaker_ids else next(iter(speaker_ids.keys()))
        speaker_id = speaker_ids[speaker_key]
        
        # Tạo temp WAV
        temp_dir = tempfile.mkdtemp()
        temp_wav = os.path.join(temp_dir, "temp.wav")
        
        model.tts_to_file(
            text=text,
            speaker_id=speaker_id,
            output_path=temp_wav,
            speed=speed,
            quiet=True
        )
        
        if not os.path.exists(temp_wav):
            return jsonify({"error": "Không tạo được file WAV", "success": False}), 500
        
        # Xác định output path
        if output_path:
            # Lưu vào path chỉ định (shared volume)
            final_mp3 = output_path
        else:
            # Trả về binary
            final_mp3 = os.path.join(temp_dir, f"{uuid.uuid4()}.mp3")
        
        # Tạo thư mục nếu chưa có
        os.makedirs(os.path.dirname(final_mp3), exist_ok=True)
        
        # Convert WAV → MP3 với ffmpeg + tăng volume
        result = subprocess.run(
            [
                "ffmpeg", "-y",
                "-i", temp_wav,
                "-filter:a", f"volume={VOLUME_MULTIPLIER}",
                "-codec:a", "libmp3lame",
                "-qscale:a", "2",
                final_mp3
            ],
            capture_output=True
        )
        
        # Dọn file WAV tạm
        if os.path.exists(temp_wav):
            os.remove(temp_wav)
        
        if result.returncode != 0:
            error_msg = result.stderr.decode('utf-8', errors='replace')
            logger.error(f"FFmpeg lỗi: {error_msg}")
            return jsonify({"error": f"FFmpeg lỗi: {error_msg[:200]}", "success": False}), 500
        
        if not os.path.exists(final_mp3):
            return jsonify({"error": "Không tạo được file MP3", "success": False}), 500
        
        file_size = os.path.getsize(final_mp3)
        logger.info(f"Synthesize thành công: {final_mp3} ({file_size} bytes)")
        
        if output_path:
            # Đã lưu vào shared volume → trả JSON
            return jsonify({
                "success": True,
                "path": output_path,
                "size": file_size
            }), 200
        else:
            # Trả file binary
            response = send_file(
                final_mp3,
                mimetype='audio/mpeg',
                as_attachment=True,
                download_name='audio.mp3'
            )
            # Dọn temp sau khi trả
            @response.call_on_close
            def cleanup():
                if os.path.exists(final_mp3):
                    os.remove(final_mp3)
                if os.path.exists(temp_dir):
                    os.rmdir(temp_dir)
            return response
    
    except ValueError as e:
        return jsonify({"error": str(e), "success": False}), 400
    except Exception as e:
        logger.error(f"Lỗi synthesize: {e}", exc_info=True)
        return jsonify({"error": str(e), "success": False}), 500


if __name__ == '__main__':
    import click
    
    @click.command()
    @click.option('--host', '-h', default='0.0.0.0')
    @click.option('--port', '-p', type=int, default=8888)
    def main(host, port):
        logger.info(f"Starting MeloTTS REST API on {host}:{port}")
        app.run(host=host, port=port, debug=False)
    
    main()
