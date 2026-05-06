import 'package:flutter/material.dart';
import 'package:audio_betters/audio_betters.dart';

class LinuxAudioSample extends StatelessWidget {
  const LinuxAudioSample({super.key});

  @override
  Widget build(BuildContext context) {
    final audioPlugin = AudioBetters();

    return Scaffold(
      appBar: AppBar(title: const Text("Linux Audio (GStreamer)")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.terminal, size: 100),
            const Text("Using GStreamer playbin"),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                "Requirement: sudo apt install libgstreamer1.0-dev gstreamer1.0-plugins-good",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            Wrap(
              spacing: 10,
              children: [
                ActionChip(
                  label: const Text("Play Sample"),
                  onPressed: () => audioPlugin.play("https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3"),
                ),
                ActionChip(
                  label: const Text("Stop"),
                  onPressed: () => audioPlugin.stop(),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
