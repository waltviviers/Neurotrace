import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for SystemSound

// ===================== CONFIG =====================
const String LOGO_ASSET = 'assets/images/logo.png';
// Set this to the exact off-black behind your logo so it blends perfectly.
const Color OFF_BLACK = Color(0xFF0D0D0D); // <-- tweak to match your logo bg
// ===================== CONFIG =====================

void main() => runApp(const NeuroTraceApp());

class NeuroTraceApp extends StatelessWidget {
  const NeuroTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const SplashScreen(), // start at splash
    );
  }
}

/// ============================================================================
/// SPLASH → GAME
/// ============================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;
  late final Animation<double> _glitch; // 0..1 for timing the jitter
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Precache the logo so there’s no pop-in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage(LOGO_ASSET), context);
    });

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Gentle fade/scale in overall
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.9, curve: Curves.easeOut));
    _scaleIn = Tween<double>(begin: 0.98, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.25, 0.9, curve: Curves.easeOutBack)),
    );

    // Glitch phase in the first ~350ms
    _glitch = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.28, curve: Curves.easeOut),
    );

    _ctrl.forward();
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) _goToGame();
    });
  }

  void _goToGame() {
    if (_navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => const GameScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Quick RGB-split offsets based on glitch progress
  Offset _redOffset(double t) {
    final mag = (1.0 - (t)).clamp(0, 1) * 6; // px
    return Offset(mag, 0);
  }

  Offset _cyanOffset(double t) {
    final mag = (1.0 - (t)).clamp(0, 1) * -6; // px opposite
    return Offset(mag, 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _goToGame, // tap to skip
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _glitch.value;
          final showGlitch = t > 0.0 && t < 1.0;

          return Container(
            color: OFF_BLACK, // exact off-black so the logo "floats"
            child: Center(
              child: FadeTransition(
                opacity: _fadeIn,
                child: Transform.scale(
                  scale: _scaleIn.value,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Base clean logo
                      Image.asset(LOGO_ASSET, filterQuality: FilterQuality.high),

                      // Glitch layers (very brief)
                      if (showGlitch) ...[
                        Transform.translate(
                          offset: _redOffset(t),
                          child: ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                              Color(0x55FF0000), BlendMode.plus,
                            ),
                            child: Image.asset(LOGO_ASSET),
                          ),
                        ),
                        Transform.translate(
                          offset: _cyanOffset(t),
                          child: ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                              Color(0x5500FFFF), BlendMode.plus,
                            ),
                            child: Image.asset(LOGO_ASSET),
                          ),
                        ),
                        // scanline texture (subtle)
                        IgnorePointer(
                          child: Opacity(
                            opacity: 0.07 * (1.0 - t),
                            child: CustomPaint(
                              size: const Size(double.infinity, 120),
                              painter: _ScanlinePainter(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Simple scanline painter across the top region for a quick “CRT” vibe
class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.12);
    final gap = 3.0;
    double y = 0;
    final w = 220.0; // a band width; it’s centered by parent stack
    while (y < size.height) {
      canvas.drawRect(Rect.fromLTWH(-w / 2, y, w, 1), paint);
      y += gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ============================================================================
/// GAME (your existing file, unchanged except now it’s a separate screen)
/// ============================================================================

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController game;

  TileRef? flashing;
  bool isPlayingBack = false;
  bool inputOpen = false;

  int lives = 3;
  int score = 0;

  bool pulseLives = false;
  bool showPlusOne = false;

  @override
  void initState() {
    super.initState();
    game = GameController(
      onLoseLife: () {
        setState(() => lives = (lives - 1).clamp(0, 99));
      },
      onScore: () {
        setState(() => score++);
      },
      onUnlockSecondRow: () {},
      onGrantExtraLifeOnce: () {
        setState(() {
          lives = (lives + 1).clamp(0, 99);
          pulseLives = true;
          showPlusOne = true;
        });
        SystemSound.play(SystemSoundType.click);
        Timer(const Duration(milliseconds: 450), () {
          if (mounted) setState(() => pulseLives = false);
        });
        Timer(const Duration(milliseconds: 900), () {
          if (mounted) setState(() => showPlusOne = false);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Extra life awarded!')),
        );
      },
    );
  }

  Future<void> _startNewRound() async {
    if (isPlayingBack) return;
    setState(() {
      flashing = null;
      inputOpen = false;
      isPlayingBack = true;
    });

    await game.startNewRound(onFlash: (tile, {required bool isTrap}) async {
      setState(() => flashing = tile);
      await Future.delayed(const Duration(milliseconds: 260));
      setState(() => flashing = null);
      await Future.delayed(const Duration(milliseconds: 140));
    });

    setState(() {
      isPlayingBack = false;
      inputOpen = true;
    });
  }

  void _handleTap(TileRef tile) {
    if (!inputOpen || isPlayingBack) return;

    final result = game.onTileTap(tile);
    if (result.roundEnded) {
      setState(() {
        inputOpen = false;
        flashing = null;
      });
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_texture.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.35))),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _hudChip(Icons.favorite, 'Lives', '$lives', pulse: pulseLives, plusOne: showPlusOne),
                      const SizedBox(width: 12),
                      _hudChip(Icons.auto_awesome, 'Score', '$score'),
                      const Spacer(),
                      _hudChip(Icons.grid_view, 'Rows', '${game.rows}'),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cellW = constraints.maxWidth / game.cols;
                        final cellH = constraints.maxHeight / max(1, game.rows);
                        final size = min(cellW, cellH) * 0.9;

                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(game.rows, (r) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(game.cols, (c) {
                                  final ref = TileRef(r, c);
                                  final isFlash = flashing == ref;
                                  final isTrap = game.trapTiles.contains(ref) && isPlayingBack;

                                  return Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: GestureDetector(
                                      onTap: () => _handleTap(ref),
                                      child: Tile(
                                        size: size,
                                        flashing: isFlash,
                                        isTrapFlash: isTrap,
                                        enabled: inputOpen,
                                      ),
                                    ),
                                  );
                                }),
                              );
                            }),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _startNewRound,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(isPlayingBack ? 'Playing…' : 'New Run'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudChip(
    IconData icon,
    String label,
    String value, {
    bool pulse = false,
    bool plusOne = false,
  }) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );

    final stacked = Stack(
      clipBehavior: Clip.none,
      children: [
        chip,
        if (plusOne)
          const Positioned(
            right: -6,
            top: -12,
            child: _RisingPlusOne(),
          ),
      ],
    );

    return AnimatedScale(
      scale: pulse ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: stacked,
    );
  }
}

/// Floating “+1” animation
class _RisingPlusOne extends StatefulWidget {
  const _RisingPlusOne({super.key});
  @override
  State<_RisingPlusOne> createState() => _RisingPlusOneState();
}

class _RisingPlusOneState extends State<_RisingPlusOne>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _y;
  late final Animation<double> _alpha;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _y = Tween<double>(begin: 0, end: -20).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _alpha = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, _y.value),
          child: Opacity(
            opacity: _alpha.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.7)),
              ),
              child: const Text(
                '+1',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ================== TILE WIDGET ==================
class Tile extends StatelessWidget {
  final double size;
  final bool flashing;
  final bool isTrapFlash;
  final bool enabled;

  const Tile({
    super.key,
    required this.size,
    required this.flashing,
    required this.isTrapFlash,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final base = Colors.tealAccent.withOpacity(0.15);
    final flash = isTrapFlash
        ? Colors.redAccent.withOpacity(0.9)
        : Colors.tealAccent.withOpacity(0.9);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: flashing ? flash : base,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: flashing
              ? (isTrapFlash ? Colors.redAccent : Colors.tealAccent)
              : Colors.white24,
          width: flashing ? 2.0 : 1.0,
        ),
        boxShadow: flashing
            ? [
                BoxShadow(
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 0),
                  color: (isTrapFlash ? Colors.redAccent : Colors.tealAccent)
                      .withOpacity(0.6),
                ),
              ]
            : null,
      ),
      child: IgnorePointer(
        ignoring: !enabled,
        child: const SizedBox.shrink(),
      ),
    );
  }
}

