import 'package:flutter/material.dart';
import 'package:audio_betters/audio_betters.dart';

class WindowsAudioSample extends StatefulWidget {
  const WindowsAudioSample({super.key});

  @override
  State<WindowsAudioSample> createState() => _WindowsAudioSampleState();
}

class _WindowsAudioSampleState extends State<WindowsAudioSample> {
  final _audioPlugin = AudioBetters();
  final String _localFilePath = "C:/Windows/Media/notify.wav"; 
  double _volume = 0.5;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlugin.setVolume(_volume);
  }

  void _handlePlay() async {
    await _audioPlugin.play(_localFilePath);
    setState(() => _isPlaying = true);
  }

  void _handlePause() async {
    await _audioPlugin.pause();
    setState(() => _isPlaying = false);
  }

  void _handleResume() async {
    await _audioPlugin.resume();
    setState(() => _isPlaying = true);
  }

  void _handleStop() async {
    await _audioPlugin.stop();
    setState(() => _isPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Windows Audio (MCI)"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blue[800],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Icon(Icons.window, size: 100, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    "Windows Media Control",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    "MCI / winmm.lib Implementation",
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.music_note, color: Colors.blue[800]),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              "Current Sound Source:",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _localFilePath,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // Player Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildControlButton(
                            icon: Icons.stop,
                            color: Colors.red,
                            onPressed: _handleStop,
                            tooltip: "Stop",
                          ),
                          const SizedBox(width: 20),
                          _buildPlayPauseButton(),
                          const SizedBox(width: 20),
                          _buildControlButton(
                            icon: Icons.refresh,
                            color: Colors.blue,
                            onPressed: _handlePlay,
                            tooltip: "Restart",
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Volume Slider
                      Row(
                        children: [
                          Icon(Icons.volume_down, color: Colors.grey[600]),
                          Expanded(
                            child: Slider(
                              value: _volume,
                              activeColor: Colors.blue[800],
                              inactiveColor: Colors.blue[100],
                              onChanged: (value) {
                                setState(() => _volume = value);
                                _audioPlugin.setVolume(value);
                              },
                            ),
                          ),
                          Icon(Icons.volume_up, color: Colors.grey[600]),
                        ],
                      ),
                      Text("Volume: ${(_volume * 100).toInt()}%"),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "نکته: در ویندوز، MCI از اکثر فرمت‌های رایج مثل WAV و MP3 پشتیبانی می‌کند.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.blue[800],
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: IconButton(
        iconSize: 40,
        icon: Icon(
          _isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
        ),
        onPressed: _isPlaying ? _handlePause : _handleResume,
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: color.withOpacity(0.3)),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
      ),
    );
  }
}
