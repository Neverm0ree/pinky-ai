#!/usr/bin/env bash
set -e

echo "=== 🚀 Автоматическая установка Pinky AI для Linux ==="

# 1. Установка системных пакетов
if command -v pacman >/dev/null 2>&1; then
    echo "📦 Установка системных пакетов (Arch / CachyOS)..."
    sudo pacman -S --needed --noconfirm godot git curl wget tar unzip python python-pip xorg-xprop xdotool pipewire-pulse alsa-utils
elif command -v apt >/dev/null 2>&1; then
    echo "📦 Установка системных пакетов (Debian / Ubuntu)..."
    sudo apt update && sudo apt install -y godot3 git curl wget tar unzip python3 python3-venv python3-pip xdotool x11-utils pulseaudio-utils alsa-utils
elif command -v dnf >/dev/null 2>&1; then
    echo "📦 Установка системных пакетов (Fedora)..."
    sudo dnf install -y godot git curl wget tar unzip python3 python3-pip xprop xdotool pulseaudio-utils alsa-utils
fi

# 2. Если скрипт запущен через curl | bash вне папки проекта — клонируем репозиторий
if [ ! -f "project.godot" ]; then
    TARGET_DIR="$HOME/pinky-ai"
    if [ ! -d "$TARGET_DIR" ]; then
        echo "📥 Клонирование репозитория Pinky AI в $TARGET_DIR..."
        git clone "https://github.com/Neverm0ree/pinky-ai.git" "$TARGET_DIR"
    fi
    cd "$TARGET_DIR"
fi

PROJECT_DIR="$(pwd)"
mkdir -p models avatars tts build/linux addons/nobodywho
touch tts/.gdignore models/.gdignore build/.gdignore avatars/.gdignore

# 3. Скачивание бинарника плагина NobodyWho (если отсутствует после git clone)
if ! ls addons/nobodywho/*.so >/dev/null 2>&1; then
    echo "🧩 Скачивание плагина NobodyWho (GDExtension) для Linux x86_64..."
    NW_URL=$(curl -s https://api.github.com/repos/nobodywho-ooo/nobodywho/releases/latest | grep -o 'https://[^"]*linux[^"]*\.zip' | head -n 1 || true)
    if [ -n "$NW_URL" ]; then
        wget -q --show-progress "$NW_URL" -O /tmp/nobodywho.zip
        unzip -qo /tmp/nobodywho.zip -d /tmp/nw_ext
        find /tmp/nw_ext -name "*.so" -exec cp -f {} addons/nobodywho/ \;
        rm -rf /tmp/nobodywho.zip /tmp/nw_ext
    fi
fi

# 4. Скачивание локального синтезатора Piper TTS и русской голосовой модели
if [ ! -f "tts/piper/piper" ]; then
    echo "🔊 Скачивание движка Piper TTS..."
    wget -q --show-progress "https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_linux_x86_64.tar.gz" -O /tmp/piper.tar.gz
    tar -xzf /tmp/piper.tar.gz -C tts/
    rm -f /tmp/piper.tar.gz
fi

if [ ! -f "tts/voice.onnx" ]; then
    echo "🎙️ Скачивание русской голосовой модели (Irina Medium)..."
    wget -q --show-progress "https://huggingface.co/rhasspy/piper-voices/resolve/main/ru/ru_RU/irina/medium/ru_RU-irina-medium.onnx" -O tts/voice.onnx
    wget -q "https://huggingface.co/rhasspy/piper-voices/resolve/main/ru/ru_RU/irina/medium/ru_RU-irina-medium.onnx.json" -O tts/voice.onnx.json
fi

# 5. Настройка Python-окружений для микрофона (Faster-Whisper) и Kyutai Pocket-TTS
echo "🐍 Настройка виртуального окружения распознавания речи (Faster-Whisper)..."
if [ ! -d "tts/venv_stt" ]; then
    python3 -m venv tts/venv_stt
fi
./tts/venv_stt/bin/pip install -q --upgrade pip
./tts/venv_stt/bin/pip install -q faster-whisper numpy

echo "🐍 Настройка виртуального окружения Kyutai Pocket-TTS..."
if [ ! -d "tts/venv_pocket" ]; then
    python3 -m venv tts/venv_pocket
fi
./tts/venv_pocket/bin/pip install -q --upgrade pip
./tts/venv_pocket/bin/pip install -q pocket-tts scipy soundfile

# 6. Скачивание стартовой GGUF-модели, если папка models/ пуста
if ! ls models/*.gguf >/dev/null 2>&1; then
    echo "🧠 Скачивание языковой модели Qwen2.5-7B-Instruct (Q3_K_M, ~3.8 ГБ)..."
    wget -c --show-progress "https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF/resolve/main/qwen2.5-7b-instruct-q3_k_m.gguf" \
        -O models/qwen2.5-7b-instruct-q3_k_m.gguf
fi

# 7. Создание единого лаунчера run_aria.sh
cat << 'LAUNCHER' > build/linux/run_aria.sh
#!/usr/bin/env bash
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

if [ -f "$DIR/tts/venv_stt/bin/python" ] && [ -f "$DIR/tts/stt_server.py" ]; then
    "$DIR/tts/venv_stt/bin/python" "$DIR/tts/stt_server.py" &
    STT_PID=$!
fi

if [ -f "$DIR/tts/venv_pocket/bin/python" ] && [ -f "$DIR/tts/pocket_server.py" ]; then
    "$DIR/tts/venv_pocket/bin/python" "$DIR/tts/pocket_server.py" &
    POCKET_PID=$!
fi

if [ -x "$DIR/aria.x86_64" ]; then
    "$DIR/aria.x86_64"
else
    godot --path "$(dirname "$(dirname "$DIR")")"
fi

[ -n "$STT_PID" ] && kill $STT_PID 2>/dev/null || true
[ -n "$POCKET_PID" ] && kill $POCKET_PID 2>/dev/null || true
LAUNCHER

chmod +x build/linux/run_aria.sh
ln -sfn "$PROJECT_DIR/models" "$PROJECT_DIR/build/linux/models"
ln -sfn "$PROJECT_DIR/avatars" "$PROJECT_DIR/build/linux/avatars"
ln -sfn "$PROJECT_DIR/tts" "$PROJECT_DIR/build/linux/tts"

# 8. Сборка нативного Linux-бинарника (если установлены шаблоны экспорта Godot)
echo "⚙️ Сборка приложения..."
godot --headless --path "$PROJECT_DIR" --export-release "Linux" "$PROJECT_DIR/build/linux/aria.x86_64" || \
    echo "ℹ️ Шаблоны экспорта не найдены — запуск будет выполняться напрямую через движок Godot."

# 9. Создание ярлыка в меню приложений
mkdir -p "$HOME/.local/share/applications"
cat << DESKTOP > "$HOME/.local/share/applications/pinky-ai.desktop"
[Desktop Entry]
Type=Application
Name=Pinky AI
Comment=Локальный 3D ИИ-компаньон (Godot 4 + LLM + TTS/STT)
Exec=$PROJECT_DIR/build/linux/run_aria.sh
Icon=$PROJECT_DIR/icon.svg
Terminal=false
Categories=Utility;
DESKTOP

echo "=== ✅ Установка завершена! Запускай: $PROJECT_DIR/build/linux/run_aria.sh ==="
