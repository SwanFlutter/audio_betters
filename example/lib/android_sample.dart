import 'package:flutter/material.dart';
import 'package:audio_betters/audio_betters.dart';

class AndroidAudioSample extends StatefulWidget {
  const AndroidAudioSample({super.key});

  @override
  State<AndroidAudioSample> createState() => _AndroidAudioSampleState();
}

class _AndroidAudioSampleState extends State<AndroidAudioSample> {
  final _audioPlugin = AudioBetters();
  final String _url = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3";
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Android Audio Implementation")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Card(
              child: ListTile(
                leading: Icon(Icons.android, color: Colors.green),
                title: Text("Android MediaPlayer"),
                subtitle: Text("Using Native AudioAttributes & MediaPlayer"),
              ),
            ),
            const SizedBox(height: 20),
            Text("Playing: $_url", style: const TextStyle(fontSize: 12)),
            const Spacer(),
            CircleAvatar(
              radius: 40,
              backgroundColor: _isPlaying ? Colors.green : Colors.grey,
              child: IconButton(
                iconSize: 40,
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                onPressed: () async {
                  if (_isPlaying) {
                    await _audioPlugin.pause();
                  } else {
                    await _audioPlugin.play(_url);
                  }
                  setState(() => _isPlaying = !_isPlaying);
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _audioPlugin.stop(),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text("Stop & Release Resources"),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
