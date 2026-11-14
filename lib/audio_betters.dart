/// Cross-platform audio playback, recording, and voice-activated
/// conversation (ChatGPT-style hands-free capture) for six platforms:
/// Android, iOS, macOS, Windows, Linux, and Web — each backed by the
/// platform's native audio stack (MediaPlayer, AVAudioPlayer/Recorder,
/// MCI/waveIn, GStreamer, HTML5 Audio/MediaRecorder).
///
/// Start with [AudioBetters], the single entry-point facade:
///
/// ```dart
/// final audio = AudioBetters();
/// await audio.play('https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3');
/// await audio.pause();
/// await audio.resume();
/// await audio.stop();
/// ```
///
/// Recording writes to a file path you own; see [startRecorder] and
/// [stopRecorder]. For hands-free voice chat with automatic speech
/// segmentation, see [startConversation] and [conversationEvents].
library;

import 'audio_betters_platform_interface.dart';
import 'src/audio_format.dart';
import 'src/conversation.dart';
export 'src/audio_format.dart';
export 'src/conversation.dart';

/// The entry point of the plugin: one instance drives playback and
/// recording, and owns a hands-free conversation session.
///
/// Instances are cheap; create one per screen or a single app-wide one.
/// Playback state is global per platform engine, so the last call to
/// [play]/[pause]/[resume]/[stop] wins app-wide.
///
/// A full runnable sample lives in the package's `example/` app
/// (players, recorder, and a one-tap voice-conversation page).
class AudioBetters {
  /// Hands-free conversation state machine shared by this facade instance.
  final ConversationController _conversation = ConversationController();

  /// The platform version string, e.g. `Android 14`, `windows 10.0`.
  ///
  /// Useful for logging and for branching platform-specific workarounds.
  ///
  /// ```dart
  /// debugPrint(await AudioBetters().getPlatformVersion());
  /// ```
  Future<String?> getPlatformVersion() {
    return AudioBettersPlatform.instance.getPlatformVersion();
  }

  /// Starts playing [urlOrPath] — a local file path or a remote HTTP(S) URL.
  ///
  /// Resolves once playback has **started** (the media is prepared), not when
  /// it finishes; use [getDuration]/[getCurrentPosition] to track progress or
  /// [stop] to end early. Playing a new track supersedes the current one: any
  /// still-pending earlier [play] call resolves normally rather than failing.
  ///
  /// Throws [PlatformException] when the source cannot be opened.
  ///
  /// ```dart
  /// await audio.play('/sdcard/Music/song.mp3');
  /// // or: await audio.play('https://example.com/song.mp3');
  /// final totalMs = await audio.getDuration();
  /// ```
  ///
  /// See also [pause], [resume], [stop], and [seekTo].
  Future<void> play(String urlOrPath) {
    return AudioBettersPlatform.instance.play(urlOrPath);
  }

  /// Pauses the current playback, keeping the position.
  ///
  /// ```dart
  /// await audio.pause();
  /// ```
  Future<void> pause() {
    return AudioBettersPlatform.instance.pause();
  }

  /// Resumes playback after [pause] from the paused position.
  ///
  /// ```dart
  /// await audio.resume();
  /// ```
  Future<void> resume() {
    return AudioBettersPlatform.instance.resume();
  }

  /// Stops playback and releases the media source/decoder.
  ///
  /// ```dart
  /// await audio.stop();
  /// ```
  Future<void> stop() {
    return AudioBettersPlatform.instance.stop();
  }

  /// Moves the playhead to [milliseconds] from the start of the track.
  ///
  /// Works while playing **and** while paused; playback continues from the
  /// new position on [resume]. Clamped by the platform to the track bounds.
  ///
  /// ```dart
  /// await audio.seekTo(30000); // jump to 30 s
  /// ```
  Future<void> seekTo(int milliseconds) {
    return AudioBettersPlatform.instance.seekTo(milliseconds);
  }

  /// Sets playback volume, where [volume] is `0.0` (muted) to `1.0` (full).
  ///
  /// ```dart
  /// await audio.setVolume(0.7);
  /// ```
  ///
  /// Throws [ArgumentError] outside the `0.0–1.0` range.
  Future<void> setVolume(double volume) {
    return AudioBettersPlatform.instance.setVolume(volume);
  }

