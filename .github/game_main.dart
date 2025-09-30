// main.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const NeuroTraceApp());
}

class NeuroTraceApp extends StatelessWidget {
  const NeuroTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroTrace',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyan,
          secondary: Colors.amber,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const LogoScene(),
    );
  }
}

/// =============================
/// CONFIG
/// =============================
const Color kLogoOffBlack = Color(0xFF0B0B0B); // match your logo bg
const int kStartLives = 3;
const int kCols = 4;
const int kMaxRows = 7;
const Duration kFlashOn = Duration(milliseconds: 420);
const Duration kFlashOff = Duration(milliseconds: 180);
const Duration kInterStepPause = Duration(milliseconds: 220);
const Duration kBetweenRoundsPause = Duration(milliseconds: 600);
const Duration kSceneFade = Duration(milliseconds: 500);
const double kTrapChance = 0.35;

/// =============================
/// LOGO SCENE (Glitch → Fade Into Game)
/// =============================
class LogoScene extends StatefulWidget {
  const LogoScene({super.key});

  @override
  State<LogoScene> createState() => _LogoSceneState();
}

class _LogoSceneState extends State<LogoScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glitchCtrl;
  late final Animation<double> _jitter;
  late final Animation<double> _flicker;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _glitchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Explicit double tweens
    _jitter = Tween<double>(begin: 6.0, end: 0.0)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_glitchCtrl);

    _flicker = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween<double>(0.0), weight: 5),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: const _SteppyFlickerCurve(repeats: 8)),
        ),
        weight: 95,
      ),
    ]).animate(_glitchCtrl);

    _glitchCtrl.forward();
    Future.delayed(const Duration(milliseconds: 1550), () async {
      if (mounted) {
        setState(() => _done = true);
        await Future.delayed(kSceneFade);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: kSceneFade,
            pageBuilder: (_, __, ___) => const GameScene(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _glitchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLogoOffBlack,
      body: Center(
        child: AnimatedBuilder(
          animation: _glitchCtrl,
          builder: (context, _) {
            final j = _jitter.value;
            final r = Random(7);
            final dx = (r.nextDouble() * 2 - 1) * j;
            final dy = (r.nextDouble() * 2 - 1) * j;
            final opacity = 0.85 + 0.15 * _flicker.value;

            return AnimatedOpacity(
              opacity: _done ? 0.0 : opacity,
              duration: kSceneFade,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(dx, dy),
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                          Colors.cyan, BlendMode.modulate),
                      child: _Logo(),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(-dx, -dy),
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                          Colors.amber, BlendMode.modulate),
                      child: _Logo(),
                    ),
                  ),
                  _Logo(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shortest = size.shortestSide;
    return Image.asset(
      'assets/logo.png',
      width: shortest * 0.7,
      fit: BoxFit.contain,
    );
  }
}

class _SteppyFlickerCurve extends Curve {
  final int repeats;
  const _SteppyFlickerCurve({this.repeats = 6});
  @override
  double transform(double t) {
    final step = (t * repeats).floor();
    return step.isEven ? 0.2 + t * 0.8 : 1.0;
  }
}

/// =============================
/// GAME SCENE
/// =============================
class GameScene extends StatefulWidget {
  const GameScene({super.key});

  @override
  State<GameScene> createState() => _GameSceneState();
}

enum Phase { idle, revealing, input, roundEnd, gameOver }

class _GameState {
  int lives = kStartLives;
  int score = 0;
  int rows = 1;
  int roundsCleared = 0;

  final List<int> sequence = [];
  int? trapStepIndex;
  int inputProgress = 0;

  bool gaveSecondRowLife = false;

  void resetForNewRound() {
    sequence.clear();
    trapStepIndex = null;
    inputProgress = 0;
  }
}

class _GameSceneState extends State<GameScene> {
  final _rng = Random();
  final _state = _GameState();
  Phase _phase = Phase.idle;

  int? _flashingIndex;
  bool _isTrapFlash = false;

  @override
  void initState() {
    super.initState();
    _startNewRound(initial: true);
  }

  int get totalTiles => _state.rows * kCols;

  Future<void> _startNewRound({bool initial = false}) async {
    setState(() {
      _phase = Phase.idle;
      _state.resetForNewRound();
      _flashingIndex = null;
      _isTrapFlash = false;
    });

    final seqLen = max(3, _state.rows + 2);
    for (int i = 0; i < seqLen; i++) {
      _state.sequence.add(_rng.nextInt(totalTiles));
    }

    if (_state.rows >= 2 && _rng.nextDouble() < kTrapChance) {
      _state.trapStepIndex = _rng.nextInt(_state.sequence.length);
    }

    await Future.delayed(const Duration(milliseconds: 350));
    await _revealSequence();
    if (!mounted) return;
    setState(() => _phase = Phase.input);
  }

  Future<void> _revealSequence() async {
    setState(() => _phase = Phase.revealing);

    for (int i = 0; i < _state.sequence.length; i++) {
      final idx = _state.sequence[i];
      final isTrap = (i == _state.trapStepIndex);

      setState(() {
        _flashingIndex = idx;
        _isTrapFlash = isTrap;
      });
      await Future.delayed(kFlashOn);

      setState(() {
        _flashingIndex = null;
        _isTrapFlash = false;
      });
      await Future.delayed(kFlashOff + kInterStepPause);
    }
  }

  void _onTilePressed(int index) {
    if (_phase != Phase.input) return;
    HapticFeedback.selectionClick();

    final trapIndex = _state.trapStepIndex == null
        ? null
        : _state.sequence[_state.trapStepIndex!];

    if (trapIndex != null && index == trapIndex) {
      _loseLife(because: 'Trap tile tapped');
      return;
    }

    int progressed = 0;
    for (int i = 0; i < _state.sequence.length; i++) {
      if (i == _state.trapStepIndex) continue;
      if (progressed == _state.inputProgress) {
        final expected = _state.sequence[i];
        if (index == expected) {
          setState(() => _state.inputProgress++);
          _pulseTile(index);
          final needed =
              _state.sequence.length - (_state.trapStepIndex == null ? 0 : 1);
          if (_state.inputProgress == needed) {
            _handleRoundCleared();
          }
        } else {
          _loseLife(because: 'Wrong tile');
        }
        return;
      } else {
        progressed++;
      }
    }
  }

  Future<void> _pulseTile(int index) async {
    setState(() => _flashingIndex = index);
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() => _flashingIndex = null);
  }

  Future<void> _loseLife({required String because}) async {
    if (_phase == Phase.gameOver) return;
    setState(() {
      _state.lives -= 1;
    });
    await _shakeScreen();

    if (_state.lives <= 0) {
      setState(() => _phase = Phase.gameOver);
      return;
    }

    setState(() {
      _state.inputProgress = 0;
      _phase = Phase.idle;
    });
    await Future.delayed(kBetweenRoundsPause);
    if (!mounted) return;
    await _revealSequence();
    if (!mounted) return;
    setState(() => _phase = Phase.input);
  }

  Future<void> _shakeScreen() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    HapticFeedback.mediumImpact();
  }

  Future<void> _handleRoundCleared() async {
    setState(() {
      _phase = Phase.roundEnd;
      _state.roundsCleared += 1;
      _state.score += 100 + (_state.trapStepIndex != null ? 35 : 0);
    });

    await Future.delayed(kBetweenRoundsPause);

    if (_state.roundsCleared % 3 == 0 && _state.rows < kMaxRows) {
      setState(() => _state.rows += 1);

      if (_state.rows >= 2 && !_state.gaveSecondRowLife) {
        setState(() {
          _state.lives += 1;
          _state.gaveSecondRowLife = true;
        });
      }
    }

    await _startNewRound();
  }

  void _restartGame() {
    setState(() {
      _phase = Phase.idle;
      _state.lives = kStartLives;
      _state.score = 0;
      _state.rows = 1;
      _state.roundsCleared = 0;
      _state.gaveSecondRowLife = false;
      _state.resetForNewRound();
      _flashingIndex = null;
      _isTrapFlash = false;
    });
    _startNewRound();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C0D),
      body: SafeArea(
        child: Column(
          children: [
            _HeaderBar(
              lives: _state.lives,
              score: _state.score,
              rows: _state.rows,
              roundsCleared: _state.roundsCleared,
              phase: _phase,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gridW = constraints.maxWidth;
                  final gridH = constraints.maxHeight;
                  final tileSize = _tileSizeFor(
                    gridW: gridW,
                    gridH: gridH,
                    rows: _state.rows,
                    cols: kCols,
                  );

                  return Center(
                    child: SizedBox(
                      width: tileSize * kCols,
                      height: tileSize * _state.rows,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: kCols,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: totalTiles,
                        itemBuilder: (context, index) {
                          final isFlashing = _flashingIndex == index;
                          final isTrapFlashNow = isFlashing && _isTrapFlash;

                          return _TileButton(
                            index: index,
                            size: tileSize,
                            disabled: _phase != Phase.input,
                            flashing: isFlashing,
                            trapFlash: isTrapFlashNow,
                            onPressed: () => _onTilePressed(index),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            _BottomBar(
              onRestart: _restartGame,
              phase: _phase,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  double _tileSizeFor({
    required double gridW,
    required double gridH,
    required int rows,
    required int cols,
  }) {
    final gapsW = (cols - 1) * 8.0;
    final gapsH = (rows - 1) * 8.0;
    final maxTileW = (gridW - gapsW) / cols;
    final maxTileH = (gridH - gapsH) / rows;
    return min(maxTileW, maxTileH).clamp(32.0, 120.0);
  }
}

/// =============================
/// UI COMPONENTS
/// =============================
class _HeaderBar extends StatelessWidget {
  final int lives;
  final int score;
  final int rows;
  final int roundsCleared;
  final Phase phase;

  const _HeaderBar({
    required this.lives,
    required this.score,
    required this.rows,
    required this.roundsCleared,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Row(
            children: List.generate(
              max(0, lives),
              (_) => const Padding(
                padding: EdgeInsets.only(right: 4.0),
                child: Icon(Icons.favorite, size: 18, color: Colors.redAccent),
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surfaceVariant.withOpacity(0.25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
            ),
            child: Text('Rows: $rows | Cleared: $roundsCleared',
                style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.primary.withOpacity(0.3)),
            ),
            child: Text('Score: $score',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _TileButton extends StatelessWidget {
  final int index;
  final double size;
  final bool disabled;
  final bool flashing;
  final bool trapFlash;
  final VoidCallback onPressed;

  const _TileButton({
    required this.index,
    required this.size,
    required this.disabled,
    required this.flashing,
    required this.trapFlash,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final base = Container(
      decoration: BoxDecoration(
        color: flashing
            ? (trapFlash ? Colors.redAccent : cs.primary)
            : const Color(0xFF121416),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: trapFlash
              ? Colors.redAccent.withOpacity(0.8)
              : cs.primary.withOpacity(flashing ? 0.9 : 0.25),
          width: flashing ? 2 : 1,
        ),
        boxShadow: [
          if (flashing)
            BoxShadow(
              color: (trapFlash ? Colors.redAccent : cs.primary).withOpacity(0.55),
              blurRadius: 14,
              spreadRadius: 2,
            ),
        ],
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: disabled ? null : onPressed,
          child: Stack(
            children: [
              Positioned.fill(child: base),
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: flashing ? 1.0 : 0.0,
                  child: Center(
                    child: Icon(
                      trapFlash ? Icons.block : Icons.circle,
                      size: size * 0.28,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback onRestart;
  final Phase phase;

  const _BottomBar({required this.onRestart, required this.phase});

  @override
  Widget build(BuildContext context) {
    final isOver = phase == Phase.gameOver;
    final label = isOver ? 'Restart' : 'Replay Sequence';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: Icon(isOver ? Icons.refresh : Icons.play_arrow),
              onPressed: () {
                if (isOver) {
                  onRestart();
                } else {
                  HapticFeedback.selectionClick();
                  final st = context.findAncestorStateOfType<_GameSceneState>();
                  st?._revealSequence().then((_) {
                    if (st.mounted) {
                      st.setState(() => st._phase = Phase.input);
                    }
                  });
                }
              },
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(''),
              ),
              // Slight label tweak:
              // Using a builder to keep const above simple:
            ),
          ),
        ],
      ),
    );
  }
}