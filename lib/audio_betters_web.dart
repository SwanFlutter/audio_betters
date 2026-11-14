// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'audio_betters_platform_interface.dart';
import 'src/audio_format.dart';

/// A web implementation of the AudioBettersPlatform of the AudioBetters plugin.
class AudioBettersWeb extends AudioBettersPlatform {
  web.HTMLAudioElement? _audioElement;
  web.MediaRecorder? _mediaRecorder;
  web.MediaStream? _mediaStream;
  List<web.Blob> _chunks = [];

  // Microphone metering (voice-activity level) for the active recording.
  web.AudioContext? _audioContext;
  web.AnalyserNode? _analyser;
  web.MediaStreamAudioSourceNode? _source;
  Uint8List? _analyserData;
  String _recorderMime = 'audio/webm';

  /// Constructs a AudioBettersWeb
  AudioBettersWeb();

  static void registerWith(Registrar registrar) {
    AudioBettersPlatform.instance = AudioBettersWeb();
  }

  @override
  Future<String?> getPlatformVersion() async {
    return web.window.navigator.userAgent;
  }

  @override
  Future<void> play(String url) async {
    _audioElement?.pause();
    _audioElement ??=
        web.document.createElement('audio') as web.HTMLAudioElement;
    _audioElement!.src = url;
    await _audioElement!.play().toDart;
  }

  @override
  Future<void> pause() async {
    _audioElement?.pause();
  }

  @override
  Future<void> resume() async {
    await _audioElement?.play().toDart;
  }

  @override
  Future<void> stop() async {
    _audioElement?.pause();
    _audioElement?.currentTime = 0;
  }

  @override
  Future<void> seekTo(int milliseconds) async {
    if (_audioElement != null) {
      _audioElement!.currentTime = milliseconds / 1000;
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    _audioElement?.volume = volume;
  }

  @override
  Future<int> getDuration() async {
    if (_audioElement == null) return 0;
    final duration = _audioElement!.duration;
    if (duration.isNaN || duration.isInfinite) return 0;
    return (duration * 1000).toInt();
  }

  @override
  Future<int> getCurrentPosition() async {
    if (_audioElement == null) return 0;
    return (_audioElement!.currentTime * 1000).toInt();
  }

  @override
  Future<void> startRecorder(
    String path, {
    AudioFormat format = AudioFormat.aac,
    int? maxDuration,
  }) async {
    try {
      _mediaStream = await web.window.navigator.mediaDevices
          .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
          .toDart;

      String mimeType = 'audio/webm';
      if (format == AudioFormat.aac &&
          web.MediaRecorder.isTypeSupported('audio/mp4')) {
        mimeType = 'audio/mp4';
      }
      _recorderMime = mimeType;

      _mediaRecorder = web.MediaRecorder(
        _mediaStream!,
        web.MediaRecorderOptions(mimeType: mimeType),
      );
      _chunks = [];

      _mediaRecorder!.ondataavailable = (web.BlobEvent e) {
        if (e.data.size > 0) {
          _chunks.add(e.data);
        }
      }.toJS;

      _mediaRecorder!.start();

      _startMetering(_mediaStream!);

      if (maxDuration != null && maxDuration > 0) {
        Future.delayed(Duration(milliseconds: maxDuration), () {
          if (_mediaRecorder?.state == 'recording') {
            stopRecorder();
          }
        });
      }
    } catch (e) {
      throw Exception("Web Recording Error: $e");
    }
  }

  /// Attaches a Web Audio analyser to the mic stream for level metering.
  /// Metering is best effort: failure leaves [getRecorderAmplitude] at -1.
  void _startMetering(web.MediaStream stream) {
    _stopMetering();
    try {
      final ctx = web.AudioContext();
      final source = ctx.createMediaStreamSource(stream);
      final analyser = ctx.createAnalyser()..fftSize = 2048;
      source.connect(analyser);
      _audioContext = ctx;
      _source = source;
      _analyser = analyser;
      _analyserData = Uint8List(analyser.fftSize);
      if (ctx.state == 'suspended') {
        unawaited(ctx.resume().toDart.then((_) {}).catchError((Object _) {}));
      }
    } catch (_) {
      // Metering unavailable; recording itself continues.
    }
  }

  void _stopMetering() {
    try {
      _source?.disconnect();
    } catch (_) {}
    final ctx = _audioContext;
    if (ctx != null) {
      unawaited(ctx.close().toDart.then((_) {}).catchError((Object _) {}));
    }
    _audioContext = null;
    _source = null;
    _analyser = null;
    _analyserData = null;
  }

  @override
  Future<double> getRecorderAmplitude() async {
    final analyser = _analyser;
    final data = _analyserData;
    if (analyser == null ||
        data == null ||
        _mediaRecorder?.state != 'recording') {
      return -1.0;
    }
    analyser.getByteTimeDomainData(data.toJS);
    double sumSquares = 0;
    for (final byte in data) {
      final sample = (byte - 128) / 128.0;
      sumSquares += sample * sample;
    }
    final rms = math.sqrt(sumSquares / data.length);
    if (rms <= 0) return 0.0;
    final db = 20 * math.log(rms) / math.ln10; // dBFS
    // Map the −50 dBFS floor → 0.0 and full scale → 1.0.
    return ((db + 50) / 50).clamp(0.0, 1.0);
  }

  @override
  Future<String?> stopRecorder() async {
    if (_mediaRecorder == null || _mediaRecorder!.state == 'inactive') {
      return null;
    }

    _stopMetering();
    final completer = Completer<String?>();
    _mediaRecorder!.onstop = (web.Event e) {
      // In web, "saving to path" means creating a Blob URL: browsers cannot
      // write to a real file path. The caller can fetch() or play() it.
      String? url;
      try {
        if (_chunks.isNotEmpty) {
          final blob = web.Blob(
            _chunks.toJS,
            web.BlobPropertyBag(type: _recorderMime),
          );
          url = web.URL.createObjectURL(blob);
        }
      } catch (_) {
        url = null;
      }
      _mediaStream?.getTracks().toDart.forEach((track) => track.stop());
      completer.complete(url);
    }.toJS;

    _mediaRecorder!.stop();
    return completer.future;
  }
}
