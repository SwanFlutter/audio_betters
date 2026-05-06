import 'package:flutter/material.dart';
import 'package:audio_betters/audio_betters.dart';

class WindowsAudioSample extends StatefulWidget {
  const WindowsAudioSample({super.key});

  @override
  State<WindowsAudioSample> createState() => _WindowsAudioSampleState();
}

class _WindowsAudioSampleState extends State<WindowsAudioSample> {
  final _audioPlugin = AudioBetters();
  final String _localFilePath = "C:/Windows/Media/chimes.wav"; // Example system sound

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Windows Audio (MCI)")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.window, size: 80, color: Colors.blue),
            const Text("Using Windows Media Control Interface (MCI)"),
            const SizedBox(height: 30),
            const Text("This implementation uses winmm.lib to communicate with Windows Multimedia system."),
            const SizedBox(height: 20),
            ListTile(
              title: const Text("Play System Chime"),
              subtitle: Text(_localFilePath),
              trailing: IconButton(
                icon: const Icon(Icons.play_circle),
                onPressed: () => _audioPlugin.play(_localFilePath),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: () => _audioPlugin.pause(), child: const Text("Pause")),
                ElevatedButton(onPressed: () => _audioPlugin.resume(), child: const Text("Resume")),
              ],
            )
          ],
        ),
      ),
    );
  }
}
