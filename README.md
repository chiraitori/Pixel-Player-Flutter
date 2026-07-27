# PixelPlayer (Flutter)

A modern, expressive, feature-rich Android & cross-platform music player written in Flutter & Dart. Ported with precision from the original Android Jetpack Compose application ([PixelPlayer](https://github.com/PixelPlayerHQ/PixelPlayer)) to deliver smooth animations, dynamic Material 3 aesthetics, and seamless local & cloud playback.

---

## 🎨 Features & Highlights

- **Material 3 & Dynamic Colors**: Elegant user interface powered by Google Sans Flex, dynamic theme extraction from album artwork (`palette_generator` / Material Utilities), and smooth micro-animations.
- **Offline & Local Library**: Scans local storage, metadata, embedded lyrics, playlists, album arts, genres, folders, and artist details seamlessly.
- **Cloud & Remote Streaming**: Integrated support for Google Drive, Jellyfin, and Navidrome remote music libraries.
- **Synchronized Lyrics**: Built-in LRC parser and interactive synchronized lyrics viewer with automatic auto-scroll.
- **Smart Recommendations & Mixes**: Daily Mix algorithm, Recently Played section, and detailed weekly playback statistics.
- **Deck & Transition Effects**: Advanced audio playback controls with customizable gapless transitions, audio equalizer, and dual-deck mashup support.
- **Background Playback & Notification Controls**: Fully integrated with Android `AudioService` & system lockscreen media controls.

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.12.2` or later)
- [Android Studio](https://developer.android.com/studio) / Android SDK (for Android build)
- [Dart SDK](https://dart.dev/get-dart)

### Installation & Running

1. **Clone the Repository**
   ```bash
   git clone https://github.com/chiraitori/Pixel-Player-Flutter.git
   cd Pixel-Player-Flutter
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the Application**
   ```bash
   flutter run
   ```

---

## 🛠️ Tech Stack & Architecture

- **Framework**: Flutter (`3.x`)
- **State Management & DI**: InheritedWidget / Provider Scope pattern
- **Audio Engine**: `just_audio`, `audio_service`, `just_audio_background`
- **Metadata & Audio Query**: `on_audio_query_android`, `flutter_taglib`, `id3`
- **UI & Animation**: Material 3, `dynamic_color`, Google Sans Flex font

---

## 💡 Acknowledgements & Credits

This Flutter port is directly based on and inspired by the original Android Compose application:
- **Original Android App**: [PixelPlayerHQ/PixelPlayer](https://github.com/PixelPlayerHQ/PixelPlayer) by [Theveloper](https://github.com/PixelPlayerHQ).

---

## 🔗 Links & Community

- **GitHub Repository**: [chiraitori/Pixel-Player-Flutter](https://github.com/chiraitori/Pixel-Player-Flutter)
- **Issue Tracker**: [Report Bugs & Request Features](https://github.com/chiraitori/Pixel-Player-Flutter/issues)

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for details.
