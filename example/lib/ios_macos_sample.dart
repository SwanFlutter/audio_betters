import 'package:flutter/material.dart';
import 'package:audio_betters/audio_betters.dart';

class IosMacosAudioSample extends StatefulWidget {
  const IosMacosAudioSample({super.key});

  @override
  State<IosMacosAudioSample> createState() => _IosMacosAudioSampleState();
}

class _IosMacosAudioSampleState extends State<IosMacosAudioSample> {
  final _audioPlugin = AudioBetters();
  final String _url = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3";
  double _volume = 0.8;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("iOS & macOS Audio")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.apple, size: 100),
            const Text("Powered by AVFoundation (AVPlayer)"),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _audioPlugin.play(_url),
              icon: const Icon(Icons.play_arrow),
              label: const Text("Start Native Player"),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(onPressed: () => _audioPlugin.pause(), icon: const Icon(Icons.pause)),
                IconButton(onPressed: () => _audioPlugin.resume(), icon: const Icon(Icons.play_circle)),
                IconButton(onPressed: () => _audioPlugin.stop(), icon: const Icon(Icons.stop)),
              ],
            ),
            const SizedBox(height: 20),
            const Text("Volume Control"),
            Slider(
              value: _volume,
              onChanged: (v) {
                setState(() => _volume = v);
                _audioPlugin.setVolume(v);
              },
            )
          ],
        ),
      ),
    );
  }
}
