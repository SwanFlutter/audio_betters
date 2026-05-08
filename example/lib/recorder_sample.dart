import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_betters/audio_betters.dart';
import 'package:audio_betters/audio_betters_platform_interface.dart';
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
  
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Timer? _playbackTimer;
  
  AudioFormat _selectedFormat = AudioFormat.aac;
  int _maxDurationSeconds = 10;
  int _elapsedSeconds = 0;
  Timer? _timer;

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
      String extension = _selectedFormat == AudioFormat.wav ? "wav" : "m4a";
      final path = "${tempDir.path}/test_record_${DateTime.now().millisecondsSinceEpoch}.$extension";
      
      await _audioPlugin.startRecorder(
        path, 
        format: _selectedFormat,
        maxDuration: _maxDurationSeconds * 1000,
      );
      
      setState(() {
        _isRecording = true;
        _recordedPath = path;
        _elapsedSeconds = 0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _elapsedSeconds++;
        });
        if (_elapsedSeconds >= _maxDurationSeconds) {
          _stopRecording();
        }
      });
    } catch (e) {
      debugPrint("Error starting recorder: $e");
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
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
    debugPrint("DEBUG: _playRecording called. Path: $_recordedPath");
    if (_recordedPath == null) {
      debugPrint("DEBUG: Recorded path is null");
      return;
    }
    if (_isRecording) {
      debugPrint("DEBUG: Currently recording, cannot play");
      return;
    }
    
    try {
      debugPrint("DEBUG: Stopping any current playback...");
      await _audioPlugin.stop();
      
      final file = File(_recordedPath!);
      bool exists = await file.exists();
      debugPrint("DEBUG: Checking file existence: $exists");
      
      if (!exists) {
        debugPrint("DEBUG: File DOES NOT exist at path: $_recordedPath");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("فایل ضبط شده یافت نشد!")),
          );
        }
        return;
      }
      
      int length = await file.length();
      debugPrint("DEBUG: File size: $length bytes");
      if (length == 0) {
        debugPrint("DEBUG: File is empty (0 bytes)!");
      }

      debugPrint("DEBUG: Calling _audioPlugin.play with path: $_recordedPath");
      await _audioPlugin.play(_recordedPath!);
      debugPrint("DEBUG: _audioPlugin.play call finished successfully");
      
      // Get duration and start progress timer
      final durMs = await _audioPlugin.getDuration();
      setState(() {
        _isPlaying = true;
        _duration = Duration(milliseconds: durMs);
        _position = Duration.zero;
      });
      
      _startPlaybackTimer();
      
    } catch (e, stack) {
      debugPrint("DEBUG: ERROR during playing: $e");
      debugPrint("DEBUG: StackTrace: $stack");
    }
  }

  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (!_isPlaying) {
        timer.cancel();
        return;
      }
      
      final posMs = await _audioPlugin.getCurrentPosition();
      setState(() {
        _position = Duration(milliseconds: posMs);
      });
      
      // If reached end
      if (_duration.inMilliseconds > 0 && _position.inMilliseconds >= _duration.inMilliseconds - 100) {
        _stopPlayback();
      }
    });
  }

  Future<void> _stopPlayback() async {
    await _audioPlugin.stop();
    _playbackTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _position = Duration.zero;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _playbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ضبط پیشرفته صدا"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Recording Icon & Timer
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording ? Colors.red.withOpacity(0.1) : Colors.grey[200],
                    ),
                  ),
                  Icon(
                    _isRecording ? Icons.mic : Icons.mic_none,
                    size: 80,
                    color: _isRecording ? Colors.red : Colors.grey,
                  ),
                  if (_isRecording)
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: CircularProgressIndicator(
                        value: _elapsedSeconds / _maxDurationSeconds,
                        strokeWidth: 8,
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _isRecording ? "00:${_elapsedSeconds.toString().padLeft(2, '0')}" : "آماده ضبط",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              
              // Settings Card
              if (!_isRecording)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text("تنظیمات ضبط", style: TextStyle(fontWeight: FontWeight.bold)),
                        const Divider(),
                        DropdownButtonListTile(
                          title: "فرمت فایل:",
                          value: _selectedFormat,
                          items: AudioFormat.values,
                          onChanged: (val) => setState(() => _selectedFormat = val!),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text("حداکثر زمان (ثانیه):"),
                            Expanded(
                              child: Slider(
                                value: _maxDurationSeconds.toDouble(),
                                min: 5,
                                max: 60,
                                divisions: 11,
                                label: _maxDurationSeconds.toString(),
                                onChanged: (val) => setState(() => _maxDurationSeconds = val.toInt()),
                              ),
                            ),
                            Text("$_maxDurationSeconds"),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
              const SizedBox(height: 40),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isRecording ? _stopRecording : _startRecording,
                    icon: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
                    label: Text(_isRecording ? "توقف ضبط" : "شروع ضبط"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.black : Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(150, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              if (_recordedPath != null && !_isRecording) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text("فایل آماده پخش است", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text(
                        _recordedPath!.split('/').last,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      
                      // Progress Bar
                      if (_duration.inMilliseconds > 0)
                        Column(
                          children: [
                            Slider(
                              value: _position.inMilliseconds.toDouble(),
                              max: _duration.inMilliseconds.toDouble(),
                              onChanged: (value) {
                                // Seeking is not implemented yet in the plugin
                              },
                              activeColor: Colors.green,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_formatDuration(_position), style: const TextStyle(fontSize: 10)),
                                  Text(_formatDuration(_duration), style: const TextStyle(fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.filled(
                            onPressed: _isPlaying ? _stopPlayback : _playRecording,
                            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                            style: IconButton.styleFrom(
                              backgroundColor: _isPlaying ? Colors.blue : Colors.green
                            ),
                          ),
                          const SizedBox(width: 20),
                          IconButton.filled(
                            onPressed: _stopPlayback,
                            icon: const Icon(Icons.stop),
                            style: IconButton.styleFrom(backgroundColor: Colors.orange),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}

class DropdownButtonListTile<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const DropdownButtonListTile({
    super.key,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        DropdownButton<T>(
          value: value,
          items: items.map((e) => DropdownMenuItem(
            value: e,
            child: Text(e.toString().split('.').last.toUpperCase()),
          )).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
