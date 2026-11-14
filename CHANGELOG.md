## 1.0.0

First public release. Playback, recording, and hands-free voice conversation
across Android, iOS, macOS, Windows, Linux, and Web. (Internal pre-releases
0.0.1–0.0.3 were never published.)

* Android: `play()` no longer throws `PlatformException(PLAY_INTERRUPTED)` when
  a new `play()` or `stop()` supersedes playback that is still preparing — the
  superseded call now resolves normally, matching all other platforms. Also
  fixes a latent hang where a pending `play()` never completed if `stop()`
  arrived while the media was still preparing.
* Android: migrated to **Built-in Kotlin** — the plugin no longer applies the
  Kotlin Gradle Plugin (`kotlin-android`); `jvmTarget` is set through the
  `kotlin { compilerOptions { … } }` DSL. This is required by AGP 9 and future
  Flutter versions. Raises the minimum supported SDKs to Flutter 3.44/Dart 3.12
  per the migration guide.
* **Windows: fixed silent playback/recording.** The plugin's MCI calls passed
  wide strings through the `mciSendString` macro, which resolves to the ANSI
  `mciSendStringA` when `UNICODE` is not defined in the plugin target (the
  default for Flutter plugin DLLs) — every command was truncated at the first
  character and failed silently. All calls now use `mciSendStringW`
  explicitly, `play()` checks its MCI error codes (with an automatic retry
  without `type mpegvideo` on machines lacking that device), and failures
  surface as `MCI_OPEN_ERROR` / `MCI_PLAY_ERROR` instead of fake success.
* Example: upgraded `permission_handler` to ^13.0.2 and set `compileSdk = 37`
  (required by `permission_handler_android` 14.x).

* Add **Conversation Mode** — ChatGPT-voice-style hands-free capture:
  `startConversation()` / `stopConversation()`, `conversationEvents`,
  `conversationLevels`, and `isConversationActive`. One tap opens the mic;
  voice-activity detection (level hysteresis + silence timeout) automatically
  starts a recording when the user speaks and finalizes each utterance as its
  own segment file. `ConversationMode.continuous` keeps listening (always-on);
  `ConversationMode.single` records one smart utterance and ends.
* Add `getRecorderAmplitude()`: normalized mic loudness (0.0–1.0, −1 when
  unavailable) on every platform — Android `getMaxAmplitude`, Apple
  `averagePower`, Windows `waveIn` meter, Linux GStreamer `level` probe, Web
  Audio analyser.
* `stopRecorder()` now returns the final path (`blob:` URL on Web).
* Fix Apple metering: call `AVAudioRecorder.updateMeters()` before reading
  `averagePower`, without which voice activity never fired on iOS/macOS.
* Fix Windows build of the level-metering code: use the real winmm APIs
  (`waveInStart(hwi)`, `waveInUnprepareHeader`) and compare against the
  numeric success code; the previous names never compiled.
* Example app: silence the `<experimental/coroutine>` deprecation static
  assert (C2338) that `permission_handler_windows` hits on current MSVC by
  defining `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` in the
  example's `windows/CMakeLists.txt`.
* Example app is now Web-safe (conditional file helpers replace direct
  `dart:io`), includes a one-tap Voice Conversation page, and the demo players
  are wired to `seekTo`.


* Add `seekTo(milliseconds)`. Android: `MediaPlayer.seekTo`. Windows: MCI
  `play from` while playing, `stop` + `seek` otherwise (waveaudio cannot seek
  while paused). Web: `currentTime`.
* Windows `resume` now plays from the parked position when the device is
  stopped rather than paused, so resume after a paused-state seek works.


* Initial release: play / pause / resume / stop / setVolume, recorder,
  duration and position queries.
