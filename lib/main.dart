import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NeuroTraceApp());
}

class NeuroTraceApp extends StatelessWidget {
  const NeuroTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEUROTRACE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1318),
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 1.0),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF9FB4C6)),
          bodyMedium: TextStyle(fontSize: 16),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E6B8),
          brightness: Brightness.dark,
        ),
      ),
      home: const GameScreen(),
    );
  }
}

enum GamePhase { showing, input, gameOver }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Grid size
  static const int rows = 3;
  static const int cols = 5;
  static const int tileCount = rows * cols;

  // Visual timing
  static const Duration flashOn = Duration(milliseconds: 430);
  static const Duration flashOff = Duration(milliseconds: 170);
  static const Duration beatGap = Duration(milliseconds: 210);

  final Random _rng = Random();

  List<int> _sequence = [];      // full pattern
  int _inputIndex = 0;           // where player is in the pattern
  Set<int> _lit = {};            // which tiles are lit right now (for animation)
  GamePhase _phase = GamePhase.showing;

  int _level = 1;
  int _score = 0;
  int _lives = 3;

  bool _busy = false;            // guards concurrent taps during animations

  @override
  void initState() {
    super.initState();
    _startNewRun();
  }

  // --- game flow -------------------------------------------------------------

  void _startNewRun() {
    _sequence = [];
    _level = 1;
    _score = 0;
    _lives = 3;
    _extendSequenceAndShow();
  }

  void _extendSequenceAndShow() {
    _sequence.add(_rng.nextInt(tileCount));
    _inputIndex = 0;
    _phase = GamePhase.showing;
    setState(() {});
    _playbackSequence();
  }

  Future<void> _playbackSequence() async {
    _busy = true;
    // brief gap before playback
    await Future.delayed(const Duration(milliseconds: 500));

    for (final idx in _sequence) {
      if (!mounted) return;
      // turn tile on
      setState(() => _lit.add(idx));
      await Future.delayed(flashOn);

      // turn it off
      if (!mounted) return;
      setState(() => _lit.remove(idx));
      await Future.delayed(flashOff);

      // small beat gap
      await Future.delayed(beatGap);
    }

    if (!mounted) return;
    _phase = GamePhase.input;
    _busy = false;
    setState(() {});
  }

  Future<void> _handleTap(int index) async {
    if (_phase != GamePhase.input || _busy) return;

    // tap feedback (flash tile briefly)
    _busy = true;
    setState(() => _lit.add(index));
    await Future.delayed(const Duration(milliseconds: 160));
    if (mounted) setState(() => _lit.remove(index));
    _busy = false;

    // evaluate input
    if (index == _sequence[_inputIndex]) {
      _inputIndex++;
      if (_inputIndex >= _sequence.length) {
        // round complete
        _score += _sequence.length; // reward longer sequences more
        _level++;
        _extendSequenceAndShow();
      } else {
        setState(() {}); // partial progress UI refresh if you want later
      }
    } else {
      // mistake
      _lives--;
      if (_lives <= 0) {
        _phase = GamePhase.gameOver;
        setState(() {});
      } else {
        // show quick error flash on the correct tile as hint (optional)
        _showErrorBlink(_sequence[_inputIndex]);
        // restart same level from the beginning of the sequence
        _inputIndex = 0;
        _phase = GamePhase.showing;
        setState(() {});
        unawaited(_playbackSequence());
      }
    }
  }

  Future<void> _showErrorBlink(int correctIndex) async {
    _busy = true;
    setState(() => _lit.add(correctIndex));
    await Future.delayed(const Duration(milliseconds: 140));
    if (mounted) setState(() => _lit.remove(correctIndex));
    await Future.delayed(const Duration(milliseconds: 140));
    if (mounted) setState(() => _lit.add(correctIndex));
    await Future.delayed(const Duration(milliseconds: 140));
    if (mounted) setState(() => _lit.remove(correctIndex));
    _busy = false;
  }

  // --- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & HUD
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('NEUROTRACE', style: text.headlineMedium),
                  Row(children: [
                    _hudChip(Icons.favorite, '$_lives', tooltip: 'Lives'),
                    const SizedBox(width: 8),
                    _hudChip(Icons.stacked_bar_chart, 'Lv $_level'),
                    const SizedBox(width: 8),
                    _hudChip(Icons.star, '$_score'),
                  ]),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _phase == GamePhase.showing
                    ? 'Watch the pattern…'
                    : _phase == GamePhase.input
                        ? 'Repeat the pattern'
                        : 'Trace terminated. Souls freed: $_score',
                style: text.titleMedium,
              ),
              const SizedBox(height: 16),

              // Grid area
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: cols / rows, // keep tiles square
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final gap = 12.0;
                        final tileW = (constraints.maxWidth - gap * (cols - 1)) / cols;
                        final tileH = (constraints.maxHeight - gap * (rows - 1)) / rows;
                        final size = min(tileW, tileH);

                        return Wrap(
                          runSpacing: gap,
                          spacing: gap,
                          children: List.generate(tileCount, (i) {
                            final lit = _lit.contains(i);
                            return _Tile(
                              size: Size.square(size),
                              lit: lit,
                              onTap: () => _handleTap(i),
                              enabled: _phase == GamePhase.input && !_busy,
                            );
                          }),
                        );
                      },
                    ),
                  ),
                ),
              ),

              // Bottom buttons
              if (_phase == GamePhase.gameOver) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _startNewRun,
                    child: const Padding(
                      padding: EdgeInsets.all(14.0),
                      child: Text('RUN IT BACK'),
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _hudChip(IconData icon, String text, {String? tooltip}) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF151B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF23303C)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF8DA3B3)),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip, child: chip);
  }
}

class _Tile extends StatelessWidget {
  final Size size;
  final bool lit;
  final VoidCallback onTap;
  final bool enabled;

  const _Tile({
    required this.size,
    required this.lit,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final base = const Color(0xFF1A222B);
    final on = const Color(0xFF14F2C1);
    final glow = on.withOpacity(0.36);

    return SizedBox(
      width: size.width,
      height: size.height,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: lit ? on.withOpacity(0.22) : base,
            borderRadius: BorderRadius.circular(22),
            boxShadow: lit
                ? [
                    BoxShadow(color: glow, blurRadius: 28, spreadRadius: 4),
                    BoxShadow(color: glow.withOpacity(0.6), blurRadius: 12, spreadRadius: 2),
                  ]
                : [
                    const BoxShadow(color: Colors.black54, blurRadius: 10, spreadRadius: 0),
                  ],
            border: Border.all(
              color: lit ? on.withOpacity(0.75) : const Color(0xFF2A3642),
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

// Utility to silence unawaited lints without adding pedantic packages
void unawaited(Future<void> _) {}