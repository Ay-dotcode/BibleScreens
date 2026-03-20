# Bible Screens

Church presentation app built with Flutter.

Bible Screens listens for spoken Bible references (for example, `John 3:16`), detects the reference in realtime, fetches verse text, and sends output to a dedicated display window for projection.

## What it does

- Live speech transcription (Deepgram over WebSocket)
- Automatic Bible reference detection from transcript text
- Manual verse search with queue + push controls
- Song search from bundled EasyWorship-style SQLite databases
- Lyrics slide push to output display
- Dedicated output window mode for second display / projector
- Output customization (theme, fonts, transition, background image)
- Translation selection (`KJV`, `WEB`, `ASV`, `BBE`, `DARBY`, `DRA`, `YLT`)
- Local verse caching and optional translation preload

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

## Speech configuration + API key

Speech streaming is implemented in `lib/services/speech_service.dart` and currently targets Deepgram `nova-3`.

Deepgram is authenticated using `_apiKey` in that file.

### Set or change the key

1. Open `lib/services/speech_service.dart`
2. Find:

   ```dart
   static const String _apiKey = 'YOUR_DEEPGRAM_API_KEY';
   ```

3. Replace with your Deepgram key.

For production, do not commit API keys in source. Use secure runtime configuration instead.

## Data + services

- Bible text source: `https://bible-api.com`
- Verse detection/parser: `lib/services/verse_detector.dart`
- Display sync bridge: `lib/services/second_display_bridge.dart`
- Song library: `assets/databases/*.db` via `lib/services/song_db_service.dart`

## Full project structure

```text
bible_screens/
├── analysis_options.yaml
├── pubspec.yaml
├── README.md
├── settings.json
├── android/
│   ├── build.gradle.kts
│   ├── gradle.properties
│   ├── local.properties
│   ├── settings.gradle.kts
│   ├── app/
│   │   ├── build.gradle.kts
│   │   └── src/
│   └── gradle/
│       └── wrapper/
├── assets/
│   └── databases/
│       ├── Songs.db
│       ├── SongWords.db
│       └── SongHistory.db
├── build/
│   ├── flutter_assets/
│   ├── native_assets/
│   ├── native_hooks/
│   ├── windows/
│   └── ...
├── ios/
│   ├── Flutter/
│   ├── Runner/
│   ├── Runner.xcodeproj/
│   ├── Runner.xcworkspace/
│   └── RunnerTests/
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
│   │   ├── bible_service.dart
│   │   ├── image_service.dart
│   │   ├── second_display_bridge.dart
│   │   ├── second_display_bridge_io.dart
│   │   ├── second_display_bridge_stub.dart
│   │   ├── second_display_bridge_web.dart
│   │   ├── song_db_service.dart
│   │   ├── speech_service.dart
│   │   └── verse_detector.dart
│   └── utils/
│       ├── bible_books.dart
│       ├── bible_chapters.dart
│       ├── color_compat.dart
│       ├── number_words.dart
│       └── rtf_parser.dart
├── linux/
│   ├── CMakeLists.txt
│   ├── flutter/
│   └── runner/
├── macos/
│   ├── Flutter/
│   ├── Runner/
│   ├── Runner.xcodeproj/
│   ├── Runner.xcworkspace/
│   └── RunnerTests/
├── test/
│   ├── widget_test.dart
│   └── services/
├── third_party/
│   └── speech_to_text_windows/
├── web/
│   ├── index.html
│   ├── manifest.json
│   └── icons/
└── windows/
	├── CMakeLists.txt
	├── flutter/
	└── runner/
```

## Development

```bash
flutter analyze
flutter test
```

## Notes

- First-time verse requests require network unless the verse is already cached.
- Translation preload can take time depending on translation size and connection speed.
- Desktop second-display behavior can vary by platform/window manager.
