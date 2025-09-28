import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const NeuroTraceApp());

/// ====== THEME ======
const _bg = Color(0xFF0B0F14);
const _neonOn = Color(0xFF16F2A5);
const _neonOff = Color(0xFF1E2633);
const _neonEdge = Color(0xFF0EF0C0);
const _danger = Color(0xFFFF4D6D);

class NeuroTraceApp extends StatelessWidget {
  const NeuroTraceApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroTrace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _bg,
        colorScheme: ColorScheme.fromSeed(seedColor: _neonOn, brightness: Brightness.dark),
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Roboto'),
      ),
      home: const GameScreen(),
    );
  }
}

/// ====== GAME SCREEN ======
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

enum Phase { intro, playing, gameOver }

class _GameScreenState extends State<GameScreen> {
  // Session
  Phase phase = Phase.intro;
  int soulsFreed = 0; // your "score"

  // Round / difficulty
  int level = 1;          // increases after each clear
  late int size;          // grid side (3..5)
  late List<bool> grid;   // true = green (on), false = red (off)
  int moves = 0;

  // Timer
  Timer? _timer;
  int timeLeft = 0;       // seconds
  int roundTime = 0;      // seconds for this round

  // UI helpers
  bool get isCleared => grid.every((b) => b);
  bool get isAllRed => grid.every((b) => !b);
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _setupLevel(level);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// === Difficulty curve ===
  int _gridSizeForLevel(int lvl) => min(2 + lvl, 5); // 1→3, 2→4, 3+→5
  int _secondsForLevel(int lvl) {
    // Starts generous, shrinks with level, never below 8s
    final base = 28 - (lvl * 3);
    return base.clamp(8, 28);
  }

  void _setupLevel(int lvl) {
    size = _gridSizeForLevel(lvl);
    roundTime = _secondsForLevel(lvl);
    timeLeft = roundTime;
    moves = 0;

    // Start mixed: begin all red, then perform random valid taps to shuffle.
    grid = List<bool>.filled(size * size, false);
    for (int k = 0; k < size * 2; k++) {
      _toggleAtIndex(_rng.nextInt(size * size), countMove: false);
    }
    if (isCleared) _toggleAtIndex(_rng.nextInt(size * size), countMove: false); // avoid instant clear
    if (isAllRed) _toggleAtIndex(_rng.nextInt(size * size), countMove: false);  // avoid instant fry
    setState(() {});
  }

  /// Lights-Out style: tap flips itself + 4-neighbors
  void _toggleAtIndex(int index, {bool countMove = true}) {
    final x = index % size;
    final y = index ~/ size;
    void flip(int xx, int yy) {
      if (xx < 0 || yy < 0 || xx >= size || yy >= size) return;
      final i = yy * size + xx;
      grid[i] = !grid[i];
    }
    flip(x, y);
    flip(x + 1, y);
    flip(x - 1, y);
    flip(x, y + 1);
    flip(x, y - 1);
    if (countMove) moves++;
  }

