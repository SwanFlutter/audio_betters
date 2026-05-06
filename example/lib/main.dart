import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'android_sample.dart';
import 'ios_macos_sample.dart';
import 'windows_sample.dart';
import 'linux_sample.dart';
import 'web_sample.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AudioBettersHome(),
  ));
}

class AudioBettersHome extends StatelessWidget {
  const AudioBettersHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Betters Multi-Platform'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "انتخاب نمونه کد بر اساس پلتفرم:",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _buildPlatformTile(
            context,
            title: "Android Implementation",
            icon: Icons.android,
            color: Colors.green,
            page: const AndroidAudioSample(),
            isCurrent: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
          ),
          _buildPlatformTile(
            context,
            title: "iOS & macOS (Apple)",
            icon: Icons.apple,
            color: Colors.black87,
            page: const IosMacosAudioSample(),
            isCurrent: !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS),
          ),
          _buildPlatformTile(
            context,
            title: "Windows (MCI)",
            icon: Icons.window,
            color: Colors.blue,
            page: const WindowsAudioSample(),
            isCurrent: !kIsWeb && defaultTargetPlatform == TargetPlatform.windows,
          ),
          _buildPlatformTile(
            context,
            title: "Linux (GStreamer)",
            icon: Icons.terminal,
            color: Colors.orange,
            page: const LinuxAudioSample(),
            isCurrent: !kIsWeb && defaultTargetPlatform == TargetPlatform.linux,
          ),
          _buildPlatformTile(
            context,
            title: "Web (HTML5)",
            icon: Icons.language,
            color: Colors.deepOrange,
            page: const WebAudioSample(),
            isCurrent: kIsWeb,
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformTile(BuildContext context,
      {required String title,
      required IconData icon,
      required Color color,
      required Widget page,
      required bool isCurrent}) {
    return Card(
      elevation: isCurrent ? 8 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrent ? BorderSide(color: color, width: 2) : BorderSide.none,
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: isCurrent ? const Text("پلتفرم شناسایی شده") : const Text("نمونه کد مرجع"),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      ),
    );
  }
}
