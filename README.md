# audio_betters

A Flutter plugin for **audio playback, recording, and hands-free voice conversation** across all major platforms — Android, iOS, macOS, Windows, Linux, and Web — using each platform's native audio engine.

New in 1.0.0: **Conversation Mode** — a ChatGPT-voice-style, voice-activated capture loop. One button tap opens the microphone; every utterance is detected automatically and finalized into its own audio file, ready to send to your AI backend.

---

## Platform Support

| Platform | Playback | Recording | Mic Metering (VAD) | Engine |
|----------|----------|-----------|--------------------|--------|
| Android  | ✅ | ✅ | ✅ | MediaPlayer / MediaRecorder (`getMaxAmplitude`) |
| iOS      | ✅ | ✅ | ✅ | AVPlayer / AVAudioRecorder (`averagePower`) |
| macOS    | ✅ | ✅ | ✅ | AVPlayer / AVAudioRecorder (`averagePower`) |
| Windows  | ✅ | ✅ | ✅ | MCI (winmm) + `waveIn` metering |
| Linux    | ✅ | ✅ | ✅ | GStreamer (`level` probe) |
| Web      | ✅ | ✅ | ✅ | HTMLAudioElement / MediaRecorder + Web Audio analyser |

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  audio_betters: ^1.0.0
```

Then run:

```bash
flutter pub get
```

> **Requirements:** Flutter ≥ 3.44 / Dart ≥ 3.12 (the Android build uses
> Flutter's Built-in Kotlin support — the plugin no longer applies KGP itself).
> On AGP 9 apps, do not add `kotlin-android` back; Kotlin target is configured
> via `kotlin { compilerOptions { … } }` in `android/build.gradle.kts`.

---

## Platform Setup

### Android

Add microphone permission to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to record audio.</string>
```

### macOS

Add to `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:

```xml
<key>com.apple.security.device.audio-input</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

### Linux

Install GStreamer development libraries:

```bash
sudo apt install \
  libgstreamer1.0-dev \
  gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-libav
```

### Windows

No additional setup required. The plugin uses the built-in `winmm` (Windows Multimedia) library.

