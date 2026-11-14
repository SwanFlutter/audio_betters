import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio_betters_platform_interface.dart';
import 'audio_format.dart';

/// How a hands-free (voice-activated) conversation session behaves after it
/// captures an utterance.
enum ConversationMode {
  /// Always-on, ChatGPT-voice-style: the session keeps listening after every
  /// utterance and writes each utterance to its own segment file. It runs
  /// until [AudioBetters.stopConversation] is called.
  continuous,

  /// Smart one-shot: records exactly one utterance — started automatically
  /// when the user begins speaking, finalized automatically when they stop —
  /// then the session ends by itself.
  single,
}

/// Type of a [ConversationEvent].
enum ConversationEventType {
  /// The session is running and the mic is open, waiting for speech.
  listening,

  /// Voice activity was detected and a new segment recording has started.
  /// [ConversationEvent.path] carries the file the segment is being written
  /// to (or the requested name on Web).
  speechStarted,

  /// An utterance finished and its file is finalized.
  /// [ConversationEvent.segment] carries the result.
  segmentCompleted,

  /// The platform did not deliver any microphone level for several seconds:
  /// voice-activated segmentation cannot work on this platform/build. The
  /// session stays alive — segments can still be ended with
  /// [AudioBetters.stopConversation], and long utterances are still capped by
  /// `maxUtterance` only once levels resume.
  noSignal,

  /// A platform error stopped the session. [ConversationEvent.message]
  /// carries the reason.
  error,

  /// The session was stopped.
  stopped,
}

/// Why a recorded segment ended.
enum SegmentEndReason {
  /// The speaker went silent for longer than the configured silence timeout.
  silence,

  /// The segment reached the configured `maxUtterance` duration.
  maxDuration,

  /// The session was stopped by [AudioBetters.stopConversation] while the
  /// user was mid-utterance.
  manual,
}

/// One recorded utterance produced by a conversation session.
class ConversationSegment {
  const ConversationSegment({
    required this.index,
    required this.path,
    required this.duration,
    required this.reason,
    required this.startedAt,
  });

  /// Zero-based index of this segment within the session.
  final int index;

  /// Finalized file path. On Web this is a `blob:` URL because browsers
  /// cannot write to a real file path; feed it straight to
  /// [AudioBetters.play] or fetch it. `null` when the platform failed to
  /// report a path.
  final String? path;

  /// Wall-clock duration of the utterance.
  final Duration duration;

  /// Why the segment ended.
  final SegmentEndReason reason;

  /// When the utterance started.
  final DateTime startedAt;

  @override
  String toString() =>
      'ConversationSegment(#$index, path: $path, duration: $duration, reason: ${reason.name})';
}

/// An event emitted by [AudioBetters.conversationEvents].
class ConversationEvent {
  const ConversationEvent(this.type, {this.segment, this.path, this.message});

  /// The kind of event; it decides which payload fields below are populated.
  final ConversationEventType type;

  /// The completed segment for [ConversationEventType.segmentCompleted].
  final ConversationSegment? segment;

  /// Target file for [ConversationEventType.speechStarted].
  final String? path;

  /// Human-readable detail for [ConversationEventType.error] and
  /// [ConversationEventType.noSignal].
  final String? message;

  @override
  String toString() =>
      'ConversationEvent(${type.name}, ${message ?? path ?? segment})';
}

/// Voice-activity state machine implementing hands-free conversation capture.
///
/// One instance per [AudioBetters]; normally used through the facade methods
/// [AudioBetters.startConversation], [AudioBetters.stopConversation],
/// [AudioBetters.conversationEvents] and [AudioBetters.conversationLevels].
///
/// The engine polls the platform's normalized microphone level
/// ([AudioBettersPlatform.getRecorderAmplitude]) every `pollInterval`:
///
/// * while idle, a level ≥ `speechStartLevel` opens a new segment file via
///   `startRecorder`;
/// * while a segment is open, a level < `speechEndLevel` sustained for
///   `silenceTimeout` (or reaching `maxUtterance`) finalizes it via
///   `stopRecorder` and emits `segmentCompleted`;
/// * in [ConversationMode.continuous] the session then listens again; in
///   [ConversationMode.single] it stops itself.
///
/// All recorder access is serialized, so events arrive in causal order.
class ConversationController {
  ConversationController({
    Future<void> Function(String path, AudioFormat format)? startRecorder,
    Future<String?> Function()? stopRecorder,
    Future<double> Function()? amplitude,
  }) : _start =
           startRecorder ??
           ((path, format) => AudioBettersPlatform.instance.startRecorder(
             path,
             format: format,
           )),
       _stop =
           stopRecorder ?? (() => AudioBettersPlatform.instance.stopRecorder()),
       _amplitude =
           amplitude ??
           (() => AudioBettersPlatform.instance.getRecorderAmplitude());

