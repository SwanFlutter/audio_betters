# audio_betters

A professional, high-performance cross-platform audio playback plugin for Flutter.

## Features

- ✅ **Cross-Platform Support**: Android, iOS, macOS, Windows, and Linux.
- ✅ **Network & Local Playback**: Stream audio from URLs or play local files.
- ✅ **Playback Controls**: Play, Pause, Resume, and Stop.
- ✅ **Volume Control**: Fine-grained volume adjustment.
- ✅ **Native Performance**: Uses native APIs (MediaPlayer on Android, AVPlayer on Apple, GStreamer on Linux, and MCI on Windows) for the best efficiency.

## Installation

Add `audio_betters` to your `pubspec.yaml`:

```yaml
dependencies:
  audio_betters: ^0.0.1
```

## Usage

Import the package:

```dart
import 'package:audio_betters/audio_betters.dart';
```

### Initialize the player

```dart
final _audioBettersPlugin = AudioBetters();
```

### Play Audio

```dart
await _audioBettersPlugin.play("https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3");
```

### Pause/Resume

```dart
await _audioBettersPlugin.pause();
await _audioBettersPlugin.resume();
```

### Stop Playback

```dart
await _audioBettersPlugin.stop();
```

### Set Volume

```dart
// Volume range: 0.0 to 1.0
await _audioBettersPlugin.setVolume(0.5);
```

## Platform-Specific Notes

### Android
Requires Internet permission for network playback.
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### macOS/iOS
Ensure `NSAppTransportSecurity` is configured if playing from non-HTTPS sources.

### Linux
Requires `libgstreamer1.0-dev` and `gstreamer1.0-plugins-good` installed on the system.

## License
MIT
