import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_betters/audio_betters.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AudioRecorderSample extends StatefulWidget {
  const AudioRecorderSample({super.key});

  @override
  State<AudioRecorderSample> createState() => _AudioRecorderSampleState();
}

class _AudioRecorderSampleState extends State<AudioRecorderSample> {
  final _audioPlugin = AudioBetters();
  bool _isRecording = false;
  String? _recordedPath;
  bool _isPlaying = false;

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("اجازه دسترسی به میکروفون داده نشده است")),
        );
      }
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      String extension = Platform.isWindows || Platform.isLinux ? "wav" : "m4a";
      final path = "${tempDir.path}/test_record.$extension";
      
      await _audioPlugin.startRecorder(path);
      setState(() {
        _isRecording = true;
        _recordedPath = path;
      });
    } catch (e) {
      debugPrint("Error starting recorder: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioPlugin.stopRecorder();
      setState(() {
        _isRecording = false;
      });
    } catch (e) {
      debugPrint("Error stopping recorder: $e");
    }
  }

  Future<void> _playRecording() async {
    if (_recordedPath == null) return;
    
    try {
      // For some platforms, local paths might need 'file://' prefix or special handling
      String playPath = _recordedPath!;
      if (!playPath.startsWith('http') && !Platform.isWindows) {
         // Some platforms might prefer file:// prefix
         // playPath = "file://$playPath";
      }
      
      await _audioPlugin.play(playPath);
      setState(() => _isPlaying = true);
    } catch (e) {
      debugPrint("Error playing recording: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ضبط و پخش صدا"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isRecording ? Icons.mic : Icons.mic_none,
                size: 100,
                color: _isRecording ? Colors.red : Colors.grey,
              ),
              const SizedBox(height: 20),
              if (_isRecording)
                const Text("در حال ضبط صدا...", style: TextStyle(fontSize: 18, color: Colors.red)),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isRecording ? _stopRecording : _startRecording,
                    icon: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
                    label: Text(_isRecording ? "توقف ضبط" : "شروع ضبط"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.black : Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              if (_recordedPath != null && !_isRecording) ...[
                const Divider(),
                const SizedBox(height: 20),
                const Text("آخرین فایل ضبط شده:"),
                Text(_recordedPath!, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _playRecording,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("پخش صدای ضبط شده"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => _audioPlugin.stop(),
                  child: const Text("توقف پخش"),
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}