  /// Consecutive level polls that returned "no data" (-1) before a
  /// [ConversationEventType.noSignal] event is emitted once per session.
  static const int noSignalTickThreshold = 50;

  final Future<void> Function(String path, AudioFormat format) _start;
  final Future<String?> Function() _stop;
  final Future<double> Function() _amplitude;

  final StreamController<ConversationEvent> _events =
      StreamController<ConversationEvent>.broadcast();
  final StreamController<double> _levels = StreamController<double>.broadcast();

  Timer? _timer;
  bool _busy = false;
  bool _started = false;
  bool _inSpeech = false;
  bool _noSignalReported = false;
  int _noDataTicks = 0;
  int _segmentIndex = 0;
  Stopwatch? _speechWatch;
  DateTime? _segmentStartedAt;
  DateTime? _silenceSince;

  // Session configuration (captured by [start]).
  String _directory = '';
  ConversationMode _mode = ConversationMode.continuous;
  AudioFormat _format = AudioFormat.aac;
  double _speechStartLevel = 0.15;
  double _speechEndLevel = 0.08;
  Duration _silenceTimeout = const Duration(milliseconds: 1200);
  Duration _maxUtterance = const Duration(seconds: 60);
  Duration _pollInterval = const Duration(milliseconds: 60);
  String Function(int segmentIndex)? _fileNameBuilder;

  /// Broadcast stream of session lifecycle events.
  Stream<ConversationEvent> get events => _events.stream;

  /// Broadcast stream of normalized microphone levels (0.0–1.0) sampled once
  /// per poll interval while the session runs. Useful for a live microphone
  /// meter; contains no audio content.
  Stream<double> get levels => _levels.stream;

  /// Whether a session is currently running.
  bool get isActive => _started;

  /// Starts a hands-free session. Throws [StateError] when one is already
  /// running and [ArgumentError] on invalid thresholds/timeouts.
  Future<void> start({
    required String directory,
    ConversationMode mode = ConversationMode.continuous,
    AudioFormat format = AudioFormat.aac,
    double speechStartLevel = 0.15,
    double speechEndLevel = 0.08,
    Duration silenceTimeout = const Duration(milliseconds: 1200),
    Duration maxUtterance = const Duration(seconds: 60),
    Duration pollInterval = const Duration(milliseconds: 60),
    String Function(int segmentIndex)? fileNameBuilder,
  }) async {
    if (_started) {
      throw StateError(
        'A conversation session is already active. '
        'Call stopConversation() before starting a new one.',
      );
    }
    if (speechStartLevel <= 0.0 || speechStartLevel > 1.0) {
      throw ArgumentError.value(
        speechStartLevel,
        'speechStartLevel',
        'must be in (0.0, 1.0]',
      );
    }
    if (speechEndLevel < 0.0 || speechEndLevel > speechStartLevel) {
      throw ArgumentError.value(
        speechEndLevel,
        'speechEndLevel',
        'must be in [0.0, speechStartLevel] ($speechStartLevel)',
      );
    }
    if (silenceTimeout <= Duration.zero ||
        maxUtterance <= silenceTimeout ||
        pollInterval <= Duration.zero) {
      throw ArgumentError(
        'pollInterval and silenceTimeout must be > 0 and maxUtterance must '
        'exceed silenceTimeout.',
      );
    }

    _directory = directory;
    _mode = mode;
    _format = format;
    _speechStartLevel = speechStartLevel;
    _speechEndLevel = speechEndLevel;
    _silenceTimeout = silenceTimeout;
    _maxUtterance = maxUtterance;
    _pollInterval = pollInterval;
    _fileNameBuilder = fileNameBuilder;

    _inSpeech = false;
    _noSignalReported = false;
    _noDataTicks = 0;
    _segmentIndex = 0;
    _speechWatch = null;
    _segmentStartedAt = null;
    _silenceSince = null;
    _started = true;

    _events.add(const ConversationEvent(ConversationEventType.listening));
    _timer = Timer.periodic(_pollInterval, (_) => _tick());
  }

