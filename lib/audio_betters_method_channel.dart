import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_betters_platform_interface.dart';

/// An implementation of [AudioBettersPlatform] that uses method channels.
class MethodChannelAudioBetters extends AudioBettersPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('audio_betters');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<void> play(String url) async {
    await methodChannel.invokeMethod('play', {'url': url});
  }

  @override
  Future<void> pause() async {
    await methodChannel.invokeMethod('pause');
  }

  @override
  Future<void> resume() async {
    await methodChannel.invokeMethod('resume');
  }

  @override
  Future<void> stop() async {
    await methodChannel.invokeMethod('stop');
  }

  @override
  Future<void> setVolume(double volume) async {
    await methodChannel.invokeMethod('setVolume', {'volume': volume});
  }
}
