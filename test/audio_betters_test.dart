import 'package:flutter_test/flutter_test.dart';
import 'package:audio_betters/audio_betters.dart';
import 'package:audio_betters/audio_betters_platform_interface.dart';
import 'package:audio_betters/audio_betters_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAudioBettersPlatform
    with MockPlatformInterfaceMixin
    implements AudioBettersPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<void> pause() {
    // TODO: implement pause
    throw UnimplementedError();
  }

  @override
  Future<void> play(String url) {
    // TODO: implement play
    throw UnimplementedError();
  }

  @override
  Future<void> resume() {
    // TODO: implement resume
    throw UnimplementedError();
  }

  @override
  Future<void> setVolume(double volume) {
    // TODO: implement setVolume
    throw UnimplementedError();
  }

  @override
  Future<void> stop() {
    // TODO: implement stop
    throw UnimplementedError();
  }
}

void main() {
  final AudioBettersPlatform initialPlatform = AudioBettersPlatform.instance;

  test('$MethodChannelAudioBetters is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAudioBetters>());
  });

  test('getPlatformVersion', () async {
    AudioBetters audioBettersPlugin = AudioBetters();
    MockAudioBettersPlatform fakePlatform = MockAudioBettersPlatform();
    AudioBettersPlatform.instance = fakePlatform;

    expect(await audioBettersPlugin.getPlatformVersion(), '42');
  });
}
