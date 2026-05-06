// ignore: avoid_web_libraries_in_flutter
import 'dart:js_interop';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'audio_betters_platform_interface.dart';

/// A web implementation of the AudioBettersPlatform of the AudioBetters plugin.
class AudioBettersWeb extends AudioBettersPlatform {
  web.HTMLAudioElement? _audioElement;

  /// Constructs a AudioBettersWeb
  AudioBettersWeb();

  static void registerWith(Registrar registrar) {
    AudioBettersPlatform.instance = AudioBettersWeb();
  }

  /// Returns a [String] containing the version of the platform.
  @override
  Future<String?> getPlatformVersion() async {
    return web.window.navigator.userAgent;
  }

  @override
  Future<void> play(String url) async {
    // Stop any existing playback
    _audioElement?.pause();

    // Create or reuse audio element
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
}