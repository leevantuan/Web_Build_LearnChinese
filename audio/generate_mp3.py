import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

from melo.api import TTS
import subprocess
import os

FFMPEG_PATH = r"C:\Users\elt.it05\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1-full_build\bin\ffmpeg.exe"

# 1.0 = giữ nguyên
# 1.2 = tăng nhẹ
# 1.5 = tăng khá rõ
# 1.8 = tăng mạnh
# 2.0 = rất to, có thể vỡ tiếng
VOLUME_MULTIPLIER = 1.8

def main():
    if len(sys.argv) < 5:
        raise Exception("Usage: python generate_mp3.py <text> <language> <speed> <output_mp3_path>")

    text = sys.argv[1]
    language = sys.argv[2]
    speed = float(sys.argv[3])
    output_mp3 = sys.argv[4]

    output_dir = os.path.dirname(output_mp3)
    os.makedirs(output_dir, exist_ok=True)

    temp_wav = os.path.join(output_dir, "temp.wav")

    model = TTS(language=language, device="cpu")
    speaker_ids = model.hps.data.spk2id
    speaker_key = language if language in speaker_ids else next(iter(speaker_ids.keys()))
    speaker_id = speaker_ids[speaker_key]

    model.tts_to_file(
        text=text,
        speaker_id=speaker_id,
        output_path=temp_wav,
        speed=speed,
        quiet=True
    )

    if not os.path.exists(temp_wav):
        raise FileNotFoundError(f"Không tạo được file wav tạm: {temp_wav}")

    if not os.path.exists(FFMPEG_PATH):
        raise FileNotFoundError(f"Không tìm thấy ffmpeg.exe: {FFMPEG_PATH}")

    subprocess.run(
        [
            FFMPEG_PATH,
            "-y",
            "-i", temp_wav,
            "-filter:a", f"volume={VOLUME_MULTIPLIER}",
            "-codec:a", "libmp3lame",
            "-qscale:a", "2",
            output_mp3
        ],
        check=True
    )

    if os.path.exists(temp_wav):
        os.remove(temp_wav)

    print(output_mp3)

if __name__ == "__main__":
    main()