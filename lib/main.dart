import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const NeuroTraceApp());
}

/// ---------------------- THEME & COLORS ----------------------
class NeuroTheme {
  static const Color teal = Color(0xFF00D1C7);
  static const Color amber = Color(0xFFF6B21A);
  static const Color bg = Color(0xFF0E1318);
  static const Color panel = Color(0xFF171D24);
  static const Color tileOff = Color(0xFF212A33);
  static const Color tileOn = Color(0xFF22E5B2);
  static const Color error = Color(0xFFFF4D4D);

  static const shadowGlow = [
    BoxShadow(
      blurRadius: 24,
      spreadRadius: -4,
      offset: Offset(0, 8),
      color: Color(0x8000FFC2),
    ),
  ];

  static LinearGradient brandGradient({
    Alignment begin = Alignment.centerLeft,
    Alignment end = Alignment.centerRight,
  }) =>
      const LinearGradient(colors: [teal, amber], begin: begin, end: end);

  static ThemeData theme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: teal,
      secondary: amber,
      surface: panel,
      error: error,
    ),
    textTheme: const TextTheme(
      headlineLarge:
          TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 1),
      headlineSmall: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white70),
      bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
    ),
    useMaterial3: true,
  );
}

/// ---------------------- APP ----------------------
class NeuroTraceApp extends StatelessWidget {
  const NeuroTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroTrace',
      debugShowCheckedModeBanner: false,
      theme: NeuroTheme.theme,
      home: const SplashScreen(),
    );
  }
}

/// ---------------------- SPLASH ----------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = Tween(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();

    Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const GameScreen()));
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ScaleTransition(
          scale: _scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo (fallback if missing)
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: NeuroTheme.brandGradient(),
                  boxShadow: NeuroTheme.shadowGlow,
                ),
                padding: const EdgeInsets.all(14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) {
                      return Container(
                        color: NeuroTheme.bg,
                        child: const Center(
                          child: Icon(Icons.bolt, color: Colors.white54, size: 60),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 22),
              ShaderMask(
                shaderCallback: (r) =>
                    NeuroTheme.brandGradient().createShader(r),
                child: Text(
                  'NEUROTRACE',
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge!
                      .copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '“You\'ve been traced. Free who you can.”',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------- GAME ----------------------
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int rows = 3;
  static const int cols = 5;
  static const int gridSize = rows * cols;

  final Random _rng = Random();
  List<int> _sequence = [];
  int _inputIndex = 0;
  bool _showingSequence = true;
  Set<int> _lit = {};
  int _round = 0;
  int _best = 0;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    _sequence = [];
    _round = 0;
    _nextRound();
  }

  void _nextRound() {
    _round += 1;
    _best = max(_best, _round - 1);
    _sequence.add(_rng.nextInt(gridSize));
    _inputIndex = 0;
    _playSequence();
  }

  Future<void> _playSequence() async {
    setState(() => _showingSequence = true);
    await Future.delayed(const Duration(milliseconds: 400));

    for (final idx in _sequence) {
      setState(() => _lit = {idx});
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _lit.clear());
      await Future.delayed(const Duration(milliseconds: 200));
    }

    setState(() => _showingSequence = false);
  }

  void _onTileTap(int index) {
    if (_showingSequence) return;

    final correct = _sequence[_inputIndex] == index;

    setState(() => _lit = {index});
    Future.delayed(const Duration(milliseconds: 150),
        () => setState(() => _lit.clear()));

    if (!correct) {
      _best = max(_best, _round - 1);
      _gameOver();
      return;
    }

    _inputIndex += 1;
    if (_inputIndex >= _sequence.length) {
      _nextRound();
    }
  }

  Future<void> _gameOver() async {
    setState(() => _showingSequence = true);
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: NeuroTheme.panel,
        title: const Text('TRACE LOCKED',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('You freed ${max(0, _round - 1)} souls.\nBest: $_best',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('AGAIN'),
          ),
        ],
      ),
    );
    _startNewGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: ShaderMask(
          shaderCallback: (r) => NeuroTheme.brandGradient().createShader(r),
          child: Text('NEUROTRACE',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall!
                  .copyWith(color: Colors.white)),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('Souls: ${max(0, _round - 1)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              _chip(Icons.visibility, _showingSequence ? 'Watch' : 'Your turn'),
              _chip(Icons.layers, 'Round $_round'),
              _chip(Icons.star, 'Best $_best'),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: gridSize,
                itemBuilder: (context, i) {
                  final active = _lit.contains(i);
                  return _Tile(
                    on: active,
                    disabled: _showingSequence,
                    onTap: () => _onTileTap(i),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: NeuroTheme.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: NeuroTheme.amber),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

/// ---------------------- TILE ----------------------
class _Tile extends StatelessWidget {
  final bool on;
  final bool disabled;
  final VoidCallback onTap;

  const _Tile(
      {required this.on, required this.disabled, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: on ? NeuroTheme.tileOn : NeuroTheme.tileOff,
          borderRadius: BorderRadius.circular(18),
          boxShadow: on
              ? [
                  const BoxShadow(
                      color: Color(0x4022E5B2), blurRadius: 24, spreadRadius: 2),
                ]
              : [],
        ),
      ),
    );
  }
}