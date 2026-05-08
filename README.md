# audio_betters

A professional, high-performance cross-platform audio plugin for Flutter, supporting playback and recording with native efficiency.

## Features

- ✅ **Cross-Platform Support**: Android, iOS, macOS, Windows, and Linux.
- ✅ **High-Quality Recording**: Record audio in **AAC** or **WAV** formats.
- ✅ **Advanced Recording Controls**: Set maximum duration limits for recordings.
- ✅ **Network & Local Playback**: Stream audio from URLs or play local files (mp3, wav, m4a, etc.).
- ✅ **Playback Controls**: Play, Pause, Resume, and Stop.
- ✅ **Progress Tracking**: Real-time access to audio **Duration** and **Current Position**.
- ✅ **Volume Control**: Fine-grained volume adjustment (0.0 to 1.0).
- ✅ **Native Performance**: Uses optimized native APIs:
    - **Android**: MediaPlayer & MediaRecorder
    - **iOS/macOS**: AVPlayer & AVAudioRecorder
    - **Windows**: MCI (winmm.lib)
    - **Linux**: GStreamer

## Installation

Add `audio_betters` to your `pubspec.yaml`:

```yaml
dependencies:
  audio_betters:
    path: path/to/audio_betters
```

## Usage

### Playback

```dart
final _audio = AudioBetters();

// Play from URL or Local Path
await _audio.play("https://example.com/audio.mp3");

// Control Playback
await _audio.pause();
await _audio.resume();
await _audio.stop();

// Get Progress
int duration = await _audio.getDuration(); // milliseconds
int position = await _audio.getCurrentPosition(); // milliseconds

// Set Volume
await _audio.setVolume(0.8);
```

### Recording

```dart
final _audio = AudioBetters();

// Start Recording with options
await _audio.startRecorder(
  "path/to/save/audio.m4a",
  format: AudioFormat.aac, // or AudioFormat.wav
  maxDuration: 60000, // Optional: auto-stop after 60 seconds
);

// Stop Recording
await _audio.stopRecorder();
```

## Platform-Specific Setup

### Android
Add these permissions to your `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

### iOS / macOS
Add these keys to your `Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need access to the microphone for recording audio.</string>
```

### Linux
Ensure GStreamer is installed:
```bash
sudo apt-get install libgstreamer1.0-dev gstreamer1.0-plugins-good gstreamer1.0-plugins-bad
```

## License
MIT