  void _startRound() {
    phase = Phase.playing;
    timeLeft = roundTime;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (phase != Phase.playing) return;
      if (timeLeft <= 1) {
        _fryBrain(); // time out
        return;
      }
      setState(() => timeLeft--);

      // tiny AI "fight back": rarely flip a random tile on higher levels
      if (level >= 3 && _rng.nextDouble() < 0.08) {
        setState(() => _toggleAtIndex(_rng.nextInt(size * size), countMove: false));
        if (isAllRed) _fryBrain();
      }
    });
    setState(() {});
  }

  void _endRoundSuccess() {
    _timer?.cancel();

    // Souls freed = base per grid + time bonus
    final base = size;                 // 3..5
    final speedBonus = (timeLeft ~/ 2); // small bonus
    final gained = base + speedBonus;
    soulsFreed += gained;

    // Quick pulse message
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.black87,
          content: Text('SOULS LIBERATED +$gained   (Total: $soulsFreed)'),
          duration: const Duration(milliseconds: 1200),
        ),
      );

    // Next level
    setState(() {
      level++;
      _setupLevel(level);
    });

    // Auto-start next round after a short beat
    Future.delayed(const Duration(milliseconds: 500), _startRound);
  }

  void _fryBrain() {
    _timer?.cancel();
    setState(() => phase = Phase.gameOver);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121821),
        title: const Text('TRACE COMPLETE', style: TextStyle(color: _danger)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            const Text('YOUR MIND IS FRIED'),
            const SizedBox(height: 12),
            Text('SOULS FREED: $soulsFreed',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _restartRun();
            },
            child: const Text('New Run'),
          ),
        ],
      ),
    );
  }

  void _restartRun() {
    soulsFreed = 0;
    level = 1;
    _setupLevel(level);
    phase = Phase.intro;
    setState(() {});
  }

  void _onTapTile(int i) {
    if (phase != Phase.playing) return;
    setState(() => _toggleAtIndex(i));
    if (isCleared) _endRoundSuccess();
    if (isAllRed) _fryBrain();
  }

  @override
  Widget build(BuildContext context) {
    final tracePct = (100 - (timeLeft * 100 ~/ max(1, roundTime))).clamp(0, 100);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('NEUROTRACE'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('Souls: $soulsFreed',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 8),
              _hud(tracePct),
              const SizedBox(height: 8),
              Expanded(child: _gridView()),
              const SizedBox(height: 8),
            ],
          ),

          // Intro overlay
          if (phase == Phase.intro) _IntroOverlay(onStart: _startRound),

          // Subtle red vignette as time runs low
          if (phase == Phase.playing && timeLeft <= (roundTime / 3))
            IgnorePointer(
              child: Container(
                color: _danger.withOpacity(0.04),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hud(int tracePct) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _chip('Trace', '$tracePct%'),
          const SizedBox(width: 8),
          _chip('Level', '$level (${size}×$size)'),
          const Spacer(),
          _timerPill(timeLeft),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121821),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6))),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _timerPill(int secs) {
    final urgent = secs <= (roundTime / 3);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: urgent ? _danger.withOpacity(0.18) : const Color(0xFF121821),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: urgent ? _danger.withOpacity(0.6) : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 18, color: urgent ? _danger : Colors.white70),
          const SizedBox(width: 6),
          Text(
            '${secs}s',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: urgent ? _danger : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridView() {
    final w = MediaQuery.of(context).size.width;
    final padding = 20.0;
    final gap = 14.0;
    final tile = (w - padding * 2 - gap * (size - 1)) / size;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(size * size, (i) {
            final on = grid[i];
            return _NeonTile(
              on: on,
              extent: tile,
              onTap: () => _onTapTile(i),
            );
          }),
        ),
      ),
    );
  }
}

/// ====== INTRO OVERLAY ======
class _IntroOverlay extends StatelessWidget {
  final VoidCallback onStart;
  const _IntroOverlay({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.92),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'TRACE DETECTED',
                style: TextStyle(color: _danger, fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'The AI has found you.\nFree as many trapped minds as you can\nbefore your brain gets fried.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.85)),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: _neonOn,
                  foregroundColor: Colors.black,
                ),
                child: const Text('BEGIN HACK'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ====== TILE WIDGET ======
class _NeonTile extends StatelessWidget {
  final bool on;
  final double extent;
  final VoidCallback onTap;

  const _NeonTile({
    required this.on,
    required this.extent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = on ? _neonOn : _neonOff;
    final glow = on ? _neonEdge.withOpacity(0.35) : Colors.black;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: extent,
        height: extent,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [baseColor.withOpacity(on ? 1 : 0.9), baseColor.withOpacity(on ? 0.9 : 1)],
          ),
          boxShadow: [BoxShadow(color: glow, blurRadius: 28, spreadRadius: 2)],
          border: Border.all(
            color: on ? _neonEdge.withOpacity(0.5) : Colors.white12,
            width: 1.2,
          ),
        ),
      ),
    );
  }
}
