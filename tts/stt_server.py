import shutil
import threading
import subprocess
import numpy as np
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from faster_whisper import WhisperModel

print("Загружаю модель Faster-Whisper (small, int8)...")
model = WhisperModel("small", device="cpu", compute_type="int8", cpu_threads=4)

def get_record_cmd():
    if shutil.which("parecord"):
        return ["parecord", "--raw", "--format=s16le", "--rate=16000", "--channels=1", "--latency-msec=50"]
    return ["arecord", "-D", "default", "-q", "-f", "S16_LE", "-r", "16000", "-c", "1", "-t", "raw"]

print(f"Используемый рекордер: {' '.join(get_record_cmd())}")
print("=== СЕРВЕР РАСПОЗНАВАНИЯ РЕЧИ ГОТОВ (Порт 8022) ===")

HALLUCINATIONS = [
    "субтитры", "редактор субтитров", "dimatorzok", "продолжение следует",
    "спасибо за просмотр", "подписывайтесь", "а.синецкая"
]

# Готовим float32-массив [-1.0, 1.0] напрямую для Whisper без сохранения в .wav
def prepare_audio_array(frames: list):
    if not frames:
        return None, 0.0
    audio_float = np.concatenate(frames).astype(np.float32)
    audio_float -= np.mean(audio_float)
    peak = float(np.max(np.abs(audio_float)))

    if peak > 80.0:
        # Нормализуем громкость сразу в формат float32 [-0.9, 0.9]
        audio_norm = (audio_float / peak) * 0.9
    else:
        audio_norm = audio_float / 32768.0

    return np.clip(audio_norm, -1.0, 1.0).astype(np.float32), peak

def transcribe_array(audio_np: np.ndarray) -> str:
    segments, _ = model.transcribe(
        audio_np,
        language="ru",
        beam_size=5,
        vad_filter=False,
        condition_on_previous_text=False
    )
    text = " ".join([seg.text.strip() for seg in segments]).strip()
    low = text.lower()
    for h in HALLUCINATIONS:
        if h in low:
            return ""
    return text

manual_proc = None
manual_thread = None
manual_frames = []
is_manual_recording = False
listen_proc = None

def manual_record_loop(proc):
    global manual_frames, is_manual_recording
    chunk_bytes = 3200 # 0.1 сек при 16000 Гц
    while is_manual_recording and proc.poll() is None:
        data = proc.stdout.read(chunk_bytes)
        if not data:
            break
        samples = np.frombuffer(data, dtype=np.int16)
        if len(samples) > 0:
            manual_frames.append(samples)

class STTHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        global manual_proc, manual_thread, manual_frames, is_manual_recording, listen_proc

        # 1. Старт записи по нажатию кнопки "Голос"
        if self.path.startswith("/start"):
            # Если был активен фоновый процесс "Звонок", останавливаем его
            if listen_proc and listen_proc.poll() is None:
                listen_proc.terminate()
            if is_manual_recording and manual_proc:
                is_manual_recording = False
                manual_proc.terminate()

            manual_frames = []
            is_manual_recording = True
            manual_proc = subprocess.Popen(
                get_record_cmd(),
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL
            )
            manual_thread = threading.Thread(target=manual_record_loop, args=(manual_proc,), daemon=True)
            manual_thread.start()
            print("[STT] 🔴 Запись с микрофона началась...")
            self._send_text("OK")

        # 2. Остановка записи и распознавание
        elif self.path.startswith("/stop"):
            is_manual_recording = False
            if manual_proc:
                manual_proc.terminate()
                try:
                    manual_proc.wait(timeout=1.0)
                except Exception:
                    manual_proc.kill()
                manual_proc = None
            if manual_thread:
                manual_thread.join(timeout=1.0)

            duration = len(manual_frames) * 0.1
            audio_np, peak = prepare_audio_array(manual_frames)
            print(f"[STT] ⏹ Записано: {duration:.1f} сек | Пиковая громкость: {int(peak)}")

            if audio_np is None or duration < 0.3 or peak < 80.0:
                print("[STT] ⚠ Слишком тихо!")
                self._send_text("")
                return

            try:
                text = transcribe_array(audio_np)
                print(f"[STT Распознано]: {text}")
                self._send_text(text)
            except Exception as e:
                print(f"[ОШИБКА STT]: {e}")
                self._send_text("")

        # 3. Автоматическое прослушивание для режима "Звонок"
        elif self.path.startswith("/listen"):
            if is_manual_recording:
                self._send_text("")
                return
            try:
                listen_proc = subprocess.Popen(
                    get_record_cmd(),
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL
                )
                chunk_bytes = 3200
                frames = []
                speaking = False
                silence_chunks = 0
                total_chunks = 0

                print("[STT Звонок] 👂 Слушаю микрофон...")
                while not is_manual_recording:
                    data = listen_proc.stdout.read(chunk_bytes)
                    if not data or len(data) < chunk_bytes:
                        break
                    total_chunks += 1
                    samples = np.frombuffer(data, dtype=np.int16).astype(np.float32)
                    samples -= np.mean(samples)
                    rms = float(np.sqrt(np.mean(samples ** 2)))

                    if not speaking:
                        if rms > 220.0:
                            speaking = True
                            frames.append(samples.astype(np.int16))
                            silence_chunks = 0
                            print(f"[STT Звонок] Зафиксирован голос (уровень {int(rms)})...")
                        elif total_chunks > 70:
                            break
                    else:
                        frames.append(samples.astype(np.int16))
                        if rms < 150.0:
                            silence_chunks += 1
                        else:
                            silence_chunks = 0
                        if silence_chunks >= 12 or len(frames) > 150:
                            break

                listen_proc.terminate()
                listen_proc.wait()
                listen_proc = None

                if not speaking or len(frames) < 4:
                    self._send_text("")
                    return

                audio_np, _ = prepare_audio_array(frames)
                text = transcribe_array(audio_np)
                print(f"[STT Авто]: {text}")
                self._send_text(text)
            except Exception as e:
                print(f"[ОШИБКА STT]: {e}")
                self._send_text("")

    def _send_text(self, text: str):
        encoded = text.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)

    def log_message(self, format, *args):
        pass

ThreadingHTTPServer(("127.0.0.1", 8022), STTHandler).serve_forever()
