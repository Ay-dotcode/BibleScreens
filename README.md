# Bible Screens

Church presentation app built with Flutter.

Bible Screens listens for spoken Bible references (for example, `John 3:16`), detects the reference in realtime, fetches verse text, and sends output to a dedicated display window for projection.

## What it does

- Live speech transcription (local Vosk model)
- Automatic Bible reference detection from transcript text
- Manual verse search with queue + push controls
- Song search from bundled song database SQLite files
- Lyrics slide push to output display
- Dedicated output window mode for second display / projector
- Output customization (theme, fonts, transition, background image)
- Translation selection (`KJV`, `AKJV`, `RNKJV`, `WEB`, `ASV`, `ACV`, `BBE`, `YLT`)
- Fully local Bible text (bundled XML assets; no verse download step)

## Requirements

- Flutter SDK installed
- Dart SDK `>=3.2.0 <4.0.0`
- A supported target (Windows, Linux, macOS, or Web)
- Microphone permission enabled on the host OS

## Quick start

1. Install dependencies:

```bash
flutter pub get
```

2. Run the control app (example: Windows):

```bash
flutter run -d windows -t lib/main.dart
```

Replace `windows` with your preferred device (`linux`, `macos`, `chrome`, etc.).

## Display window mode

### Desktop

Run a second instance in display-only mode:

```bash
flutter run -d windows -t lib/main.dart --dart-entrypoint-args=--display-window
```

`--display` is also supported.

### Web

Open any of these routes/URL patterns:

- `?display=1`
- `/display`
- `#display=1`

## Keyboard shortcuts (control screen)

- `F5`: start / stop listening
- `Space`: push next queued item (or current search result)
- `Esc`: clear live output
- `Ctrl+F`: focus verse search
- `ArrowDown`: push first queued verse

## Speech model setup

Speech recognition is implemented in `lib/services/speech_service.dart` using the local Vosk model service.

If no model is installed yet, the app prompts for model download from the Home screen.

Model management is handled in `lib/services/vosk_model_service.dart`.

No API key is required for speech recognition.

## Data + services

- Bible text source: bundled XML files in `assets/bibles/`
- Verse detection/parser: `lib/services/verse_detector.dart`
- Display sync bridge: `lib/services/second_display_bridge.dart`
- Song database: `assets/databases/*.db` via `lib/services/song_db_service.dart`

## Full project structure

```text
bible_screens/
├── analysis_options.yaml
├── pubspec.yaml
├── README.md
├── settings.json
├── assets/
│   ├── bibles/
│   │   ├── ACV.xml
│   │   ├── AKJV.xml
│   │   ├── ASV.xml
│   │   ├── BBE.xml
│   │   ├── KJV.xml
│   │   ├── RNKJV.xml
│   │   ├── WEB.xml
│   │   └── YLT.xml
│   └── databases/
├── lib/
│   ├── app.dart
│   ├── main.dart
│   ├── core/
│   │   └── theme/
│   ├── models/
│   │   ├── app_settings.dart
│   │   ├── bible_verse.dart
│   │   ├── second_display_state.dart
│   │   └── song.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── output_display_screen.dart
│   │   ├── settings_screen.dart
│   │   └── song_search_screen.dart
│   ├── services/
│   │   ├── app_storage_service.dart
│   │   ├── bible_service.dart
│   │   ├── image_service.dart
│   │   ├── second_display_bridge.dart
│   │   ├── second_display_bridge_io.dart
│   │   ├── second_display_bridge_stub.dart
│   │   ├── second_display_bridge_web.dart
│   │   ├── song_db_service.dart
│   │   ├── speech_service.dart
│   │   ├── verse_detector.dart
│   │   └── vosk_model_service.dart
│   ├── utils/
│   │   └── ...
│   └── widgets/
│       └── ...
├── test/
│   ├── widget_test.dart
│   └── services/
├── android/
├── ios/
├── linux/
├── macos/
├── web/
├── windows/
└── third_party/
   └── speech_to_text_windows/
```

## Runtime data directory

At runtime, writable app data is stored under a central Documents folder:

```text
Documents/
└── Bible Screen/
   ├── settings.json
   ├── song_database/
   ├── images/
   ├── vosk_models/
   └── state/
```

## Development

```bash
flutter analyze
flutter test
```

## Notes

- Bible verses are read from local bundled assets and work offline.
- Internet is only needed for optional image URL downloads.
- Desktop second-display behavior can vary by platform/window manager.
