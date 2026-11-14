import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audio_betters/audio_betters.dart';
import 'package:permission_handler/permission_handler.dart';

import 'io/paths.dart';

/// ChatGPT-voice-style demo: tap the mic button once and the plugin keeps the
/// microphone open; every utterance the user speaks is detected automatically
/// (voice-activity detection) and finalized into its own audio segment when
/// they fall silent. Each segment file (or blob: URL on Web) can be sent to an
/// AI backend — here we simply replay it.
class VoiceConversationSample extends StatefulWidget {
  const VoiceConversationSample({super.key});

  @override
  State<VoiceConversationSample> createState() =>
      _VoiceConversationSampleState();
}

class _VoiceConversationSampleState extends State<VoiceConversationSample> {
  final AudioBetters _audio = AudioBetters();

  ConversationMode _mode = ConversationMode.continuous;
  bool _active = false;
  bool _inSpeech = false;
  double _level = 0.0;
  String _status = 'آماده — دکمه میکروفون را بزنید';
  String? _warning;
  final List<ConversationSegment> _segments = [];
  String? _playingPath;
  StreamSubscription<ConversationEvent>? _eventSub;
  StreamSubscription<double>? _levelSub;

  @override
  void initState() {
    super.initState();
    _eventSub = _audio.conversationEvents.listen(_onEvent);
    _levelSub = _audio.conversationLevels.listen((level) {
      if (mounted) setState(() => _level = level);
    });
  }

  Future<void> _toggleConversation() async {
    if (_active) {
      await _audio.stopConversation();
      return;
    }
    // On Web the browser prompts for microphone access by itself.
    if (!kIsWeb) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        setState(() => _warning = 'دسترسی میکروفون داده نشد.');
        return;
      }
    }
    try {
      // Browsers cannot write files — Web ignores the directory and hands
      // back blob: URLs for every segment.
      final directory = canUseFileSystem ? await tempDirPath() : '';
      setState(() {
        _warning = null;
        _segments.clear();
        _level = 0.0;
      });
      await _audio.startConversation(directory: directory, mode: _mode);
      if (mounted) setState(() => _active = true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _active = _audio.isConversationActive;
          _warning = 'شروع گفتگو ناموفق بود: $e';
        });
      }
    }
  }

  void _onEvent(ConversationEvent event) {
    if (!mounted) return;
    setState(() {
      switch (event.type) {
        case ConversationEventType.listening:
          _status = 'در حال گوش دادن…';
          _inSpeech = false;
        case ConversationEventType.speechStarted:
          _status = 'در حال ضبط صحبت شما…';
          _inSpeech = true;
        case ConversationEventType.segmentCompleted:
          _inSpeech = false;
          if (event.segment != null) _segments.add(event.segment!);
          _status = _mode == ConversationMode.continuous
              ? 'قطعه ضبط شد — دوباره صحبت کنید'
              : 'قطعه ضبط شد';
        case ConversationEventType.noSignal:
          _warning = event.message;
        case ConversationEventType.error:
          _warning = event.message;
          _status = 'خطا در جلسه گفتگو';
        case ConversationEventType.stopped:
          _active = false;
          _inSpeech = false;
          _level = 0.0;
          if (_status != 'خطا در جلسه گفتگو') _status = 'گفتگو متوقف شد';
      }
    });
  }

  Future<void> _playSegment(ConversationSegment segment) async {
    final path = segment.path;
    if (path == null) return;
    try {
      if (_audio.isConversationActive) await _audio.stopConversation();
      if (_playingPath == path) {
        await _audio.stop();
        setState(() => _playingPath = null);
        return;
      }
      await _audio.play(path);
      setState(() => _playingPath = path);
    } catch (e) {
      setState(() => _warning = 'پخش ناموفق: $e');
    }
  }

  String _reasonLabel(SegmentEndReason reason) {
    switch (reason) {
      case SegmentEndReason.silence:
        return 'سکوت';
      case SegmentEndReason.maxDuration:
        return 'حداکثر زمان';
      case SegmentEndReason.manual:
        return 'توقف دستی';
    }
  }

  String _tail(String? path) {
    if (path == null) return '(بدون مسیر)';
    return path.split(RegExp(r'[/\\]')).last;
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _levelSub?.cancel();
    if (_audio.isConversationActive) _audio.stopConversation();
    _audio.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('حالت گفتگوی صوتی'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 8),
              // Status pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _active
                      ? Colors.teal.withValues(alpha: 0.12)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _active ? Colors.teal.shade700 : Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // One-tap conversation button with a live mic meter ring.
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: _active
                        ? CircularProgressIndicator(
                            value: _level.clamp(0.0, 1.0),
                            strokeWidth: 8,
                            backgroundColor: Colors.grey[300],
                            color: _inSpeech ? Colors.red : Colors.teal,
                          )
                        : const SizedBox.shrink(),
                  ),
                  GestureDetector(
                    onTap: _toggleConversation,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: _active && _inSpeech ? 130 : 110,
                      height: _active && _inSpeech ? 130 : 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: !_active
                            ? Colors.grey[700]
                            : (_inSpeech ? Colors.red : Colors.teal),
                      ),
                      child: Icon(
                        _active ? (Icons.mic) : (Icons.mic_none),
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _active
                    ? 'میکروفون باز است — هرچه بگویید خودکار ضبط می‌شود'
                    : 'برای شروع گفتگو یک بار بزنید',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              // Mode switch
              SegmentedButton<ConversationMode>(
                segments: const [
                  ButtonSegment(
                    value: ConversationMode.continuous,
                    icon: Icon(Icons.all_inclusive),
                    label: Text('همیشه فعال'),
                  ),
                  ButtonSegment(
                    value: ConversationMode.single,
                    icon: Icon(Icons.filter_1),
                    label: Text('هوشمند یک‌بار'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: _active
                    ? null
                    : (selection) => setState(() => _mode = selection.first),
              ),
              if (_warning != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Text(
                    _warning!,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Expanded(
                child: _segments.isEmpty
                    ? Center(
                        child: Text(
                          _active
                              ? 'هنوز چیزی گفته نشده…'
                              : 'لیست قطعه‌های ضبط‌شده اینجا نمایش داده می‌شود',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        itemCount: _segments.length,
                        itemBuilder: (context, index) {
                          final segment = _segments[index];
                          final playing = _playingPath == segment.path;
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: playing
                                    ? Colors.green
                                    : Colors.teal.withValues(alpha: 0.2),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: playing
                                        ? Colors.white
                                        : Colors.teal.shade800,
                                  ),
                                ),
                              ),
                              title: Text(
                                _tail(segment.path),
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(
                                'مدت: ${(segment.duration.inMilliseconds / 1000).toStringAsFixed(1)} ثانیه — پایان: ${_reasonLabel(segment.reason)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  playing
                                      ? Icons.pause_circle
                                      : Icons.play_circle,
                                ),
                                color: playing ? Colors.green : Colors.teal,
                                iconSize: 32,
                                onPressed: () => _playSegment(segment),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
