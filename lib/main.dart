import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const NeuroTraceApp());

class NeuroTraceApp extends StatelessWidget {
  const NeuroTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroTrace',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(fontSize: 16),
        ),
      ),
      home: const MemoryGameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MemoryGameScreen extends StatefulWidget {
  const MemoryGameScreen({super.key});
  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<MemoryGameScreen> {
  final _rng = Random();
  final int _gridSize = 9; // 3x3 grid => 9 tiles (indices 0..8)

  List<int> _sequence = [];
  int _inputIndex = 0;
  bool _showing = false;
  int? _highlight; // which tile is flashing right now
  int _round = 0;
  int _best = 0;
  String _stateText = 'Tap ▶ to begin';

  // Colors for tiles (base + highlight)
  static const _baseColor = Color(0xFF0A0F14);
  static const _highlightColor = Color(0xFF00FFA8);

  Future<void> _playback() async {
    setState(() {
      _showing = true;
      _stateText = 'Watch the sequence…';
      _highlight = null;
    });
    await Future.delayed(const Duration(milliseconds: 400));

    for (final i in _sequence) {
      setState(() => _highlight = i);
      await Future.delayed(const Duration(milliseconds: 420));
      setState(() => _highlight = null);
      await Future.delayed(const Duration(milliseconds: 180));
    }

    setState(() {
      _showing = false;
      _stateText = 'Repeat the sequence';
      _inputIndex = 0;
    });
  }

  Future<void> _startRound() async {
    _sequence.add(_rng.nextInt(_gridSize));
    _round = _sequence.length - 1; // completed rounds
    await _playback();
  }

  void _resetGame({bool keepBest = true}) {
    if (keepBest) _best = max(_best, _round);
    _sequence = [];
    _round = 0;
    _inputIndex = 0;
    _highlight = null;
    _showing = false;
    _stateText = 'Tap ▶ to begin';
    setState(() {});
  }

  void _onTileTap(int idx) {
    if (_showing || _sequence.isEmpty) return; // ignore during playback / not started

    // flash on tap for feedback
    setState(() => _highlight = idx);
    Timer(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => _highlight = null);
    });

    if (idx == _sequence[_inputIndex]) {
      _inputIndex++;
      // completed this round
      if (_inputIndex == _sequence.length) {
        setState(() {
          _round = _sequence.length;
          _stateText = 'Nice! Round $_round';
        });
        // short pause then next round
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _startRound();
        });
      }
    } else {
      // wrong tile — game over
      _best = max(_best, _round);
      setState(() {
        _stateText = 'Wrong! Score: $_round  •  Best: $_best';
      });
      // allow restart
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _resetGame(keepBest: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canStart = !_showing && _sequence.isEmpty;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('NeuroTrace'),
        actions: [
          IconButton(
            tooltip: 'Restart',
            onPressed: () => _resetGame(),
            icon: const Icon(Icons.refresh),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Round: $_round', style: Theme.of(context).textTheme.bodyMedium),
                  const Spacer(),
                  Text('Best: $_best', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _stateText,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Start',
                    onPressed: canStart ? _startRound : null,
                    icon: const Icon(Icons.play_arrow_rounded, size: 32),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: _gridSize,
                    itemBuilder: (context, idx) {
                      final isLit = _highlight == idx;
                      return _Tile(
                        lit: isLit,
                        label: '${idx + 1}',
                        onTap: () => _onTileTap(idx),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final bool lit;
  final String label;
  final VoidCallback onTap;

  const _Tile({required this.lit, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: lit ? _highlightColor.withOpacity(0.9) : _baseColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 120),
            style: TextStyle(
              color: lit ? Colors.black : Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 22,
              letterSpacing: 0.5,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
