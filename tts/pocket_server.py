import io
import scipy.io.wavfile as wavfile
from http.server import BaseHTTPRequestHandler, HTTPServer
from pocket_tts import TTSModel

RU_TO_EN = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'ye', 'ё': 'yo',
    'ж': 'zh', 'з': 'z', 'и': 'ee', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
    'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'oo',
    'ф': 'f', 'х': 'kh', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'shch',
    'ъ': '', 'ы': 'i', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya'
}

def transliterate_ru(text: str) -> str:
    out = []
    for ch in text:
        low = ch.lower()
        if low in RU_TO_EN:
            rep = RU_TO_EN[low]
            out.append(rep.capitalize() if ch.isupper() else rep)
        else:
            out.append(ch)
    return "".join(out)

print("Загружаю модель Kyutai Pocket-TTS (при первом запуске скачается ~200 МБ)...")
model = TTSModel.load_model()
# Доступные женские голоса: "alba", "cosette", "fantine", "azelma"
voice_state = model.get_state_for_audio_prompt("cosette")
print("=== СЕРВЕР POCKET-TTS ГОТОВ (Порт 8021) ===")

class PocketHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", 0))
            raw_text = self.rfile.read(length).decode("utf-8").strip()
            if not raw_text:
                raw_text = "Privet!"

            phonetic_text = transliterate_ru(raw_text)
            print(f"[Pocket-TTS] Озвучиваю: {raw_text} -> ({phonetic_text})")

            audio_tensor = model.generate_audio(voice_state, phonetic_text)
            
            buf = io.BytesIO()
            wavfile.write(buf, model.sample_rate, audio_tensor.numpy())
            wav_bytes = buf.getvalue()

            self.send_response(200)
            self.send_header("Content-Type", "audio/wav")
            self.end_headers()
            self.wfile.write(wav_bytes)
        except Exception as e:
            print(f"[ОШИБКА POCKET-TTS]: {e}")
            self.send_response(500)
            self.end_headers()

    def log_message(self, format, *args):
        pass

HTTPServer(("127.0.0.1", 8021), PocketHandler).serve_forever()