/// ================== CONTROLLER ==================
class GameController {
  GameController({
    required this.onLoseLife,
    required this.onScore,
    required this.onUnlockSecondRow,
    required this.onGrantExtraLifeOnce,
  });

  bool scalingEnabled = false;   // OFF: keep sequence at 3
  int baseSequenceLen = 3;
  int successesThisLevel = 0;
  int level = 1;

  int rows = 1;
  int cols = 5;
  bool trapsEnabled = false;

  List<TileRef> sequence = [];
  int inputIndex = 0;
  Set<TileRef> trapTiles = {};

  bool _extraLifeAlreadyGranted = false;

  final VoidCallback onLoseLife;
  final VoidCallback onScore;
  final VoidCallback onUnlockSecondRow;
  final VoidCallback onGrantExtraLifeOnce;

  Future<void> startNewRound({
    required Future<void> Function(TileRef tile, {required bool isTrap}) onFlash,
  }) async {
    inputIndex = 0;
    final length = scalingEnabled ? _computeSequenceLength() : baseSequenceLen;
    sequence = _generateSequence(length);
    trapTiles = trapsEnabled ? _pickTrapTilesForRound() : {};
    for (final t in sequence) {
      await onFlash(t, isTrap: trapTiles.contains(t));
    }
  }

  TapResult onTileTap(TileRef tapped) {
    if (trapsEnabled && trapTiles.contains(tapped)) {
      onLoseLife();
      return _endRound(failed: true);
    }
    final expected = _nextExpectedTileSkippingTraps();
    if (tapped == expected) {
      inputIndex++;
      if (_isRoundComplete()) {
        successesThisLevel++;
        onScore();
        _maybeUnlockRowAndExtras();
        return _endRound(failed: false);
      }
      return const TapResult(roundEnded: false);
    } else {
      onLoseLife();
      return _endRound(failed: true);
    }
  }

