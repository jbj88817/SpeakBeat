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
  int _beatsPerBar = 4; // 每小节拍数
  int _currentBeat = 1;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    // 中文语音
    await _flutterTts.setLanguage('zh-CN');
    // 保持较自然的语速（0.0 - 1.0，平台相关）
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    // 我们用定时器保证节拍，不等待说话完成
    await _flutterTts.awaitSpeakCompletion(false);
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
    final next = value.round().clamp(30, 240);
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
              max: 240,
              divisions: 210,
              label: _bpm.toString(),
              onChanged: (v) => _updateBpm(v),
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