  /// Total duration of the loaded track in milliseconds, or `-1` when no
  /// track is loaded.
  ///
  /// ```dart
  /// final ms = await audio.getDuration(); // e.g. 193000
  /// ```
  Future<int> getDuration() {
    return AudioBettersPlatform.instance.getDuration();
  }

  /// Current playhead position of the loaded track in milliseconds.
  ///
  /// ```dart
  /// final ms = await audio.getCurrentPosition();
  /// final sliderValue = ms / await audio.getDuration();
  /// ```
  Future<int> getCurrentPosition() {
    return AudioBettersPlatform.instance.getCurrentPosition();
  }

  /// Starts recording the microphone into the file at [path].
  ///
  /// You own the path: pick a writable location (e.g. via
  /// `path_provider::getTemporaryDirectory()`). On Web the path is ignored —
  /// [stopRecorder] hands back a `blob:` URL instead.
  ///
  /// * [format] — desired encoding; see [AudioFormat] for what each platform
  ///   actually writes. Windows always records WAV.
  /// * [maxDuration] — optional hard limit in **seconds** after which the
  ///   platform finalizes the file by itself.
  ///
  /// Requires microphone permission to already be granted by the host app
  /// (e.g. with `permission_handler` on Android/iOS; browsers prompt
  /// automatically on Web).
  ///
  /// ```dart
  /// // dir comes from path_provider's getTemporaryDirectory()
  /// final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
  /// await audio.startRecorder(path, format: AudioFormat.aac, maxDuration: 300);
  /// ```
  ///
  /// See also [stopRecorder] and [getRecorderAmplitude].
  Future<void> startRecorder(
    String path, {
    AudioFormat format = AudioFormat.aac,
    int? maxDuration,
  }) {
    return AudioBettersPlatform.instance.startRecorder(
      path,
      format: format,
      maxDuration: maxDuration,
    );
  }

  /// Stops the active recording and finalizes the file.
  ///
  /// Returns the final path reported by the platform — the same file path on
  /// native platforms, a `blob:` URL on Web — or `null` when unavailable.
  /// Safe to call when no recording is running (returns `null`).
  ///
  /// ```dart
  /// await audio.startRecorder(path);
  /// // ... user finishes talking ...
  /// final saved = await audio.stopRecorder(); // file is ready to send
  /// await audio.play(saved!); // or upload it to your AI/STT backend
  /// ```
  Future<String?> stopRecorder() {
    return AudioBettersPlatform.instance.stopRecorder();
  }

  /// Normalized microphone loudness (`0.0`–`1.0`) while [startRecorder] is
  /// active, or `-1.0` when no recording is running or the platform cannot
  /// meter the microphone.
  ///
  /// Poll this (roughly every 60 ms) to draw a mic meter or to detect speech;
  /// inside a conversation session prefer the already-polled
  /// [conversationLevels] stream.
  ///
  /// ```dart
  /// final level = await audio.getRecorderAmplitude(); // -1 … 1
  /// ```
  Future<double> getRecorderAmplitude() {
    return AudioBettersPlatform.instance.getRecorderAmplitude();
  }

  // ---------------------------------------------------------------------------
  // Hands-free conversation mode (ChatGPT-style voice chat)
  // ---------------------------------------------------------------------------

  /// Broadcast stream of lifecycle events for the conversation session
  /// started with [startConversation].
  ///
  /// Subscribe **before** starting the session; the stream is broadcast, so
  /// multiple listeners are fine. Each
  /// [ConversationEventType.segmentCompleted] event carries a ready file at
  /// [ConversationEvent.segment] — feed it to your STT/AI pipeline.
  ///
  /// ```dart
  /// audio.conversationEvents.listen((e) {
  ///   switch (e.type) {
  ///     case ConversationEventType.speechStarted:
  ///       showRecordingIndicator();
  ///     case ConversationEventType.segmentCompleted:
  ///       sendToAI(e.segment!.path!);
  ///     case ConversationEventType.noSignal:
  ///     case ConversationEventType.error:
  ///       showError(e.message);
  ///     default:
  ///       break;
  ///   }
  /// });
  /// ```
  Stream<ConversationEvent> get conversationEvents => _conversation.events;