  int _computeSequenceLength() {
    final growth = (successesThisLevel ~/ 2);
    final cap = 10 + (rows - 1) * 3;
    return (baseSequenceLen + growth).clamp(3, cap);
    // with scalingEnabled=false we stay at 3
  }

  List<TileRef> _generateSequence(int length) {
    final rng = Random();
    final allTiles = _allVisibleTiles();
    return List.generate(length, (_) => allTiles[rng.nextInt(allTiles.length)]);
  }

  Set<TileRef> _pickTrapTilesForRound() {
    final rng = Random();
    final all = _allVisibleTiles();
    if (all.isEmpty) return {};
    final includeTrap = rng.nextDouble() < 0.4;
    return includeTrap ? {all[rng.nextInt(all.length)]} : {};
  }

  TileRef _nextExpectedTileSkippingTraps() {
    int i = inputIndex;
    while (i < sequence.length && trapTiles.contains(sequence[i])) {
      i++;
      inputIndex = i;
    }
    if (inputIndex >= sequence.length) return sequence.last;
    return sequence[inputIndex];
  }

  bool _isRoundComplete() => inputIndex >= sequence.length;

  TapResult _endRound({required bool failed}) {
    sequence = [];
    inputIndex = 0;
    trapTiles = {};
    return TapResult(roundEnded: true, failed: failed);
  }

  void _maybeUnlockRowAndExtras() {
    if (successesThisLevel % 3 == 0) {
      final before = rows;
      rows = (rows + 1).clamp(1, 6);
      if (before < 2 && rows >= 2) {
        trapsEnabled = true;
        onUnlockSecondRow();
        if (!_extraLifeAlreadyGranted) {
          _extraLifeAlreadyGranted = true;
          onGrantExtraLifeOnce();
        }
      }
    }
  }

  List<TileRef> _allVisibleTiles() => gridTilesFor(rows, cols);
}

/// ================== MODELS ==================
class TileRef {
  final int r, c;
  const TileRef(this.r, this.c);
  @override
  bool operator ==(Object o) => o is TileRef && o.r == r && o.c == c;
  @override
  int get hashCode => Object.hash(r, c);
}

List<TileRef> gridTilesFor(int rows, int cols) {
  final out = <TileRef>[];
  for (int r = 0; r < rows; r++) {
    for (int c = 0; c < cols; c++) {
      out.add(TileRef(r, c));
    }
  }
  return out;
}

class TapResult {
  final bool roundEnded;
  final bool failed;
  const TapResult({required this.roundEnded, this.failed = false});
}