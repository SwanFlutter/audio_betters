import 'audio_betters_platform_interface.dart';

class AudioBetters {
  Future<String?> getPlatformVersion() {
    return AudioBettersPlatform.instance.getPlatformVersion();
  }

  Future<void> play(String url) {
    return AudioBettersPlatform.instance.play(url);
  }

  Future<void> pause() {
    return AudioBettersPlatform.instance.pause();
  }

  Future<void> resume() {
    return AudioBettersPlatform.instance.resume();
  }

  Future<void> stop() {
    return AudioBettersPlatform.instance.stop();
  }

  Future<void> setVolume(double volume) {
    return AudioBettersPlatform.instance.setVolume(volume);
  }
}