  /// Broadcast stream of microphone levels (`0.0`–`1.0`) sampled once per poll
  /// interval while a conversation session runs — drive a live mic meter with
  /// this without moving any audio.
  ///
  /// ```dart
  /// audio.conversationLevels.listen((level) => meter.value = level);
  /// ```
  Stream<double> get conversationLevels => _conversation.levels;

  /// Whether a conversation session is currently active on this instance.
  ///
  /// ```dart
  /// if (audio.isConversationActive) await audio.stopConversation();
  /// ```
  bool get isConversationActive => _conversation.isActive;

  /// Starts a hands-free, voice-activated recording session: one call (or one
  /// button tap in your UI) opens the microphone, and from then on every
  /// utterance the user speaks is captured automatically — recording starts
  /// when speech starts and the segment file is finalized when the user falls
  /// silent. This is the ChatGPT-voice-style "press once, talk freely" flow.
  ///
  /// The session is built on [startRecorder]/[stopRecorder] + microphone
  /// polling, so it works on every platform that can meter the mic
  /// (Android, iOS, macOS, Windows, Linux, Web).
  ///
  /// * [directory] — where segment files are written (ignored on Web, which
  ///   produces `blob:` URLs).
  /// * [mode] — [ConversationMode.continuous] keeps listening for the next
  ///   utterance after each one ("always on"); [ConversationMode.single]
  ///   records one utterance and stops by itself.
  /// * [format] — desired encoding per [AudioFormat] (platform caveats apply).
  /// * [speechStartLevel] / [speechEndLevel] — normalized `0.0–1.0` thresholds
  ///   to open and hold a segment (hysteresis). Raise both on noisy mics,
  ///   lower them for quiet speakers.
  /// * [silenceTimeout] — sustained quiet that closes a segment.
  /// * [maxUtterance] — hard cap that force-finalizes a long segment.
  /// * [pollInterval] — microphone level sampling period.
  /// * [fileNameBuilder] — customize segment file naming; defaults to
  ///   `conversation_<timestamp>_seg<index>.<ext>` with a platform-correct
  ///   extension.
  ///
  /// Requires microphone permission to already be granted by the host app.
  /// Throws [StateError] when a session is already active, and
  /// [ArgumentError] on invalid thresholds or timeouts.
  ///
  /// ```dart
  /// final dir = (await getTemporaryDirectory()).path;
  /// audio.conversationEvents.listen((e) {
  ///   if (e.type == ConversationEventType.segmentCompleted) {
  ///     uploadToMyAi(e.segment!.path!);
  ///   }
  /// });
  /// await audio.startConversation(directory: dir); // one tap → hands-free
  /// // ... later, to close the mic:
  /// await audio.stopConversation();
  /// ```
  ///
  /// See also [conversationEvents], [conversationLevels], [stopConversation].
  Future<void> startConversation({
    required String directory,
    ConversationMode mode = ConversationMode.continuous,
    AudioFormat format = AudioFormat.aac,
    double speechStartLevel = 0.15,
    double speechEndLevel = 0.08,
    Duration silenceTimeout = const Duration(milliseconds: 1200),
    Duration maxUtterance = const Duration(seconds: 60),
    Duration pollInterval = const Duration(milliseconds: 60),
    String Function(int segmentIndex)? fileNameBuilder,
  }) {
    return _conversation.start(
      directory: directory,
      mode: mode,
      format: format,
      speechStartLevel: speechStartLevel,
      speechEndLevel: speechEndLevel,
      silenceTimeout: silenceTimeout,
      maxUtterance: maxUtterance,
      pollInterval: pollInterval,
      fileNameBuilder: fileNameBuilder,
    );
  }

  /// Stops the conversation session, finalizing any in-flight utterance as a
  /// segment with [SegmentEndReason.manual] first, then emitting
  /// [ConversationEventType.stopped].
  ///
  /// ```dart
  /// await audio.stopConversation(); // mic closed, last segment delivered
  /// ```
  Future<void> stopConversation() => _conversation.stop();
}
