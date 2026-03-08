# ⛪ Church Display — Auto Verse Detection

A human-free, EasyWorship-style Bible verse display for churches.  
Just talk — if you mention a Bible verse, it appears on screen automatically.

---

## ✨ Features

- 🎙 **Continuous microphone listening** using your device's built-in speech engine (free, no API key)
- 📖 **Smart verse detection** — understands all of these:
  - `John 3:16`
  - `John 3 16`
  - `John three sixteen`
  - `John chapter three verse sixteen`
  - `First Corinthians thirteen four`
  - `Psalms 23` → Psalm 23:1
- 📡 **Bible text** fetched from [bible-api.com](https://bible-api.com) — free, no account needed
- 💾 **Local cache** — verses load instantly after first fetch, works offline for cached verses
- 🎨 **Worship-style dark display** with elegant typography
- ⚙️ **Settings** — font size, Bible translation (KJV, WEB, ASV, BBE, Darby, DRA, YLT), transcript panel, and more

---

## 🚀 Quick Start

### 1. Create a new Flutter project

```bash
flutter create church_display
cd church_display
```

### 2. Replace files

Copy all files from this repo into your project, overwriting defaults:

```
lib/          → replace entirely
macos/Runner/Info.plist → replace (macOS only)
pubspec.yaml  → replace
```

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Run

```bash
# macOS
flutter run -d macos

# Windows
flutter run -d windows

# Linux
flutter run -d linux
```

---

## 🖥 Platform Setup

### macOS

The `macos/Runner/Info.plist` file in this repo already includes the required permissions:

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

**Also enable the network entitlement** (needed to reach bible-api.com).  
In `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`, add:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

### Windows

1. Make sure **Windows Speech Recognition** is enabled:  
   `Settings → Time & Language → Speech → Windows Speech Recognition`
2. No additional code changes required.

### Linux

Install the `speech_dispatcher` library:

```bash
sudo apt-get install -y libspeechd-dev speech-dispatcher
```

> **Note:** Linux STT support is limited. The `speech_to_text` package uses speech-dispatcher,
> which may require additional configuration. Alternatively, set up a Google STT API key
> and use the `speech_to_text` package's `sttConfigure` option.

---

## 🗣 How It Works

1. Press the **🎙 mic button** in the top-right corner to start listening.
2. Speak naturally during the service. The live transcript appears at the bottom.
3. Whenever a Bible verse reference is detected, the verse text is fetched and displayed instantly.
4. Press **✕** to clear the screen, or the mic button again to pause.

### Verse Detection Examples

| You say                                  | Detected           |
| ---------------------------------------- | ------------------ |
| `John three sixteen`                     | John 3:16          |
| `Romans eight twenty-eight`              | Romans 8:28        |
| `First Corinthians thirteen four`        | 1 Corinthians 13:4 |
| `Psalms 23`                              | Psalms 23:1        |
| `Second Kings chapter seven verse three` | 2 Kings 7:3        |
| `Rev 22 20`                              | Revelation 22:20   |

---

## ⚙️ Settings (accessible from the gear icon)

| Setting                    | Description                              |
| -------------------------- | ---------------------------------------- |
| **Translation**            | KJV, WEB, ASV, BBE, Darby, DRA, YLT      |
| **Verse font size**        | 24–100px                                 |
| **Reference font size**    | 14–60px                                  |
| **Font family**            | Georgia, Palatino, Times New Roman, etc. |
| **Show translation badge** | Toggle KJV/WEB/etc. badge                |
| **Show reference**         | Toggle book/chapter/verse label          |
| **Live transcript**        | Show/hide bottom transcript panel        |
| **Transcript opacity**     | Adjust panel transparency                |

---

## 📦 Dependencies

All free, no API keys required:

| Package             | Purpose                                     |
| ------------------- | ------------------------------------------- |
| `speech_to_text`    | Microphone + speech-to-text (device native) |
| `http`              | Fetch verse text from bible-api.com         |
| `path_provider`     | Locate cache/settings directory             |
| `path`              | File path utilities                         |
| `animated_text_kit` | Text animations                             |

---

## 🔒 Privacy

- **No data leaves your device** except the verse reference sent to bible-api.com (e.g. `john+3:16`).
- Speech recognition runs entirely **on-device** using your OS's built-in engine.
- No account, no login, no telemetry.

---

## 🛠 Troubleshooting

**"Speech recognition not available"**  
→ Make sure your OS speech engine is configured and your microphone is working.

**Verse not detected**  
→ Speak clearly. The app needs at least a book name + two numbers (or word equivalents).  
→ Check the live transcript at the bottom to see what was heard.

**Verse text not loading**  
→ Check your internet connection. bible-api.com must be reachable.  
→ On macOS, ensure the network entitlement is set in `.entitlements` files.

**Wrong verse displayed**  
→ The detector uses the most recent valid reference it hears. If stale transcript text remains, press ✕ to clear and restart listening.

---

## 🧱 Project Structure

```text
lib/
  core/
    theme/
      app_theme.dart
  models/
    app_settings.dart
    bible_verse.dart
  screens/
    home_screen.dart
    settings_screen.dart
  services/
    speech_service.dart
    verse_detector.dart
    bible_service.dart
  utils/
    bible_books.dart
    number_words.dart
  app.dart
  main.dart
```

This keeps UI, domain models, and integrations separate so you can add future features (song lyrics, overlays, scheduling, remote control) without rewriting existing modules.
