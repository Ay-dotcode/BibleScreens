# Bible Screens

Human-free church worship display built with Flutter.

The app listens for spoken Bible references (for example, `John 3:16`), detects the verse reference, fetches the verse text, and pushes it to a clean output display window for projection.

## Features

- Live speech-to-text using Deepgram (WebSocket streaming)
- Automatic Bible verse detection from transcript text
- Manual verse search and instant push to output
- Verse queue and quick history controls
- Lyrics mode (split text into slides and push to output)
- Second display / projector output mode
- Customizable output style:
  - Theme mode (light/dark/system)
  - Font family and font sizes
  - Verse transition animation
  - Background image from local file or URL
- Translation selection (`KJV`, `WEB`, `ASV`, `BBE`, `DARBY`, `DRA`, `YLT`)
- Offline-friendly verse cache (local JSON cache)
- Optional full translation preload for offline use

## Tech Stack

- Flutter (desktop + web capable)
- Dart SDK `>=3.2.0 <4.0.0`
- `record` for microphone capture
- `web_socket_channel` for Deepgram realtime transcription
- `http` for bible-api.com verse fetching
- `window_manager` for desktop display window behavior
- `path_provider`, `path`, `file_picker` for local file/cache handling

## Getting Started

### 1. Prerequisites

- Flutter SDK installed and configured
- A desktop target enabled (Linux/Windows/macOS) for projector workflows
- Microphone permission enabled for the app

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run the control app

```bash
flutter run -d linux -t lib/main.dart
```

Replace `linux` with your target device when needed.

## Running Display Window Mode

The app supports a dedicated output-only window.

### Desktop output window

Run a second instance with display arguments:

```bash
flutter run -d linux -t lib/main.dart --dart-entrypoint-args=--display-window
```

You can also use `--display` as the argument value.

### Web output mode

Open the app with one of these URL forms:

- `?display=1`
- `/display`
- `#display=1`

## Keyboard Shortcuts (Control Screen)

- `F5`: Start/stop listening
- `Space`: Push next queued item (or current search result)
- `Esc`: Clear live output
- `Ctrl+F`: Focus verse search
- `ArrowDown`: Push first queued verse

## Configuration Notes

- Speech transcription currently uses Deepgram (`nova-3`) in `lib/services/speech_service.dart`.
- Bible verses are fetched from `https://bible-api.com` and cached locally by `BibleService`.
- Output state is bridged to the display window through `SecondDisplayBridge`.

## Project Structure

```text
bible_screens/
├── .github/
│   └── workflows/
├── lib/
│   ├── main.dart                      # App entrypoint and window mode bootstrapping
│   ├── app.dart                       # MaterialApp and display/control routing
│   ├── pubspec.lock
│   ├── core/
│   │   └── theme/                     # Theme definitions
│   │       └── app_theme.dart
│   ├── models/
│   │   ├── app_settings.dart          # Persisted user settings and output styling
│   │   ├── bible_verse.dart           # Verse/reference data model
│   │   └── second_display_state.dart  # State payload for output display
│   ├── screens/
│   │   ├── home_screen.dart           # Main control UI (speech, queue, lyrics)
│   │   ├── output_display_screen.dart # Projector/second-display render surface
│   │   └── settings_screen.dart       # App + output customization settings
│   ├── services/
│   │   ├── bible_service.dart         # Bible API calls, local cache, offline preload
│   │   ├── image_service.dart         # Background image picker/download/cache
│   │   ├── speech_service.dart        # Mic capture + Deepgram WebSocket streaming
│   │   ├── verse_detector.dart        # Reference parser from transcript/search input
│   │   ├── second_display_bridge.dart # Platform bridge export (io/web/stub)
│   │   ├── second_display_bridge_io.dart
│   │   ├── second_display_bridge_web.dart
│   │   └── second_display_bridge_stub.dart
│   └── utils/
│       ├── bible_books.dart           # Book aliases and API-safe path mapping
│       ├── bible_chapters.dart        # Canonical chapter counts for preload
│       ├── number_words.dart          # Number-word normalization helpers
│       └── color_compat.dart          # Cross-version color helpers
├── test/
│   ├── widget_test.dart
│   └── services/
│       └── verse_detector_test.dart
├── android/                           # Android host project
├── ios/                               # iOS host project
├── linux/                             # Linux host project
├── macos/                             # macOS host project
├── windows/                           # Windows host project
├── web/                               # Web host assets
├── third_party/
│   └── speech_to_text_windows/
├── settings.json
├── pubspec.yaml                       # Dependencies and package metadata
├── pubspec.lock
├── analysis_options.yaml              # Lint rules
└── README.md
```

## Development Commands

```bash
flutter analyze
flutter test
```

## Known Notes

- Network is required for first-time verse fetches unless the verse/chapter was already cached.
- Offline preload may take time depending on translation size and internet speed.
- Desktop second-display behavior depends on platform window manager support.
