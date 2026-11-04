# 🌸 Pinky AI — Local 3D AI Companion for Linux

A fully autonomous 3D assistant and companion built with **Godot 4**, running locally without cloud APIs:

- **🧠 Local LLMs (GGUF):** support for `Qwen2.5`, `Qwen3`, and `LFM3` models via the `NobodyWho` plugin with automatic filtering of `<think>` reasoning blocks.

- **🗣️ Dual Text-to-Speech (TTS):** instant offline synthesis via `Piper TTS` and neural `Kyutai Pocket-TTS` with lip-sync (FFT lip-sync) and emotions.

- **🎙️ Speech-to-Text (STT):** push-to-talk voice input and a continuous live call mode powered by `Faster-Whisper` (`PipeWire` / `ALSA`).

- **🎭 Hot-Swappable 3D Models:** support for `.vrm` and `.glb` custom character avatars directly from the settings.

- **⚡ Visual Terminal Automation:** built-in node editor (`GraphEdit`) for creating `zsh` command pipelines and voice triggers.


---

## 🚀 Quick Installation on Linux (One-Command)

This command will automatically install system packages (`Arch / CachyOS`, `Ubuntu / Debian`, `Fedora`), configure Python virtual environments for voice and microphone, download the `Piper TTS` engine, the `NobodyWho` plugin, a baseline `.gguf` language model, and create a shortcut:

```bash
git clone [https://github.com/Neverm0ree/pinky-ai.git](https://github.com/Neverm0ree/pinky-ai.git) ~/pinky-ai && cd ~/pinky-ai && ./install_pinky.sh

# 🌸 Pinky AI — Локальный 3D ИИ-компаньон для Linux

Полностью автономный 3D-ассистент и компаньон на базе **Godot 4**, работающий локально без облачных API:

* **🧠 Локальные LLM (GGUF):** поддержка моделей `Qwen2.5`, `Qwen3`, `LFM3` через плагин `NobodyWho` с автоматической фильтрацией блоков размышлений `<think>`.
* **🗣️ Двойной синтез речи (TTS):** мгновенный офлайн-синтез через `Piper TTS` и нейросетевой `Kyutai Pocket-TTS` с синхронизацией губ (FFT-липсинк) и эмоций.
* **🎙️ Распознавание голоса (STT):** голосовой ввод по кнопке и режим непрерывного живого звонка на базе `Faster-Whisper` (`PipeWire` / `ALSA`).
* **🎭 Горячая смена 3D-моделей:** поддержка пользовательских аватаров формата `.vrm` и `.glb` прямо из настроек.
* **⚡ Визуальная автоматизация терминала:** встроенный нодовый редактор (`GraphEdit`) для создания цепочек команд `zsh` и голосовых триггеров.

---

## 🚀 Быстрая установка на Linux (в одну команду)

Эта команда автоматически установит системные пакеты (`Arch / CachyOS`, `Ubuntu / Debian`, `Fedora`), настроит виртуальные окружения Python для голоса и микрофона, скачает движок `Piper TTS`, плагин `NobodyWho`, базовую языковую модель `.gguf` и создаст ярлык запуска:

```bash
git clone https://github.com/Neverm0ree/pinky-ai.git ~/pinky-ai && cd ~/pinky-ai && ./install_pinky.sh
```

Либо запуск установщика напрямую через `curl`:

```bash
curl -fsSL https://raw.githubusercontent.com/Neverm0ree/pinky-ai/main/install_pinky.sh | bash
```

---

## 🎮 Запуск приложения

После установки запустить **Pinky AI** можно из меню приложений твоего рабочего стола или командой в терминале:

```bash
~/pinky-ai/build/linux/run_aria.sh
```

---

## 🛠️ Ручное добавление моделей и VRM-аватаров

* **Языковые модели (`.gguf`):** помести любой файл `.gguf` в папку `models/` и выбери его в окне **Настройки → Модель ИИ**.
* **3D-аватары (`.vrm` / `.glb`):** помести файлы моделей в папку `avatars/` (или нажми кнопку **«Файл...»** во вкладке **Настройки → Вид и 3D**).
