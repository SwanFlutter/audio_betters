/// Audio encoding requested for microphone recordings
/// ([AudioBetters.startRecorder], [AudioBetters.startConversation]).
///
/// Each value maps to the best encoder the platform actually offers; the
/// finalized file keeps a platform-correct extension
/// (`m4a`/`wav`/`webm`):
///
/// * [AudioFormat.wav] is universally supported everywhere.
/// * [AudioFormat.aac] writes M4A/ACC on Android, iOS, macOS, and Linux;
///   Windows always writes WAV regardless of this value; Web records in
///   `webm`/Opus and only falls back to WAV when Opus is unavailable.
///
/// ```dart
/// await audio.startRecorder(path, format: AudioFormat.wav);
/// await audio.startConversation(directory: dir, format: AudioFormat.aac);
/// ```
enum AudioFormat {
  /// AAC in an MP4 container (typically `.m4a`; `webm`/Opus on Web,
  /// `.wav` on Windows). Smaller files — the default for voice capture.
  aac,

  /// Uncompressed PCM WAV (`.wav`). Largest files, guaranteed support on
  /// every platform, ideal when the consumer expects raw PCM.
  wav,
}
