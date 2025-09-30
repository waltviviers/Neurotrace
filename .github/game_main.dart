import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const NeuroTraceApp());

class NeuroTraceApp extends StatelessWidget {
  const NeuroTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// GAME SCREEN (UI + controller wiring)
/// ─────────────────────────────────────────────────────────────────────────────
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameController game;

  // UI runtime
  TileRef? flashing;            // which tile is currently flashing during playback
  bool isPlayingBack = false;   // true while showing the sequence
  bool inputOpen = false;       // true when user can tap tiles

  // simple lives/score HUD
  int lives = 3;
  int score = 0;
  bool pulseLives = false;      // small animation flag when life is granted

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
      onUnlockSecondRow: () {
        // hook for sfx/animation if you want when row 2 unlocks
      },
      onGrantExtraLifeOnce: () {
        // +1 life exactly once; pulse the HUD briefly
        setState(() {
          lives = (lives + 1).clamp(0, 99);
          pulseLives = true;
        });
        // optional toast/snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Extra life awarded!')),
        );
        Timer(const Duration(milliseconds: 450), () {
          if (mounted) setState(() => pulseLives = false);
        });
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
      // flash each tile with a quick highlight; traps flash red tint
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
          // --- Background ---
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_texture.png',
              fit: BoxFit.cover,
            ),
          ),

          // --- Optional darken overlay for readability ---
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.35))),

          // --- Foreground content ---
          SafeArea(
            child: Column(
              children: [
                // HUD
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _hudChip(Icons.favorite, 'Lives', '$lives', pulse: pulseLives),
                      const SizedBox(width: 12),
                      _hudChip(Icons.auto_awesome, 'Score', '$score'),
                      const Spacer(),
                      _hudChip(Icons.grid_view, 'Rows', '${game.rows}'),
                    ],
                  ),
                ),

                // Grid
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

                // CTA
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

  Widget _hudChip(IconData icon, String label, String value, {bool pulse = false}) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value),
        ],
      ),
    );

    return AnimatedScale(
      scale: pulse ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: chip,
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// TILE WIDGET
/// ─────────────────────────────────────────────────────────────────────────────
class Tile extends StatelessWidget {
  final double size;
  final bool flashing;
  final bool isTrapFlash; // red tint during playback if a trap
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

/// ─────────────────────────────────────────────────────────────────────────────
/// CONTROLLER (fixed 3-flash now; scalable later)
/// ─────────────────────────────────────────────────────────────────────────────
class GameController {
  GameController({
    required this.onLoseLife,
    required this.onScore,
    required this.onUnlockSecondRow,
    required this.onGrantExtraLifeOnce,
  });

  // ---- Config toggles ----
  bool scalingEnabled = false;   // OFF: keep sequence at 3
  int baseSequenceLen = 3;       // requirement now
  int successesThisLevel = 0;    // successful rounds completed
  int level = 1;

  // ---- Grid / rows ----
  int rows = 1;                  // start at 1 row
  int cols = 5;
  bool trapsEnabled = false;     // becomes true once rows >= 2

  // ---- Round state ----
  List<TileRef> sequence = [];
  int inputIndex = 0;
  Set<TileRef> trapTiles = {};

  // ---- One-shot flags ----
  bool _extraLifeAlreadyGranted = false; // ensures single grant on first 2nd-row unlock

  // ---- Callbacks to UI/HUD ----
  final VoidCallback onLoseLife;
  final VoidCallback onScore;
  final VoidCallback onUnlockSecondRow;
  final VoidCallback onGrantExtraLifeOnce;

  // For UI:
  bool get canTap => sequence.isNotEmpty && inputIndex < sequence.length;

  // Lifecycle
  Future<void> startNewRound({
    required Future<void> Function(TileRef tile, {required bool isTrap}) onFlash,
  }) async {
    inputIndex = 0;

    final length = scalingEnabled ? _computeSequenceLength() : baseSequenceLen;
    sequence = _generateSequence(length);

    trapTiles = trapsEnabled ? _pickTrapTilesForRound() : {};

    // Playback
    for (final t in sequence) {
      final isTrap = trapTiles.contains(t);
      await onFlash(t, isTrap: isTrap);
    }
  }

  // Called from UI when a tile is tapped
  TapResult onTileTap(TileRef tapped) {
    // Trap instant fail
    if (trapsEnabled && trapTiles.contains(tapped)) {
      onLoseLife();
      return _endRound(failed: true);
    }

    // Skip over traps in the sequence (player should never tap them)
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

  // ---------- Helpers ----------
  int _computeSequenceLength() {
    final growth = (successesThisLevel ~/ 2);
    final cap = 10 + (rows - 1) * 3;
    return (baseSequenceLen + growth).clamp(3, cap);
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
    final includeTrap = rng.nextDouble() < 0.4; // ~40% of rounds have 1 trap
    return includeTrap ? {all[rng.nextInt(all.length)]} : {};
  }

  TileRef _nextExpectedTileSkippingTraps() {
    int i = inputIndex;
    while (i < sequence.length && trapTiles.contains(sequence[i])) {
      i++;
      inputIndex = i; // auto-skip trap entries
    }
    if (inputIndex >= sequence.length) {
      return sequence.last;
    }
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
    // Every 3 successes -> add a row
    if (successesThisLevel % 3 == 0) {
      final before = rows;
      rows = (rows + 1).clamp(1, 6);

      // First time we cross into 2+ rows
      if (before < 2 && rows >= 2) {
        trapsEnabled = true;
        onUnlockSecondRow();

        // Grant exactly one extra life the first time row 2 appears
        if (!_extraLifeAlreadyGranted) {
          _extraLifeAlreadyGranted = true;
          onGrantExtraLifeOnce();
        }
      }
    }
  }

  List<TileRef> _allVisibleTiles() => gridTilesFor(rows, cols);
}

/// ─────────────────────────────────────────────────────────────────────────────
/// MODELS / HELPERS
/// ─────────────────────────────────────────────────────────────────────────────
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