  /// Stops the session. A segment that is mid-utterance is finalized first
  /// ([SegmentEndReason.manual]) and reported through
  /// [ConversationEventType.segmentCompleted] before the
  /// [ConversationEventType.stopped] event.
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    if (!_started) return;
    // Wait for an in-flight poll tick so recorder access stays serialized.
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    _busy = true;
    try {
      if (_inSpeech) {
        await _endSegment(SegmentEndReason.manual);
      }
      if (_started) {
        _started = false;
        _events.add(const ConversationEvent(ConversationEventType.stopped));
      }
    } finally {
      _busy = false;
    }
  }

  /// Stops any session and releases the event streams. The controller is not
  /// usable afterwards.
  Future<void> dispose() async {
    await stop();
    await _events.close();
    await _levels.close();
  }

  Future<void> _tick() async {
    if (_busy || !_started) return;
    _busy = true;
    try {
      double level;
      try {
        level = await _amplitude();
      } catch (e) {
        await _fail('Microphone level query failed: $e');
        return;
      }
      if (!_started) return; // Stopped while the query was in flight.

      if (level < 0) {
        _noDataTicks++;
        if (!_noSignalReported && _noDataTicks >= noSignalTickThreshold) {
          _noSignalReported = true;
          _events.add(
            const ConversationEvent(
              ConversationEventType.noSignal,
              message:
                  'No microphone level data from this platform — '
                  'voice-activated segmentation is unavailable. Segments only '
                  'end via stopConversation().',
            ),
          );
        }
        return;
      }
      _noDataTicks = 0;
      _levels.add(level);

      if (!_inSpeech) {
        if (level >= _speechStartLevel) {
          await _beginSegment();
        }
        return;
      }

      final now = DateTime.now();
      if (level < _speechEndLevel) {
        _silenceSince ??= now;
        if (now.difference(_silenceSince!) >= _silenceTimeout) {
          await _endSegment(SegmentEndReason.silence);
          return;
        }
      } else {
        _silenceSince = null;
      }

      if (_inSpeech && _speechWatch!.elapsed >= _maxUtterance) {
        await _endSegment(SegmentEndReason.maxDuration);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _beginSegment() async {
    final name =
        _fileNameBuilder?.call(_segmentIndex) ??
        _defaultFileName(_segmentIndex);
    final fullPath = _join(_directory, name);
    _inSpeech = true;
    _silenceSince = null;
    _speechWatch = Stopwatch()..start();
    _segmentStartedAt = DateTime.now();
    try {
      await _start(fullPath, _format);
    } catch (e) {
      _inSpeech = false;
      _speechWatch = null;
      await _fail('Failed to start recording "$fullPath": $e');
      return;
    }
    if (!_started) return; // Session was stopped while the recorder started.
    _events.add(
      ConversationEvent(ConversationEventType.speechStarted, path: fullPath),
    );
  }

  Future<void> _endSegment(SegmentEndReason reason) async {
    if (!_inSpeech) return;
    _inSpeech = false;
    final index = _segmentIndex;
    final duration = _speechWatch?.elapsed ?? Duration.zero;
    final startedAt = _segmentStartedAt ?? DateTime.now();
    _speechWatch = null;
    _silenceSince = null;
    String? path;
    try {
      path = await _stop();
    } catch (e) {
      await _fail('Failed to finalize segment #$index: $e');
      return;
    }
    _segmentIndex++;
    _events.add(
      ConversationEvent(
        ConversationEventType.segmentCompleted,
        segment: ConversationSegment(
          index: index,
          path: path,
          duration: duration,
          reason: reason,
          startedAt: startedAt,
        ),
      ),
    );
    if (_mode == ConversationMode.single) {
      await stop();
    }
  }

  Future<void> _fail(String message) async {
    _timer?.cancel();
    _timer = null;
    _started = false;
    _inSpeech = false;
    _speechWatch = null;
    // Best effort: make sure the native recorder is not left running.
    try {
      await _stop();
    } catch (_) {}
    _events.add(
      ConversationEvent(ConversationEventType.error, message: message),
    );
    _events.add(const ConversationEvent(ConversationEventType.stopped));
  }

  String _defaultFileName(int index) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'conversation_${ts}_seg$index.${_defaultExtension()}';
  }

  String _defaultExtension() {
    if (kIsWeb) return 'webm';
    if (defaultTargetPlatform == TargetPlatform.windows) {
      // The Windows recorder (MCI) always writes WAV.
      return 'wav';
    }
    return _format == AudioFormat.wav ? 'wav' : 'm4a';
  }

  static String _join(String directory, String name) {
    if (directory.isEmpty) return name;
    final sep = directory.endsWith('/') || directory.endsWith(r'\') ? '' : '/';
    return '$directory$sep$name';
  }
}
