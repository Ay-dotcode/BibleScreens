# ⛪ Bible Screens — Auto Verse Detection

A hands-free, EasyWorship-style Bible verse display for churches.  
Just talk — if you mention a Bible verse, it appears on the output screen automatically.

The app runs as a single Flutter desktop (or web) application. The **control window** (home screen) handles microphone capture, transcript display, and settings. A separate **output window** (`?display=1` on web, or `--display-window` on desktop) shows only the verse — designed to be placed on a projector or second monitor.

---

## ✨ Features

- 🎙 **Continuous microphone listening** — raw audio captured via the `record` package and streamed to Deepgram over a WebSocket for real-time transcription
- 📖 **Smart verse detection** — understands all of these:
  - `John 3:16`
  - `John 3 16`
  - `John three sixteen`
  - `John chapter three verse sixteen`
  - `First Corinthians thirteen four`
  - `Psalms 23` → Psalm 23:1
- 🎤 **Microphone selector** — choose any available input device from a dropdown in the control window
- 📡 **Bible text** fetched from [bible-api.com](https://bible-api.com) — free, no account needed
- 💾 **Local cache** — verses load instantly after first fetch, works offline for cached verses
- 📥 **Full offline download** — download a whole translation once in Settings
- 🖼 **Background image** — set a URL in Settings to show a full-screen image behind the verse text on the output screen
- 🎨 **Worship-style dark display** with elegant typography
- 🖥 **Dual-window output** — the output display screen is a second window (or browser tab) driven by a file-based bridge; the two windows do not need to be on the same machine
- ⚙️ **Settings** — font size, colours, Bible translation (KJV, WEB, ASV, BBE, Darby, DRA, YLT), transcript panel, background image URL, and more

---

## 🚀 Quick Start

### 1. Clone and install dependencies

```bash
git clone https://github.com/Ay-dotcode/bible_screens.git
cd bible_screens
flutter pub get
```

### 2. Run

```bash
# Windows (primary development target)
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux

# Web (opens control window; add ?display=1 in a second tab for the output screen)
flutter run -d chrome
```

### 3. Open the output screen

**Desktop:** launch a second instance of the app with the `--display-window` flag, or move to a second monitor — the control window publishes state via a shared JSON file that the output window polls every 250 ms.

**Web:** open a second browser tab and add `?display=1` to the URL.

---

## 🖥 Platform Setup

### Windows

The app captures audio using the `record` package and streams it to Deepgram. No additional OS configuration is required beyond allowing microphone access when Windows prompts for it.

### macOS

`macos/Runner/Info.plist` already includes the required permissions:

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

Also enable the network entitlement (needed to reach Deepgram and bible-api.com).  
In `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`, add:

```xml
<key>com.apple.security.network.client</key>
<true/>
```

### Linux

Install the ALSA / PulseAudio development headers required by the `record` package:

```bash
sudo apt-get install -y libasound2-dev libpulse-dev
```

---

## 🗣 How It Works

1. Press the **🎙 mic button** in the control window to start listening.
2. Raw PCM audio is captured from the selected microphone at 16 kHz mono and streamed over a WebSocket to Deepgram's `nova-3` model.
3. Deepgram returns interim and final transcripts. The live transcript is displayed at the bottom of the control window.
4. `VerseDetector` scans every transcript update for a Bible verse reference.
5. When a reference is found, `BibleService` fetches the verse text (from cache or bible-api.com).
6. The verse is written to a shared JSON state file via `SecondDisplayBridge`.
7. The output display screen polls that file every 250 ms and re-renders whenever the state changes.
8. Press **✕** to clear the screen, or the mic button again to stop listening.

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

| Setting                    | Description                                                 |
| -------------------------- | ----------------------------------------------------------- |
| **Translation**            | KJV, WEB, ASV, BBE, Darby, DRA, YLT                         |
| **Verse font size**        | 24–100 px                                                   |
| **Reference font size**    | 14–60 px                                                    |
| **Font family**            | Georgia, Palatino, Times New Roman, etc.                    |
| **Verse colour**           | Colour of the verse text on the output screen               |
| **Reference colour**       | Colour of the book/chapter/verse label                      |
| **Background colour**      | Solid background colour (used when no image is set)         |
| **Background image URL**   | Optional full-screen image behind the verse (any HTTPS URL) |
| **Show translation badge** | Toggle KJV/WEB/etc. badge                                   |
| **Show reference**         | Toggle book/chapter/verse label                             |
| **Live transcript**        | Show/hide bottom transcript panel                           |
| **Transcript opacity**     | Adjust panel transparency                                   |
| **Download now**           | Downloads the full selected translation for offline use     |

---

## 📦 Dependencies

| Package              | Purpose                                                            |
| -------------------- | ------------------------------------------------------------------ |
| `record`             | Capture raw PCM audio from the microphone                          |
| `web_socket_channel` | Stream audio to Deepgram and receive transcripts over WebSocket    |
| `http`               | Fetch verse text from bible-api.com                                |
| `path_provider`      | Locate the app's documents directory (cache, settings, state file) |
| `path`               | File path utilities                                                |
| `web`                | Web-platform interop (used by the web bridge)                      |
| `cupertino_icons`    | Icons                                                              |

> **Speech-to-text backend:** Deepgram (`nova-3` model, `wss://api.deepgram.com/v1/listen`).  
> An API key is embedded in `lib/services/speech_service.dart`. Replace it with your own key from [deepgram.com](https://deepgram.com) if you plan to deploy publicly.

---

## 🔒 Privacy

- Audio is streamed to **Deepgram** for transcription — it does not stay on-device.
- Only the verse reference (e.g. `john+3:16`) is sent to bible-api.com.
- Settings and cached verses are stored locally in the app's documents folder.
- No account, login, or telemetry beyond the above.

---

## 🛠 Troubleshooting

**Mic button stuck on "initialising"**  
→ Deepgram connection failed. Check your internet connection and that the API key in `speech_service.dart` is valid.

**Verse not detected**  
→ Speak clearly. The detector needs at least a book name plus two numbers (or their word equivalents).  
→ Watch the live transcript to see exactly what Deepgram heard.

**Verse text not loading**  
→ Check your internet connection. bible-api.com must be reachable.  
→ On macOS, ensure the network entitlement is set in the `.entitlements` files.

**Output screen not updating**  
→ Make sure both windows are running from the same user account (they share the same app documents directory).  
→ On web, ensure the second tab has `?display=1` in its URL.

**Wrong verse displayed**  
→ The detector always uses the most recent valid reference heard. Press ✕ to clear and start fresh.

---

## 🧱 Project Structure

```
bible_screens/
├── lib/                          # All Dart application code
│   ├── main.dart                 # Entry point — boots the app; accepts --display-window flag
│   ├── app.dart                  # Root widget (ChurchDisplayApp); routes to control or output screen
│   │
│   ├── core/
│   │   └── theme/
│   │       └── app_theme.dart    # Shared colour constants and MaterialTheme (dark)
│   │
│   ├── models/                   # Plain data classes (no Flutter dependency)
│   │   ├── app_settings.dart     # All user preferences; loads/saves as JSON; singleton
│   │   ├── bible_verse.dart      # BibleVerse and VerseReference value objects
│   │   └── second_display_state.dart  # Snapshot of everything the output screen needs to render
│   │
│   ├── screens/                  # Full-screen UI widgets
│   │   ├── home_screen.dart      # Control window — mic button, transcript panel, verse preview,
│   │   │                         #   microphone selector, background-image dialog
│   │   ├── output_display_screen.dart  # Output (projector) window — renders verse text over
│   │   │                               #   optional background image; driven by SecondDisplayBridge
│   │   └── settings_screen.dart  # Settings drawer — fonts, colours, translation, offline download
│   │
│   ├── services/                 # Business logic and external integrations
│   │   ├── speech_service.dart   # Captures raw PCM audio via `record`, streams to Deepgram
│   │   │                         #   over WebSocket, exposes transcriptStream / stateStream /
│   │   │                         #   errorStream / audioLevelStream; handles mic enumeration
│   │   ├── verse_detector.dart   # Stateless parser — scans a transcript string for the most
│   │   │                         #   recent Bible verse reference and returns a VerseReference
│   │   ├── bible_service.dart    # Fetches verse text from bible-api.com; caches to disk as JSON;
│   │   │                         #   supports full offline translation download
│   │   ├── second_display_bridge.dart       # Conditional export — picks the right bridge impl
│   │   ├── second_display_bridge_io.dart    # Desktop/native bridge: writes state to a JSON file,
│   │   │                                    #   polls the file every 250 ms for the output screen
│   │   ├── second_display_bridge_web.dart   # Web bridge: uses a BroadcastChannel between tabs
│   │   └── second_display_bridge_stub.dart  # No-op stub for unsupported platforms
│   │
│   └── utils/                    # Pure utility/data helpers
│       ├── bible_books.dart      # Complete list of all 66 Bible books with canonical names,
│       │                         #   API slugs, and recognised aliases (abbreviations, ordinals)
│       ├── bible_chapters.dart   # Chapter counts per book — used for offline download pagination
│       ├── color_compat.dart     # Extension that back-ports Color.withValues() for older Flutter
│       └── number_words.dart     # Converts English number words to digits ("three" → "3",
│                                 #   "first" → "1", "twenty two" → "22")
│
├── test/                         # Automated tests
│   ├── widget_test.dart          # Basic widget smoke test
│   └── services/
│       └── verse_detector_test.dart  # Unit tests for VerseDetector parsing logic
│
├── third_party/                  # Vendored packages not available on pub.dev
│   └── speech_to_text_windows/   # Local fork/patch of speech_to_text for Windows compatibility
│
├── android/                      # Android platform project (not a primary target)
├── ios/                          # iOS platform project (not a primary target)
├── macos/                        # macOS platform project — entitlements and Info.plist edits needed
├── windows/                      # Windows platform project — primary desktop target
├── linux/                        # Linux platform project
└── web/                          # Web platform project — index.html; supports dual-tab output mode
```

### Key data-flow summary

```
Microphone
  └─► speech_service.dart  (raw PCM → Deepgram WebSocket → transcript text)
        └─► verse_detector.dart  (transcript → VerseReference?)
              └─► bible_service.dart  (VerseReference → verse text, from cache or API)
                    └─► SecondDisplayBridge  (writes SecondDisplayState to shared file/channel)
                          └─► output_display_screen.dart  (polls state → renders verse + background)
```
