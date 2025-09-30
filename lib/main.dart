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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1114),
        fontFamily: 'Roboto',
      ),
      debugShowCheckedModeBanner: false,
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
  // --- Tunables ---
  static const int startRows = 1;
  static const int maxRows = 5; // cap growth
  static const int cols = 5;
  static const int startingLives = 2;
  static const Duration flashOn = Duration(milliseconds: 450);
  static const Duration flashGap = Duration(milliseconds: 200);
  static const double trapChanceBase = 0.18; // 18% per step once traps enabled
  static const double trapChanceGrowth = 0.02; // tiny bump each added row

  // --- Colors (NT palette) ---
  static const Color teal = Color(0xFF22D3EE);
  static const Color amber = Color(0xFFF59E0B);
  static const Color tileOff = Color(0xFF1B242A);
  static const Color tileOn = Color(0xFF28E1B9);
  static const Color tileTrap = Color(0xFFE11D48); // red
  static const Color glow = Color(0xFF00FFC3);

  // --- State ---
  int rows = startRows;
  int lives = startingLives;
  int souls = 0;

  int level = 1; // round length grows with level
  int correctSoFar = 0;
  int roundsSinceRowUp = 0;

  List<int> pattern = [];
  Set<int> traps = {}; // indices that flashed red in current pattern

  bool isShowing = false;
  bool inputOpen = false;

  // visual feedback
  int? litIndex; // tile currently lit for playback
  Set<int> pressed = {}; // user press highlight
  bool wrongFlash = false;

  final rnd = Random();

  @override
  void initState() {
    super.initState();
    _startNewRun();
  }

  void _startNewRun() {
    rows = startRows;
    lives = startingLives;
    souls = 0;
    level = 1;
    roundsSinceRowUp = 0;
    _nextRound();
  }

  int get gridCount => rows * cols;

  // Determine if traps are active: after we've revealed the 2nd row once.
  bool get trapsEnabled => rows >= 2 && lives > startingLives - 1;

  Future<void> _nextRound() async {
    setState(() {
      correctSoFar = 0;
      litIndex = null;
      pressed.clear();
      wrongFlash = false;
      inputOpen = false;
      traps.clear();
    });

    // Create a new pattern with current length = min(level+2, gridCount)
    final length = min(level + 2, gridCount);
    pattern = List<int>.generate(length, (_) => rnd.nextInt(gridCount));

    await _playSequence();

    setState(() {
      inputOpen = true;
      correctSoFar = 0;
    });
  }

  Future<void> _playSequence() async {
    isShowing = true;
    inputOpen = false;
    traps.clear();

    final trapChance =
        trapsEnabled ? (trapChanceBase + (rows - 2) * trapChanceGrowth) : 0.0;

    for (int i = 0; i < pattern.length; i++) {
      final idx = pattern[i];

      // Decide if this step is a trap (only if traps are enabled and not same index twice in a row)
      final bool isTrap = trapsEnabled && rnd.nextDouble() < trapChance;

      setState(() {
        litIndex = idx;
        if (isTrap) traps.add(idx);
      });

      await Future.delayed(flashOn);

      setState(() => litIndex = null);
      await Future.delayed(flashGap);
    }

    isShowing = false;
  }

  Future<void> _onTileTap(int index) async {
    if (!inputOpen || wrongFlash) return;

    // Trap tapped? immediate penalty & round fail
    if (traps.contains(index)) {
      await _loseLifeWithFlash(index);
      return;
    }

    setState(() => pressed.add(index));
    await Future.delayed(const Duration(milliseconds: 120));
    setState(() => pressed.remove(index));

    // Must match expected step, skipping traps (which aren't in the expected order)
    if (index == pattern[correctSoFar]) {
      correctSoFar++;
      if (correctSoFar >= pattern.length) {
        // Round cleared
        souls++; // you freed another soul
        level++;
        roundsSinceRowUp++;

        // Every 3 cleared rounds -> add a row (and one-time bonus when reaching 2 rows)
        if (roundsSinceRowUp >= 3 && rows < maxRows) {
          roundsSinceRowUp = 0;
          rows++;
          if (rows == 2) {
            // “Second row revealed” bonus life
            lives++;
          }
        }
        await _celebrateAndContinue();
      }
    } else {
      await _loseLifeWithFlash(index);
    }
  }

  Future<void> _celebrateAndContinue() async {
    setState(() {
      inputOpen = false;
      litIndex = null;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    _nextRound();
  }

  Future<void> _loseLifeWithFlash(int index) async {
    setState(() {
      wrongFlash = true;
      pressed.add(index);
    });
    await Future.delayed(const Duration(milliseconds: 220));
    setState(() {
      pressed.remove(index);
    });

    lives--;
    if (lives <= 0) {
      // Game over -> restart run after a short beat
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      _startNewRun();
      return;
    }

    // retry same level
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    _nextRound();
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // background image (PNG)
        Positioned.fill(
          child: Image.asset(
            'assets/bg_circuits.png',
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.10),
            colorBlendMode: BlendMode.darken,
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                _buildChips(),
                const SizedBox(height: 8),
                Expanded(child: _buildGrid()),
                _buildBottomBar(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          Image.asset('assets/logo.png', height: 24),
          const SizedBox(width: 8),
          Expanded(
            child: ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                colors: [teal, amber],
              ).createShader(r),
              child: const Text(
                'NEUROTRACE',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.favorite, size: 18, color: Colors.white70),
          const SizedBox(width: 4),
          Text('Souls: $souls',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildChips() {
    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _HudChip(icon: Icons.memory, label: 'Level $level'),
            const SizedBox(width: 8),
            _HudChip(icon: Icons.grid_3x3, label: 'Grid ${rows}×$cols'),
            const SizedBox(width: 8),
            _HudChip(
              icon: Icons.warning_amber_rounded,
              label: trapsEnabled ? 'Traps ON' : 'Traps OFF',
              tint: trapsEnabled ? amber : Colors.white70,
            ),
            const SizedBox(width: 8),
            _HudChip(
              icon: Icons.favorite_rounded,
              label: 'Lives $lives',
              tint: lives > 1 ? Colors.white70 : tileTrap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    final double sidePadding = 16;
    final size = MediaQuery.of(context).size;
    final availableWidth = size.width - sidePadding * 2;

    // portrait-friendly square tiles with spacing
    const spacing = 12.0;
    final tileSize = (availableWidth - (cols - 1) * spacing) / cols;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sidePadding, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(rows, (r) {
          return Padding(
            padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : spacing),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(cols, (c) {
                final index = r * cols + c;
                return Padding(
                  padding: EdgeInsets.only(right: c == cols - 1 ? 0 : spacing),
                  child: _Tile(
                    size: tileSize,
                    on: litIndex == index,
                    pressed: pressed.contains(index),
                    isTrapFlash: litIndex == index && traps.contains(index),
                    showTrapRing: trapsEnabled,
                    onTap: () => _onTileTap(index),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.06),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: isShowing ? null : () => _startNewRun(),
            icon: const Icon(Icons.refresh),
            label: const Text('New Run'),
          ),
        ),
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? tint;
  const _HudChip({required this.icon, required this.label, this.tint});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: tint ?? Colors.white70),
          const SizedBox(width: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              )),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final double size;
  final bool on;
  final bool pressed;
  final bool isTrapFlash;
  final bool showTrapRing;
  final VoidCallback onTap;

  const _Tile({
    super.key,
    required this.size,
    required this.on,
    required this.pressed,
    required this.isTrapFlash,
    required this.showTrapRing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color baseColor = isTrapFlash
        ? _GameScreenState.tileTrap
        : (on || pressed ? _GameScreenState.tileOn : _GameScreenState.tileOff);

    final List<BoxShadow> shadow = (on || pressed || isTrapFlash)
        ? [
            BoxShadow(
              color: (isTrapFlash
                      ? _GameScreenState.tileTrap
                      : _GameScreenState.glow)
                  .withOpacity(0.55),
              blurRadius: 24,
              spreadRadius: 1,
            ),
          ]
        : [];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: shadow,
          border: showTrapRing && isTrapFlash
              ? Border.all(
                  color: _GameScreenState.tileTrap.withOpacity(0.9), width: 3)
              : null,
        ),
      ),
    );
  }
}