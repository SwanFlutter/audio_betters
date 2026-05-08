// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js_interop';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'audio_betters_platform_interface.dart';

/// A web implementation of the AudioBettersPlatform of the AudioBetters plugin.
class AudioBettersWeb extends AudioBettersPlatform {
  web.HTMLAudioElement? _audioElement;
  web.MediaRecorder? _mediaRecorder;
  web.MediaStream? _mediaStream;
  List<web.Blob> _chunks = [];

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
    _audioElement ??= web.document.createElement('audio') as web.HTMLAudioElement;
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
  Future<void> startRecorder(String path, {AudioFormat format = AudioFormat.aac, int? maxDuration}) async {
    try {
      _mediaStream = await web.window.navigator.mediaDevices.getUserMedia(web.MediaStreamConstraints(audio: true.toJS)).toDart;
      
      String mimeType = 'audio/webm';
      if (format == AudioFormat.aac && web.MediaRecorder.isTypeSupported('audio/mp4')) {
        mimeType = 'audio/mp4';
      }

      _mediaRecorder = web.MediaRecorder(_mediaStream!, web.MediaRecorderOptions(mimeType: mimeType));
      _chunks = [];

      _mediaRecorder!.ondataavailable = (web.BlobEvent e) {
        if (e.data.size > 0) {
          _chunks.add(e.data);
        }
      }.toJS;

      _mediaRecorder!.start();

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

  @override
  Future<void> stopRecorder() async {
    if (_mediaRecorder == null || _mediaRecorder!.state == 'inactive') return;

    final completer = Completer<void>();
    _mediaRecorder!.onstop = (web.Event e) {
      // In web, "saving to path" usually means creating a Blob URL.
      // Since the API expects us to have saved it, we just keep the chunks.
      // A more complete implementation might use IndexedDB to simulate a file system if needed.
      _mediaStream?.getTracks().toDart.forEach((track) => track.stop());
      completer.complete();
    }.toJS;

    _mediaRecorder!.stop();
    return completer.future;
  }
}