> **Example app note:** `permission_handler_windows` needs a *real* `nuget.exe`
> visible to CMake (`find_program`) to fetch C++/WinRT headers. If your nuget
> was installed via winget, its shim in `WinGet\Links` may not be detected and
> the plugin falls back to an ancient v6.0.0 download that can no longer reach
> nuget.org. Fix: copy the actual `nuget.exe` (e.g. from
> `%LOCALAPPDATA%\Microsoft\WinGet\Packages\Microsoft.NuGet_*\`) into a folder on
> your `PATH`, then restart the IDE/terminal.

### Web

No additional setup required. The plugin uses the browser's native `HTMLAudioElement`, `MediaRecorder`, and Web Audio APIs. The browser prompts for microphone access automatically.

> **Note:** Browsers block autoplay until the user interacts with the page. Always trigger playback from a user gesture (button tap, etc.).

---

## Usage

### Import

```dart
import 'package:audio_betters/audio_betters.dart';
```

### Initialize

```dart
final audio = AudioBetters();
```

---

## Playback

### Play from URL (network)

```dart
await audio.play('https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3');
```

### Play from local file

```dart
await audio.play('/storage/emulated/0/Music/song.mp3');  // Android
await audio.play('/Users/me/Music/song.mp3');            // macOS / iOS
await audio.play('C:/Users/me/Music/song.wav');          // Windows
```

### Pause & Resume

```dart
await audio.pause();
await audio.resume();
```

### Stop

```dart
await audio.stop();
```

### Seeking

```dart
// Jump to 30 s. Works while playing and while paused.
await audio.seekTo(30 * 1000); // milliseconds
```

### Volume Control

Volume is a `double` between `0.0` (mute) and `1.0` (max).

```dart
await audio.setVolume(0.8);
```

### Get Duration & Position

Both return values in **milliseconds**.

```dart
final durationMs = await audio.getDuration();
final positionMs = await audio.getCurrentPosition();
```

---

## Recording

### Supported Formats

| Format | Android | iOS | macOS | Windows | Linux | Web |
|--------|---------|-----|-------|---------|-------|-----|
| AAC (`.m4a`) | ✅ | ✅ | ✅ | ⚠️ WAV only | ✅ | ✅ (webm/mp4) |
| WAV | ⚠️ OGG fallback | ✅ | ✅ | ✅ | ✅ | ✅ (wav) |

### Start Recording

```dart
import 'package:path_provider/path_provider.dart';

final dir = await getTemporaryDirectory();
final path = '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

await audio.startRecorder(
  path,
  format: AudioFormat.aac,   // AudioFormat.aac or AudioFormat.wav
  maxDuration: 30000,         // optional: max duration in milliseconds
);
```

### Stop Recording

`stopRecorder()` finalizes the file and returns the platform-reported path —
the real file path on native platforms, a `blob:` URL on Web (`null` when the
platform has nothing to report):

```dart
final String? savedPath = await audio.stopRecorder();
```

### Live Microphone Level

While the recorder is active, poll a normalized loudness value (`0.0`–`1.0`,
`-1.0` when unavailable):

```dart
final double level = await audio.getRecorderAmplitude();
```

---

## Conversation Mode (Voice Activity Detection)

ChatGPT-voice-style hands-free capture: the user taps **one** button, the
microphone stays open, and the plugin automatically:

1. **starts a recording the moment the user begins speaking** (level ≥ `speechStartLevel`);
2. **finalizes the segment when they fall silent** (level < `speechEndLevel` sustained for `silenceTimeout`);
3. emits each finished utterance as its own file (`ConversationSegment`) — feed it to your STT/AI pipeline and play the answer with `play()`;
4. keeps listening for the next utterance (continuous mode) or stops after one (single-shot mode).

All of the voice-activity logic runs on the normalized mic level
(`getRecorderAmplitude`), which is implemented on **every supported platform**.
No extra audio buffers are moved by the Dart layer.

### One-tap voice chat

```dart
final audio = AudioBetters();

// Listen for finished utterances (send each to your AI backend).
audio.conversationEvents.listen((event) {
  if (event.type == ConversationEventType.segmentCompleted) {
    final segment = event.segment!;
    print('Utterance #${segment.index} → ${segment.path} '
        '(${segment.duration.inMilliseconds} ms, ended by ${segment.reason.name})');
    // upload / transcribe / ask AI …
  }
});

// Drive a live mic meter (0.0–1.0) without touching raw audio.
audio.conversationLevels.listen((level) => setState(() => _level = level));

// USER TAPS THE MIC BUTTON ONCE:
await audio.startConversation(directory: '/path/to/tmp');   // always-on by default
// … USER TAPS AGAIN TO END THE SESSION:
await audio.stopConversation();
```

> On Web there is no file system, so pass any string (it is ignored) — every
> segment's `path` is a `blob:` URL you can `fetch()` or `play()`.

### Tuning parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `mode` | `ConversationMode.continuous` | `continuous` = always-on listening; `single` = smart one-shot (records one utterance and ends the session) |
| `speechStartLevel` | `0.15` | Normalized level that opens a new segment |
| `speechEndLevel` | `0.08` | Hysteresis floor that holds a segment open |
| `silenceTimeout` | `1200 ms` | Sustained quiet that finalizes a segment |
| `maxUtterance` | `60 s` | Hard cap that force-finalizes a long segment |
| `pollInterval` | `60 ms` | How often the mic level is sampled |
| `format` | `AudioFormat.aac` | Segment encoding (Web picks the best supported codec automatically) |
| `fileNameBuilder` | `conversation_<ts>_seg<i>.<ext>` | Custom segment naming |

### Events

| Event type | When |
|------------|------|
| `listening` | Session running, mic open, waiting for speech |
| `speechStarted` | Voice detected — a segment is now recording |
| `segmentCompleted` | An utterance was finalized (`event.segment` carries path/duration/reason) |
| `noSignal` | Platform is not delivering mic levels — segmentation degrades gracefully; segments end via `stopConversation()` |
| `error` | Platform failure ended the session (`event.message`) |
| `stopped` | Session fully stopped |

> Requires microphone permission to be granted **before** calling
> `startConversation` (e.g. with `permission_handler`; on Web the browser
> prompts on its own).

---

## Full Example: Player with Progress Bar

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_betters/audio_betters.dart';

class AudioPlayerWidget extends StatefulWidget {
  final String url;
  const AudioPlayerWidget({super.key, required this.url});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final _audio = AudioBetters();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _timer;

  Future<void> _play() async {
    await _audio.play(widget.url);
    final ms = await _audio.getDuration();
    setState(() {
      _isPlaying = true;
      _duration = Duration(milliseconds: ms);
    });
    _timer = Timer.periodic(const Duration(milliseconds: 300), (_) async {
      final pos = await _audio.getCurrentPosition();
      setState(() => _position = Duration(milliseconds: pos));
    });
  }

  Future<void> _pause() async {
    await _audio.pause();
    _timer?.cancel();
    setState(() => _isPlaying = false);
  }

  Future<void> _stop() async {
    await _audio.stop();
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
      _position = Duration.zero;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audio.stop();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
      '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Slider(
          value: _position.inMilliseconds.toDouble(),
          max: _duration.inMilliseconds > 0
              ? _duration.inMilliseconds.toDouble()
              : 1.0,
          onChanged: (v) => setState(() => _position = Duration(milliseconds: v.toInt())),
          onChangeEnd: (v) => _audio.seekTo(v.toInt()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(_position)),
            Text(_fmt(_duration)),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: _isPlaying ? _pause : _play,
            ),
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stop,
            ),
          ],
        ),
      ],
    );
  }
}
```

---

## Full Example: Voice Conversation Widget (ChatGPT-style)

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audio_betters/audio_betters.dart';

class VoiceChatWidget extends StatefulWidget {
  const VoiceChatWidget({super.key, required this.temporaryDirectory});
  final String temporaryDirectory;

  @override
  State<VoiceChatWidget> createState() => _VoiceChatWidgetState();
}

class _VoiceChatWidgetState extends State<VoiceChatWidget> {
  final _audio = AudioBetters();
  bool _active = false;
  bool _inSpeech = false;
  double _level = 0.0;

  @override
  void initState() {
    super.initState();
    _audio.conversationEvents.listen((event) {
      if (!mounted) return;
      setState(() {
        switch (event.type) {
          case ConversationEventType.speechStarted:
            _inSpeech = true;
          case ConversationEventType.segmentCompleted:
            _inSpeech = false;
            // TODO: send event.segment!.path to your AI backend.
          case ConversationEventType.stopped:
            _active = false;
            _inSpeech = false;
          default:
            break;
        }
      });
    });
    _audio.conversationLevels.listen((l) {
      if (mounted) setState(() => _level = l);
    });
  }

  Future<void> _toggle() async {
    if (_active) {
      await _audio.stopConversation();
    } else {
      await _audio.startConversation(
        directory: kIsWeb ? '' : widget.temporaryDirectory,
      );
      setState(() => _active = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.large(
      backgroundColor: _active ? (_inSpeech ? Colors.red : Colors.teal) : Colors.grey,
      onPressed: _toggle,
      tooltip: _active ? 'Listening ${(_level * 100).round()}%' : 'Start voice chat',
      child: Icon(_active ? Icons.mic : Icons.mic_none, color: Colors.white),
    );
  }
}
```

---

## API Reference

### `AudioBetters`

| Method | Description | Returns |
|--------|-------------|---------|
| `play(String urlOrPath)` | Play audio from URL or local path. Resolves when playback starts; a newer `play()`/`stop()` supersedes a pending one gracefully (no error). | `Future<void>` |
| `pause()` | Pause current playback | `Future<void>` |
| `resume()` | Resume paused playback | `Future<void>` |
| `stop()` | Stop and release resources | `Future<void>` |
| `seekTo(int milliseconds)` | Jump to a position (playing or paused) | `Future<void>` |
| `setVolume(double volume)` | Set volume `0.0` – `1.0` | `Future<void>` |
| `getDuration()` | Get total duration in ms | `Future<int>` |
| `getCurrentPosition()` | Get current position in ms | `Future<int>` |
| `startRecorder(String path, {AudioFormat format, int? maxDuration})` | Start recording to file | `Future<void>` |
| `stopRecorder()` | Stop recording, finalize file | `Future<String?>` (path / blob URL) |
| `getRecorderAmplitude()` | Normalized mic loudness while recording | `Future<double>` |
| `startConversation({required String directory, …})` | Start hands-free voice-activated capture | `Future<void>` |
| `stopConversation()` | End the session, finalizing any live utterance | `Future<void>` |
| `conversationEvents` | Stream of session lifecycle events | `Stream<ConversationEvent>` |
| `conversationLevels` | Stream of mic levels during a session | `Stream<double>` |
| `isConversationActive` | Whether a session is running | `bool` |

### `AudioFormat`

```dart
enum AudioFormat {
  aac,  // .m4a — default, best compatibility
  wav,  // .wav — lossless, larger file size
}
```

### `ConversationMode`

```dart
enum ConversationMode {
  continuous, // always-on: keeps listening after every utterance
  single,     // smart one-shot: one utterance, then the session ends
}
```

---

## Example App

The `example/` app runs on all six platforms and includes a **Voice Conversation
Mode** page demonstrating the one-tap ChatGPT-style loop, live meter, segment
list, and playback — plus per-platform player/recorder samples.

---

## Known Limitations

| Platform | Limitation |
|----------|------------|
| Android | `AudioFormat.wav` is not natively supported by `MediaRecorder`; falls back to OGG/OPUS format |
| Windows | Recording always produces WAV via MCI; `AudioFormat.aac` is ignored |
| Windows | File paths with non-ASCII (Unicode) characters may not work correctly |
| Windows | MCI waveaudio cannot seek while paused (the plugin parks at the position and continues on resume) |
| Linux | Requires GStreamer plugins to be installed on the target system |
| Web | Recorded audio is kept in memory as a `Blob`; saving to a real file path is not supported — `stopRecorder()`/segments return `blob:` URLs |
| All | Conversation Mode detects *voice activity*, not words — transcription/STT happens on your AI backend |

---

## Dependencies

| Package | Purpose |
|---------|---------|
| `plugin_platform_interface` | Platform interface pattern |
| `flutter_web_plugins` | Web plugin registration |
| `web` | Web APIs (`HTMLAudioElement`, `MediaRecorder`, Web Audio) |

---

## License

MIT License. See [LICENSE](LICENSE) for details.
