import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() {
  runApp(const SpeakBeatApp());
}

class SpeakBeatApp extends StatelessWidget {
  const SpeakBeatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpeakBeat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SpeakBeatHomePage(),
    );
  }
}

class SpeakBeatHomePage extends StatefulWidget {
  const SpeakBeatHomePage({super.key});

  @override
  State<SpeakBeatHomePage> createState() => _SpeakBeatHomePageState();
}

class _SpeakBeatHomePageState extends State<SpeakBeatHomePage> {
  final FlutterTts _flutterTts = FlutterTts();

  Timer? _timer;
  int _bpm = 60; // 速度（每分钟拍数）
  int _beatsPerBar = 8; // 每小节拍数（默认8拍）
  int _currentBeat = 1;
  bool _isRunning = false;
  List<dynamic> _availableVoices = [];
  String? _selectedVoiceName;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    // 中文语音
    await _flutterTts.setLanguage('zh-CN');
    // 保持较自然的语速（0.0 - 1.0，平台相关）
    await _flutterTts.setSpeechRate(0.40);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.05);
    // 我们用定时器保证节拍，不等待说话完成
    await _flutterTts.awaitSpeakCompletion(false);

    // 尝试使用 Google TTS 引擎（Android），以获取更自然的声音
    try {
      await _flutterTts.setEngine('com.google.android.tts');
    } catch (_) {}

    await _loadVoicesAndSelectBest();
  }

  Future<void> _loadVoicesAndSelectBest() async {
    try {
      final voices = await _flutterTts.getVoices;
      if (voices is List) {
        _availableVoices = voices;
      } else {
        _availableVoices = [];
      }

      // 先尝试用户指定的优选默认声音
      const preferredName = 'cmn-cn-x-cce-local';
      Map<String, dynamic>? preferred;
      try {
        final dynamic raw = _availableVoices
            .whereType<Map>()
            .firstWhere((v) => v['name']?.toString() == preferredName, orElse: () => <String, dynamic>{});
        if (raw is Map) {
          final map = Map<String, dynamic>.from(raw);
          preferred = map.isEmpty ? null : map;
        }
      } catch (_) {
        preferred = null;
      }

      final best = preferred ?? _chooseBestChineseVoice(_availableVoices);
      if (best != null) {
        _selectedVoiceName = best['name']?.toString();
        await _flutterTts.setVoice({'name': best['name'], 'locale': best['locale']});
      }
      setState(() {});
    } catch (_) {
      // 忽略异常，继续使用默认语言配置
    }
  }

  Map<String, dynamic>? _chooseBestChineseVoice(List<dynamic> voices) {
    final candidates = voices
        .whereType<Map>()
        .where((v) => v['locale'] != null && v['locale'].toString().toLowerCase().startsWith('zh'))
        .toList();
    if (candidates.isEmpty) return null;

    // 1) 优先包含 female 关键词
    final female = candidates.firstWhere(
      (v) => v['name'] != null && v['name'].toString().toLowerCase().contains('female'),
      orElse: () => {},
    );
    if (female.isNotEmpty) return Map<String, dynamic>.from(female);

    // 2) 其次尝试常见的女声标识（不严格，仅作启发式）
    final hints = ['-a', 'f1', 'f2', 'woman', 'girl'];
    for (final h in hints) {
      final found = candidates.firstWhere(
        (v) => v['name'] != null && v['name'].toString().toLowerCase().contains(h),
        orElse: () => {},
      );
      if (found.isNotEmpty) return Map<String, dynamic>.from(found);
    }

    // 3) 退化：选择第一个中文声音
    return Map<String, dynamic>.from(candidates.first);
  }

  Duration get _beatInterval {
    final milliseconds = (60000 / _bpm).round();
    return Duration(milliseconds: milliseconds);
  }

  Future<void> _speakBeat(int beat) async {
    // 为避免叠音，在下一次说话前停止上一次
    await _flutterTts.stop();
    await _flutterTts.speak('$beat');
  }

  void _start() {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
    });

    // 立即播报第一次
    _currentBeat = 1;
    _speakBeat(_currentBeat);

    _timer?.cancel();
    _timer = Timer.periodic(_beatInterval, (timer) {
      if (!_isRunning) return;
      _currentBeat = _currentBeat % _beatsPerBar + 1;
      _speakBeat(_currentBeat);
      setState(() {});
    });
  }

  void _stop() {
    if (!_isRunning) return;
    _timer?.cancel();
    _timer = null;
    _flutterTts.stop();
    setState(() {
      _isRunning = false;
      _currentBeat = 1;
    });
  }

  void _toggle() {
    _isRunning ? _stop() : _start();
  }

  void _updateBpm(double value) {
    final next = value.round().clamp(30, 160);
    final needRestart = _isRunning;
    _timer?.cancel();
    setState(() {
      _bpm = next;
    });
    if (needRestart) {
      // 以新的间隔重启定时器
      _timer = Timer.periodic(_beatInterval, (timer) {
        if (!_isRunning) return;
        _currentBeat = _currentBeat % _beatsPerBar + 1;
        _speakBeat(_currentBeat);
        setState(() {});
      });
    }
  }

  void _updateBeatsPerBar(int value) {
    setState(() {
      _beatsPerBar = value;
      _currentBeat = 1;
    });
  }

  Future<void> _onVoiceChanged(String? voiceName) async {
    if (voiceName == null) return;
    final match = _availableVoices
        .whereType<Map>()
        .firstWhere((v) => v['name']?.toString() == voiceName, orElse: () => {});
    if (match.isEmpty) return;
    setState(() {
      _selectedVoiceName = voiceName;
    });
    try {
      await _flutterTts.setVoice({'name': match['name'], 'locale': match['locale']});
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('说话的节拍器'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 当前拍显示
            Expanded(
              child: Center(
                child: Text(
                  '$_currentBeat',
                  style: const TextStyle(fontSize: 96, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // BPM 控制
            Text('速度 (BPM): $_bpm', style: Theme.of(context).textTheme.titleMedium),
            Slider(
              value: _bpm.toDouble(),
              min: 30,
              max: 160,
              divisions: 130,
              label: _bpm.toString(),
              onChanged: (v) => _updateBpm(v),
            ),

            // 快捷步进按钮，便于精细/快速调节（自适应换行，避免溢出）
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _updateBpm((_bpm - 5).toDouble()),
                        child: const Text('-5'),
                      ),
                      OutlinedButton(
                        onPressed: () => _updateBpm((_bpm - 3).toDouble()),
                        child: const Text('-3'),
                      ),
                      OutlinedButton(
                        onPressed: () => _updateBpm((_bpm - 1).toDouble()),
                        child: const Text('-1'),
                      ),
                      OutlinedButton(
                        onPressed: () => _updateBpm((_bpm + 1).toDouble()),
                        child: const Text('+1'),
                      ),
                      OutlinedButton(
                        onPressed: () => _updateBpm((_bpm + 3).toDouble()),
                        child: const Text('+3'),
                      ),
                      OutlinedButton(
                        onPressed: () => _updateBpm((_bpm + 5).toDouble()),
                        child: const Text('+5'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '范围 30-160',
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 每小节拍数控制
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('每小节拍数'),
                DropdownButton<int>(
                  value: _beatsPerBar,
                  items: List.generate(16, (i) => i + 1)
                      .map((v) => DropdownMenuItem<int>(
                            value: v,
                            child: Text(v.toString()),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) _updateBeatsPerBar(v);
                  },
                ),
              ],
            ),

          const SizedBox(height: 8),

          // 声音选择（可选）
          if (_availableVoices.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('声音'),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: DropdownButton<String>(
                      value: _selectedVoiceName,
                      hint: const Text('自动选择'),
                      items: _availableVoices
                          .whereType<Map>()
                          .where((v) => v['locale'] != null && v['locale'].toString().toLowerCase().startsWith('zh'))
                          .map((v) => DropdownMenuItem<String>(
                                value: v['name']?.toString(),
                                child: Text(v['name']?.toString() ?? ''),
                              ))
                          .toList(),
                      onChanged: _onVoiceChanged,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 开始/停止按钮
            FilledButton.icon(
              onPressed: _toggle,
              icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
              label: Text(_isRunning ? '停止' : '开始'),
            ),
          ],
        ),
      ),
    );
  }
}
