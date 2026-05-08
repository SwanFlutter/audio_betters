import 'audio_betters_platform_interface.dart';
export 'audio_betters_platform_interface.dart' show AudioFormat;

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

  Future<void> startRecorder(String path, {AudioFormat format = AudioFormat.aac, int? maxDuration}) {
    return AudioBettersPlatform.instance.startRecorder(path, format: format, maxDuration: maxDuration);
  }

  Future<void> stopRecorder() {
    return AudioBettersPlatform.instance.stopRecorder();
  }

  Future<int> getDuration() {
    return AudioBettersPlatform.instance.getDuration();
  }

  Future<int> getCurrentPosition() {
    return AudioBettersPlatform.instance.getCurrentPosition();
  }
}
