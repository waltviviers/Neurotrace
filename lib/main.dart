import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const NeuroTraceApp());
}

class NeuroTraceApp extends StatelessWidget {
  const NeuroTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0C1014),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF13C7B9), // teal-ish
        secondary: Color(0xFFF5B646), // amber-ish
        surface: Color(0xFF12171D),
        onSurface: Colors.white,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.0),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'NEUROTRACE',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // Grid: 3 x 5
  static const int rows = 5;
  static const int cols = 3;
  static const Duration stepOn = Duration(milliseconds: 480);
  static const Duration stepGap = Duration(milliseconds: 140);

  final Random _rng = Random();
  final List<int> _sequence = <int>[];
  final List<int> _player = <int>[];

  late List<AnimationController> _glowCtrls;
  late List<AnimationController> _errorCtrls;

  int _level = 1;
  bool _inputEnabled = false;
  bool _isPlayingDemo = false;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    final total = rows * cols;
    _glowCtrls = List<AnimationController>.generate(
      total,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
        lowerBound: 0.0,
        upperBound: 1.0,
      ),
    );
    _errorCtrls = List<AnimationController>.generate(
      total,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 180),
        lowerBound: 0.0,
        upperBound: 1.0,
      ),
    );
    _newGame();
  }

  @override
  void dispose() {
    for (final c in _glowCtrls) {
      c.dispose();
    }
    for (final c in _errorCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _newGame() {
    _sequence.clear();
    _player.clear();
    _score = 0;
    _level = 1;
    _extendSequence();
    _playSequence();
  }

  void _extendSequence() {
    final total = rows * cols;
    _sequence.add(_rng.nextInt(total));
  }

  Future<void> _playSequence() async {
    setState(() {
      _inputEnabled = false;
      _isPlayingDemo = true;
      _player.clear();
    });

    await Future.delayed(const Duration(milliseconds: 420));

    for (final idx in _sequence) {
      await _flashTile(idx);
      await Future.delayed(stepGap);
    }

    setState(() {
      _inputEnabled = true;
      _isPlayingDemo = false;
    });
  }

  Future<void> _flashTile(int index) async {
    final c = _glowCtrls[index];
    try {
      await c.forward();
      await Future.delayed(stepOn);
      await c.reverse();
    } catch (_) {}
  }

  Future<void> _flashError(int index) async {
    final e = _errorCtrls[index];
    try {
      await e.forward();
      await Future.delayed(const Duration(milliseconds: 120));
      await e.reverse();
    } catch (_) {}
  }

  Future<void> _onTapTile(int index) async {
    if (!_inputEnabled || _isPlayingDemo) return;

    // Give a tiny active flash even during input
    unawaited(_glowCtrls[index].forward().then((_) => _glowCtrls[index].reverse()));

    _player.add(index);

    final pos = _player.length - 1;
    if (_sequence[pos] != index) {
      // Wrong — flash that tile red and replay
      await _flashError(index);
      setState(() {
        _score = max(0, _score - 1);
      });
      _player.clear();
      _inputEnabled = false;
      await Future.delayed(const Duration(milliseconds: 350));
      await _playSequence();
      return;
    }

    // Correct so far
    if (_player.length == _sequence.length) {
      // Completed level
      setState(() {
        _score += 3 + _level; // small reward
        _level += 1;
      });
      _extendSequence();
      _inputEnabled = false;
      await Future.delayed(const Duration(milliseconds: 420));
      await _playSequence();
    } else {
      // Partial progress
      setState(() {
        _score += 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Background image + subtle gradient tint
        DecoratedBox(
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage('assets/bg_texture.png'),
              fit: BoxFit.cover,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primary.withOpacity(0.12),
                cs.secondary.withOpacity(0.12),
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),

        // Content
        Scaffold(
          backgroundColor: Colors.black.withOpacity(0.15),
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _HeaderBar(score: _score),
                const SizedBox(height: 8),

                // Level / status
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      _Pill(
                        icon: Icons.memory,
                        label: 'Level',
                        value: '$_level',
                      ),
                      const SizedBox(width: 12),
                      _Pill(
                        icon: Icons.grid_3x3,
                        label: 'Grid',
                        value: '3×5',
                      ),
                      const Spacer(),
                      _Pill(
                        icon: _isPlayingDemo ? Icons.visibility : Icons.touch_app,
                        label: _isPlayingDemo ? 'Watch' : 'Repeat',
                        value: _isPlayingDemo ? 'Demo' : 'Now',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Grid stretches in portrait
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 3 / 5, // 3 columns × 5 rows
                      child: _TileGrid(
                        rows: rows,
                        cols: cols,
                        glowCtrls: _glowCtrls,
                        errorCtrls: _errorCtrls,
                        onTap: _onTapTile,
                        inputEnabled: _inputEnabled && !_isPlayingDemo,
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isPlayingDemo ? null : _newGame,
                          icon: const Icon(Icons.refresh),
                          label: const Text('New Run'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: cs.surface.withOpacity(0.7),
                            foregroundColor: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Very soft vignette
        IgnorePointer(
          ignoring: true,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.15),
                  Colors.transparent,
                  Colors.black.withOpacity(0.25),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2),
      child: Row(
        children: [
          // Logo + title
          Row(
            children: [
              // Your logo
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: const DecorationImage(
                    image: AssetImage('assets/logo.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: <Color>[cs.primary, cs.secondary],
                  ).createShader(bounds);
                },
                child: const Text(
                  'NEUROTRACE',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Colors.white, // masked
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Score pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.favorite, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Souls: $score',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurface),
          const SizedBox(width: 6),
          Text(
            '$label ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TileGrid extends StatelessWidget {
  const _TileGrid({
    required this.rows,
    required this.cols,
    required this.glowCtrls,
    required this.errorCtrls,
    required this.onTap,
    required this.inputEnabled,
  });

  final int rows;
  final int cols;
  final List<AnimationController> glowCtrls;
  final List<AnimationController> errorCtrls;
  final void Function(int) onTap;
  final bool inputEnabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = 12.0;
        final tileW = (constraints.maxWidth - spacing * (cols - 1)) / cols;
        final tileH = (constraints.maxHeight - spacing * (rows - 1)) / rows;
        final size = min(tileW, tileH);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(rows, (r) {
            return Padding(
              padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : spacing),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List<Widget>.generate(cols, (c) {
                  final index = r * cols + c;
                  return Padding(
                    padding: EdgeInsets.only(right: c == cols - 1 ? 0 : spacing),
                    child: _Tile(
                      size: size,
                      cs: cs,
                      glow: glowCtrls[index],
                      error: errorCtrls[index],
                      onTap: inputEnabled ? () => onTap(index) : null,
                    ),
                  );
                }),
              ),
            );
          }),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.size,
    required this.cs,
    required this.glow,
    required this.error,
    required this.onTap,
  });

  final double size;
  final ColorScheme cs;
  final AnimationController glow;
  final AnimationController error;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Animation<double> glowA = CurvedAnimation(
      parent: glow,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final Animation<double> errA = CurvedAnimation(
      parent: error,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final List<BoxShadow> baseShadow = <BoxShadow>[
      BoxShadow(
        color: Colors.black.withOpacity(0.35),
        blurRadius: 12,
        spreadRadius: 1,
        offset: const Offset(2, 4),
      ),
    ];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([glowA, errA]),
        builder: (context, _) {
          final glowStrength = glowA.value;
          final errStrength = errA.value;

          // Blend colors: teal glow or red flash
          final Color tileColor = Color.lerp(
                const Color(0xFF1D2732),
                cs.primary,
                glowStrength * 0.8,
              ) ??
              const Color(0xFF1D2732);

          final List<BoxShadow> shadow = <BoxShadow>[
            ...baseShadow,
            if (glowStrength > 0)
              BoxShadow(
                color: cs.primary.withOpacity(0.55 * glowStrength),
                blurRadius: 24 + 24 * glowStrength,
                spreadRadius: 1 + 2 * glowStrength,
              ),
            if (errStrength > 0)
              BoxShadow(
                color: Colors.redAccent.withOpacity(0.7 * errStrength),
                blurRadius: 28,
                spreadRadius: 2,
              ),
          ];

          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: tileColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: shadow,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  tileColor.withOpacity(0.95),
                  tileColor.withOpacity(0.75),
                ],
              ),
            ),
            child: AnimatedOpacity(
              opacity: errStrength > 0 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 80),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.35 * errStrength),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}