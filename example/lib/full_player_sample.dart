import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_betters/audio_betters.dart';
import 'package:path_provider/path_provider.dart';

class FullPlayerSample extends StatefulWidget {
  const FullPlayerSample({super.key});

  @override
  State<FullPlayerSample> createState() => _FullPlayerSampleState();
}

class _FullPlayerSampleState extends State<FullPlayerSample> {
  final _audioPlugin = AudioBetters();
  
  bool _isPlaying = false;
  bool _isPaused = false;
  
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0;
  
  Timer? _timer;
  String? _currentFilePath;
  String _status = "آماده پخش";

  @override
  void initState() {
    super.initState();
    _initAsset();
  }

  Future<void> _initAsset() async {
    try {
      final byteData = await rootBundle.load("assets/Are_you_worried_about_your_organization_or_company.mp3");
      final tempDir = await getTemporaryDirectory();
      final file = File("${tempDir.path}/test_asset.mp3");
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      setState(() {
        _currentFilePath = file.path;
      });
      debugPrint("Asset loaded to: ${file.path}");
    } catch (e) {
      setState(() => _status = "خطا در بارگذاری فایل");
    }
  }

  void _handlePlay() async {
    if (_currentFilePath == null) return;
    try {
      await _audioPlugin.play(_currentFilePath!);
      final durMs = await _audioPlugin.getDuration();
      
      setState(() {
        _isPlaying = true;
        _isPaused = false;
        _duration = Duration(milliseconds: durMs);
        _status = "در حال پخش";
      });
      
      _startTimer();
    } catch (e) {
      setState(() => _status = "خطا در پخش: $e");
    }
  }

  void _handlePause() async {
    await _audioPlugin.pause();
    setState(() {
      _isPaused = true;
      _isPlaying = false;
      _status = "متوقف شده (Pause)";
    });
  }

  void _handleResume() async {
    await _audioPlugin.resume();
    setState(() {
      _isPaused = false;
      _isPlaying = true;
      _status = "در حال پخش";
    });
  }

  void _handleStop() async {
    await _audioPlugin.stop();
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
      _isPaused = false;
      _position = Duration.zero;
      _status = "توقف کامل";
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!_isPlaying && !_isPaused) {
        timer.cancel();
        return;
      }
      
      final posMs = await _audioPlugin.getCurrentPosition();
      setState(() {
        _position = Duration(milliseconds: posMs);
      });

      // Auto stop when finished
      if (_duration.inMilliseconds > 0 && _position.inMilliseconds >= _duration.inMilliseconds - 200) {
        _handleStop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("تست کامل پخش‌کننده"), backgroundColor: Colors.indigo),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.music_video, size: 100, color: Colors.indigo),
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(_currentFilePath?.split('/').last ?? "در حال آماده‌سازی...", 
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
            
            const SizedBox(height: 40),
            
            // Progress Slider
            Slider(
              value: _position.inMilliseconds.toDouble().clamp(0, _duration.inMilliseconds.toDouble()),
              max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
              onChanged: (v) {}, // Seek not implemented
              activeColor: Colors.indigo,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position)),
                Text(_formatDuration(_duration)),
              ],
            ),
            
            const SizedBox(height: 30),
            
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.stop,
                  onPressed: _handleStop,
                  color: Colors.red,
                ),
                _buildActionButton(
                  icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                  onPressed: _isPlaying ? _handlePause : (_isPaused ? _handleResume : _handlePlay),
                  color: Colors.indigo,
                  size: 70,
                ),
                _buildActionButton(
                  icon: Icons.refresh,
                  onPressed: _handlePlay,
                  color: Colors.blue,
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            
            // Volume
            Row(
              children: [
                const Icon(Icons.volume_down),
                Expanded(
                  child: Slider(
                    value: _volume,
                    onChanged: (v) {
                      setState(() => _volume = v);
                      _audioPlugin.setVolume(v);
                    },
                  ),
                ),
                const Icon(Icons.volume_up),
              ],
            ),
            Text("Volume: ${(_volume * 100).toInt()}%"),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required VoidCallback onPressed, required Color color, double size = 50}) {
    return IconButton(
      icon: Icon(icon, size: size * 0.6),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        fixedSize: Size(size, size),
      ),
    );
  }

  String _formatDuration(Duration d) {
    return "${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }
}
