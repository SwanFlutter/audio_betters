import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'audio_betters_method_channel.dart';

enum AudioFormat {
  aac,
  wav,
}

abstract class AudioBettersPlatform extends PlatformInterface {
  /// Constructs a AudioBettersPlatform.
  AudioBettersPlatform() : super(token: _token);

  static final Object _token = Object();

  static AudioBettersPlatform _instance = MethodChannelAudioBetters();

  /// The default instance of [AudioBettersPlatform] to use.
  ///
  /// Defaults to [MethodChannelAudioBetters].
  static AudioBettersPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AudioBettersPlatform] when
  /// they register themselves.
  static set instance(AudioBettersPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<void> play(String url) {
    throw UnimplementedError('play() has not been implemented.');
  }

  Future<void> pause() {
    throw UnimplementedError('pause() has not been implemented.');
  }

  Future<void> resume() {
    throw UnimplementedError('resume() has not been implemented.');
  }

  Future<void> stop() {
    throw UnimplementedError('stop() has not been implemented.');
  }

  Future<void> setVolume(double volume) {
    throw UnimplementedError('setVolume() has not been implemented.');
  }

  Future<void> startRecorder(String path, {AudioFormat format = AudioFormat.aac, int? maxDuration}) {
    throw UnimplementedError('startRecorder() has not been implemented.');
  }

  Future<void> stopRecorder() {
    throw UnimplementedError('stopRecorder() has not been implemented.');
  }

  Future<int> getDuration() {
    throw UnimplementedError('getDuration() has not been implemented.');
  }

  Future<int> getCurrentPosition() {
    throw UnimplementedError('getCurrentPosition() has not been implemented.');
  }
}
