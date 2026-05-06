import 'package:flutter/material.dart';
import 'package:audio_betters/audio_betters.dart';

class WebAudioSample extends StatefulWidget {
  const WebAudioSample({super.key});

  @override
  State<WebAudioSample> createState() => _WebAudioSampleState();
}

class _WebAudioSampleState extends State<WebAudioSample> {
  final _audioPlugin = AudioBetters();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Web Audio (HTML5)")),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const Icon(Icons.html, size: 100, color: Colors.orange),
            const Text("Using package:web and HTMLAudioElement"),
            const SizedBox(height: 20),
            const Text(
              "Note: Browsers might block auto-play. User interaction is required to start playback.",
              style: TextStyle(fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => _audioPlugin.play("https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3"),
              child: const Text("Play Sound via HTML5 Audio"),
            ),
          ],
        ),
      ),
    );
  }
}
