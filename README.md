# 🌸 Pinky AI — Local 3D AI Companion (Linux & Windows)

[**🇬🇧 English**](#-english) | [**🇷🇺 Русский**](#-русский)

---

## 🇬🇧 English

**Pinky AI** is a fully autonomous, offline 3D desktop assistant and companion built with **Godot 4** for Linux and Windows. It runs locally without cloud APIs:

- **🧠 Local LLMs (GGUF):** support for `Qwen2.5`, `Qwen3`, and `LFM3` models via the `NobodyWho` plugin (`llama.cpp` GDExtension) with automatic filtering of `<think>` reasoning blocks and GPU/CPU layer offloading.
- **🗣️ Dual Text-to-Speech (TTS):** instant offline synthesis via `Piper TTS` and neural `Kyutai Pocket-TTS` with real-time FFT audio lip-sync and facial emotions.
- **🎙️ Speech-to-Text (STT):** push-to-talk voice input and continuous live call mode powered by `Faster-Whisper` (`PipeWire` / `ALSA` on Linux, `DirectShow` / `FFmpeg` on Windows).
- **🎭 Hot-Swappable 3D Models:** load and switch custom `.vrm`, `.glb`, and `.gltf` character avatars on the fly directly from the settings.
- **⚡ Visual Terminal Automation:** built-in node editor (`GraphEdit`) for creating `zsh` (Linux) and `PowerShell` (Windows) command pipelines, conditions, and voice triggers.
- **🪟 Frosted Glass Overlay:** transparent borderless desktop overlay with a GLSL Gaussian blur shader and native Linux compositor blur (`KDE KWin` / `Hyprland`).

---

### 🐧 Installation on Linux (One-Command)

This command automatically installs system packages (`Arch / CachyOS`, `Ubuntu / Debian`, `Fedora`), configures Python virtual environments for voice and microphone, downloads the `Piper TTS` engine, the `NobodyWho` plugin, a starter `.gguf` language model, and creates an application menu shortcut:

```bash
git clone [https://github.com/Neverm0ree/pinky-ai.git](https://github.com/Neverm0ree/pinky-ai.git) ~/pinky-ai && cd ~/pinky-ai && ./install_pinky.sh
```

Or run the installer directly via `curl`:

```bash
curl -fsSL [https://raw.githubusercontent.com/Neverm0ree/pinky-ai/main/install_pinky.sh](https://raw.githubusercontent.com/Neverm0ree/pinky-ai/main/install_pinky.sh) | bash
```

**Running on Linux:**
Launch **Pinky AI** from your desktop application menu or run in the terminal:

```bash
~/pinky-ai/build/linux/run_aria.sh
```

---

### 🪟 Installation on Windows

#### Option 1: Portable Release (Recommended)
1. Download the latest **`PinkyAI-Windows-x64.zip`** archive from the [**Releases**](https://github.com/Neverm0ree/pinky-ai/releases) page and extract it to any folder.
2. Run **`install_windows_deps.bat`** — it will automatically download the baseline `.gguf` language model (`Qwen2.5-7B-Instruct`) into `models/` and configure Python virtual environments for `Faster-Whisper` (STT) and `Pocket-TTS` (if Python 3.10+ is installed).
3. Launch the application via **`run_pinky.bat`** (or **`PinkyAI.exe`**).

#### Option 2: Manual Setup from Source
1. Clone the repository and open the project in **Godot Engine 4.3+**:
   ```powershell
   git clone [https://github.com/Neverm0ree/pinky-ai.git](https://github.com/Neverm0ree/pinky-ai.git)
   ```
2. Place `libnobodywho-godot-x86_64-pc-windows-msvc-release.dll` into `addons/nobodywho/` and `piper_windows_amd64` into `tts/piper/`.
3. Export the project using the **`Windows Desktop`** preset to `build/windows/PinkyAI.exe`.

---

### 🛠️ Adding Custom Models and VRM Avatars

- **Language Models (`.gguf`):** place any `.gguf` file into the `models/` folder and select it in **Settings → AI Model**.
- **3D Avatars (`.vrm` / `.glb`):** place model files into the `avatars/` folder (or click the **"File..."** button in the **Settings → View & 3D** tab).

---
---

## 🇷🇺 Русский

**Pinky AI** — полностью автономный 3D-ассистент и компаньон на базе **Godot 4** для Linux и Windows, работающий локально без облачных API:

- **🧠 Локальные LLM (GGUF):** поддержка моделей `Qwen2.5`, `Qwen3`, `LFM3` через плагин `NobodyWho` (`llama.cpp` GDExtension) с автоматической фильтрацией блоков размышлений `<think>` и распределением слоёв между видеокартой (VRAM) и процессором.
- **🗣️ Двойной синтез речи (TTS):** мгновенный офлайн-синтез через `Piper TTS` и нейросетевой `Kyutai Pocket-TTS` с синхронизацией губ по частотам звука (FFT-липсинк) и эмоциями.
- **🎙️ Распознавание голоса (STT):** голосовой ввод по кнопке и режим непрерывного живого звонка на базе `Faster-Whisper` (`PipeWire` / `ALSA` на Linux, `DirectShow` / `FFmpeg` на Windows).
- **🎭 Горячая смена 3D-моделей:** поддержка пользовательских аватаров формата `.vrm`, `.glb` и `.gltf` прямо из настроек без перезапуска.
- **⚡ Визуальная автоматизация терминала:** встроенный нодовый редактор (`GraphEdit`) для создания цепочек команд `zsh` (Linux) и `PowerShell` (Windows), условий и голосовых триггеров.
- **🪟 Тема «Матовое стекло» (Frosted Glass):** режим прозрачного оверлея рабочего стола с GLSL-шейдером размытия и поддержкой аппаратного блюра композитора (`KDE KWin` / `Hyprland`).

---

### 🐧 Быстрая установка на Linux (в одну команду)

Эта команда автоматически установит системные пакеты (`Arch / CachyOS`, `Ubuntu / Debian`, `Fedora`), настроит виртуальные окружения Python для голоса и микрофона, скачает движок `Piper TTS`, плагин `NobodyWho`, базовую языковую модель `.gguf` и создаст ярлык запуска:

```bash
git clone [https://github.com/Neverm0ree/pinky-ai.git](https://github.com/Neverm0ree/pinky-ai.git) ~/pinky-ai && cd ~/pinky-ai && ./install_pinky.sh
```

Либо запуск установщика напрямую через `curl`:

```bash
curl -fsSL [https://raw.githubusercontent.com/Neverm0ree/pinky-ai/main/install_pinky.sh](https://raw.githubusercontent.com/Neverm0ree/pinky-ai/main/install_pinky.sh) | bash
```

**Запуск на Linux:**
После установки запустить **Pinky AI** можно из меню приложений рабочего стола или командой в терминале:

```bash
~/pinky-ai/build/linux/run_aria.sh
```

---

### 🪟 Установка и запуск на Windows

#### Способ 1: Готовая портативная сборка (рекомендуется)
1. Скачай архив **`PinkyAI-Windows-x64.zip`** из раздела [**Releases**](https://github.com/Neverm0ree/pinky-ai/releases) и распакуй его в любую папку.
2. Запусти **`install_windows_deps.bat`** — скрипт автоматически скачает базовую языковую модель `Qwen2.5-7B-Instruct` (`.gguf`) в папку `models/` и настроит Python-окружения для микрофона (`Faster-Whisper`) и `Pocket-TTS` (при наличии установленного Python 3.10+).
3. Запускай приложение через **`run_pinky.bat`** (или напрямую **`PinkyAI.exe`**).

#### Способ 2: Сборка из исходников
1. Склонируй репозиторий и открой проект в **Godot Engine 4.3+**:
   ```powershell
   git clone [https://github.com/Neverm0ree/pinky-ai.git](https://github.com/Neverm0ree/pinky-ai.git)
   ```
2. Помести библиотеку `libnobodywho-godot-x86_64-pc-windows-msvc-release.dll` в `addons/nobodywho/` и распакуй `piper_windows_amd64.zip` в `tts/piper/`.
3. Экспортируй проект через пресет **`Windows Desktop`** в `build/windows/PinkyAI.exe`.

---

### 🛠️ Ручное добавление моделей и VRM-аватаров

- **Языковые модели (`.gguf`):** помести любой файл `.gguf` в папку `models/` и выбери его в окне **Настройки → Модель ИИ**.
- **3D-аватары (`.vrm` / `.glb`):** помести файлы моделей в папку `avatars/` (или нажми кнопку **«Файл...»** во вкладке **Настройки → Вид и 3D**).
