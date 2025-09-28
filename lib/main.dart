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
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0F141B)),
      home: const MemoryGameScreen(),
    );
  }
}

class MemoryGameScreen extends StatefulWidget {
  const MemoryGameScreen({super.key});
  @override
  State<MemoryGameScreen> createState() => _MemoryGameScreenState();
}

enum Phase { intro, showing, input, fail, gameOver }

class _MemoryGameScreenState extends State<MemoryGameScreen> {
  // Grid
  static const int rows = 3;
  static const int cols = 5;
  static const int tileCount = rows * cols;

  // Game state
  final rng = Random();
  Phase phase = Phase.intro;
  List<int> sequence = [];
  int inputIndex = 0;
  int souls = 0;         // score (souls freed)
  int bestSouls = 0;     // session best (no persistence)

  // Visuals
  int? highlighted;      // which tile is flashing now
  bool flashWin = false;

  // Timing
  Timer? _showTimer;
  Duration get beat => _beatForRound(sequence.length);
  Duration _beatForRound(int len) {
    // Faster as the sequence gets longer
    final ms = (520 - (len * 12)).clamp(260, 520);
    return Duration(milliseconds: ms);
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    super.dispose();
  }

  /* -------------------- Game flow -------------------- */

  void _startRun() {
    souls = 0;
    sequence.clear();
    phase = Phase.showing;
    _extendSequence();
  }

  void _extendSequence() {
    sequence.add(rng.nextInt(tileCount));
    inputIndex = 0;
    _playback();
  }

  Future<void> _playback() async {
    phase = Phase.showing;
    setState(() { highlighted = null; });

    // short settle
    await Future.delayed(const Duration(milliseconds: 400));

    for (final i in sequence) {
      setState(() => highlighted = i);
      await Future.delayed(beat);
      setState(() => highlighted = null);
      await Future.delayed(Duration(milliseconds: (beat.inMilliseconds * 0.45).round()));
    }

    phase = Phase.input;
    setState(() {});
  }

  void _handleTap(int index) {
    if (phase != Phase.input) return;

    // tap feedback flash
    setState(() => highlighted = index);
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => highlighted = null);
    });

    if (index == sequence[inputIndex]) {
      inputIndex++;
      if (inputIndex == sequence.length) {
        // round complete
        souls += 1;                      // one soul per round
        _pulseWin();
        Future.delayed(const Duration(milliseconds: 440), () {
          if (!mounted) return;
          _extendSequence();
        });
      }
    } else {
      // wrong input
      phase = Phase.fail;
      setState(() {});
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        bestSouls = max(bestSouls, souls);
        phase = Phase.gameOver;
        setState(() {});
      });
    }
  }

  void _pulseWin() {
    setState(() => flashWin = true);
    Future.delayed(const Duration(milliseconds: 140), () {
      if (mounted) setState(() => flashWin = false);
    });
  }

  void _restart() {
    phase = Phase.intro;
    sequence.clear();
    inputIndex = 0;
    highlighted = null;
    setState(() {});
  }

  /* -------------------- UI -------------------- */

  @override
  Widget build(BuildContext context) {
    final headerStyle = const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 1.2);

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // title + score
                  Row(
                    children: [
                      const Text('NEUROTRACE', style: headerStyle),
                      const Spacer(),
                      _chip('Souls: $souls', icon: Icons.favorite),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _chip('Round: ${sequence.isEmpty ? 0 : sequence.length}', icon: Icons.memory),
                      const SizedBox(width: 8),
                      _chip('Best: $bestSouls', icon: Icons.emoji_events),
                      const Spacer(),
                      _phaseChip(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: _board()),
                ],
              ),
            ),
          ),

          // Intro overlay
          if (phase == Phase.intro) _IntroOverlay(onStart: _startRun),

          // Game over overlay
          if (phase == Phase.gameOver)
            _GameOverOverlay(
              souls: souls,
              best: bestSouls,
              onRestart: _restart,
              onPlayAgain: _startRun,
            ),

          // Win pulse
          IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: flashWin ? 1 : 0,
              child: Container(color: const Color(0xFF00E6A8).withOpacity(0.08)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _phaseChip() {
    String label;
    IconData icon;
    switch (phase) {
      case Phase.intro:
        label = 'Ready'; icon = Icons.play_arrow_rounded; break;
      case Phase.showing:
        label = 'Watch'; icon = Icons.visibility; break;
      case Phase.input:
        label = 'Repeat'; icon = Icons.touch_app; break;
      case Phase.fail:
        label = 'Wrong'; icon = Icons.close_rounded; break;
      case Phase.gameOver:
        label = 'Trace Complete'; icon = Icons.warning_amber_rounded; break;
    }
    return _chip(label, icon: icon);
  }

  Widget _board() {
    final panel = const Color(0xFF121923);
    final w = MediaQuery.sizeOf(context).width;
    final gap = 10.0;
    final tile = (w - 36 - gap * (cols - 1)) / cols; // 18px side padding each

    return Center(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 28)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(rows, (r) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(cols, (c) {
                final idx = r * cols + c;
                final lit = highlighted == idx && (phase == Phase.showing || phase == Phase.input);
                return Padding(
                  padding: EdgeInsets.all(gap / 2),
                  child: _Tile(
                    size: tile,
                    lit: lit,
                    label: (idx + 1).toString(),
                    onTap: () => _handleTap(idx),
                    enabled: phase == Phase.input,
                  ),
                );
              }),
            );
          }),
        ),
      ),
    );
  }

  Widget _chip(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141A22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 6),
          ],
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

/* -------------------- Widgets -------------------- */

class _Tile extends StatelessWidget {
  final double size;
  final bool lit;
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  const _Tile({
    required this.size,
    required this.lit,
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final on = const Color(0xFF18E0A4);
    final offG1 = const Color(0xFF1B2430);
    final offG2 = const Color(0xFF161C27);

    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: lit
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF00F0B6), Color(0xFF00C893)],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [offG1, offG2],
              ),
        boxShadow: lit
            ? [
                BoxShadow(color: on.withOpacity(0.55), blurRadius: 24, spreadRadius: 2),
              ]
            : const [
                BoxShadow(color: Colors.black45, blurRadius: 10, spreadRadius: 0),
              ],
        border: Border.all(color: lit ? Colors.white12 : const Color(0xFF222A36), width: 1.2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: lit ? Colors.black : Colors.white70,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return enabled
        ? GestureDetector(onTap: onTap, child: child)
        : AbsorbPointer(child: child);
  }
}

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
                style: TextStyle(color: Color(0xFFFF5A76), fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Watch the pattern. Repeat it back.\nEach round frees a soul.\nMiss once and the AI fries you.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.85)),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00E6A8),
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

class _GameOverOverlay extends StatelessWidget {
  final int souls;
  final int best;
  final VoidCallback onRestart;
  final VoidCallback onPlayAgain;
  const _GameOverOverlay({
    required this.souls,
    required this.best,
    required this.onRestart,
    required this.onPlayAgain,
  });

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
                'TRACE COMPLETE',
                style: TextStyle(color: Color(0xFFFF5A76), fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text('Souls freed: $souls', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Text('Best this session: $best', style: const TextStyle(fontSize: 14, color: Colors.white70)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onRestart,
                      child: const Text('MENU'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onPlayAgain,
                      child: const Text('PLAY AGAIN'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
