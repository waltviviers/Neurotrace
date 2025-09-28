import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() => runApp(const NeuroTraceApp());

class NeuroTraceApp extends StatelessWidget {
  const NeuroTraceApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEUROTRACE',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0E1116),
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5A8),
          secondary: Color(0xFF00E5A8),
          surface: Color(0xFF12161D),
        ),
      ),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Grid config
  static const int rows = 3;
  static const int cols = 5;
  static const int tileCount = rows * cols;

  // Game state
  late List<bool> lit; // true = green, false = off (dark)
  int level = 1;
  int souls = 0;

  // Timers & meters
  late double timeRemaining; // seconds
  late double timeStart;     // seconds for the level
  late double trace;         // 0..100
  late double traceRate;     // % per second
  Timer? loop;

  // Feedback
  bool shock = false; // brief red flash on fail
  final rng = Random();

  // Taunts
  final List<String> taunts = const [
    "AI: Your intrusion is quaint.",
    "AI: Every second you delay, another mind is digested.",
    "AI: You cannot free them all, meatspace.",
    "AI: Your entropy pleases statistical models.",
    "AI: Die loudly. My sensors enjoy it.",
  ];

  @override
  void initState() {
    super.initState();
    _startRun();
  }

  @override
  void dispose() {
    loop?.cancel();
    super.dispose();
  }

  // ---- Game lifecycle ----
  void _startRun() {
    level = 1;
    souls = 0;
    trace = 15;                // start under pressure
    traceRate = 2.0;           // %/sec
    timeStart = 20;            // seconds
    timeRemaining = timeStart;
    lit = List<bool>.filled(tileCount, false);

    loop?.cancel();
    loop = Timer.periodic(const Duration(milliseconds: 120), _tick);
    _randomizeStart(); // give some greens so it looks alive
    setState(() {});
    _showBanner("TRACE DETECTED — RUN!");
  }

  void _nextLevel() {
    souls += level;                // reward
    level += 1;

    // progression ramps
    timeStart = max(8, 20 - level * 1.2);
    timeRemaining = timeStart;
    trace = max(0, trace - 20);    // brief relief
    traceRate = min(7, 2.0 + level * 0.6);

    // fresh board with a few lights on to tease
    lit = List<bool>.filled(tileCount, false);
    _randomizeStart();

    _taunt();
    setState(() {});
  }

  void _gameOver(String reason) async {
    loop?.cancel();
    setState(() => shock = true);
    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() => shock = false);

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141922),
        contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        title: const Text("TRACE COMPLETE", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(reason,
                style: TextStyle(color: Colors.white.withOpacity(0.8))),
            const SizedBox(height: 12),
            Text("Souls liberated: $souls",
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Reset"),
          )
        ],
      ),
    );

    if (!mounted) return;
    _startRun();
  }

  void _tick(Timer t) {
    // Time flows
    timeRemaining -= 0.12;
    trace += traceRate * 0.12;

    // Lose conditions
    if (timeRemaining <= 0) {
      _gameOver("You stalled until your cortex lit the sky.");
      return;
    }
    if (trace >= 100) {
      _gameOver("The AI triangulated your signal.");
      return;
    }
    if (_allRed()) {
      _gameOver("Your logic collapsed to zero state.");
      return;
    }

    setState(() {});
  }

  // ---- Mechanics ----
  bool _allGreen() => lit.every((v) => v);
  bool _allRed() => lit.every((v) => !v);

  void _randomizeStart() {
    // Start with a solvable-ish tease: ~30% green
    for (int i = 0; i < tileCount; i++) {
      lit[i] = rng.nextDouble() < 0.3;
    }
  }

  void _toggleAt(int r, int c) {
    if (r < 0 || c < 0 || r >= rows || c >= cols) return;
    final idx = r * cols + c;
    lit[idx] = !lit[idx];
  }

  void _onTapTile(int index) {
    final r = index ~/ cols;
    final c = index % cols;

    // Always flip self
    _toggleAt(r, c);

    // Chance to flip neighbours grows with level (adds depth)
    final neighbourChance = min(0.15 + level * 0.06, 0.85);
    if (rng.nextDouble() < neighbourChance) {
      _toggleAt(r - 1, c);
      _toggleAt(r + 1, c);
      _toggleAt(r, c - 1);
      _toggleAt(r, c + 1);
    }

    // Small random glitch: flip a random tile sometimes
    if (rng.nextDouble() < min(0.05 + level * 0.01, 0.15)) {
      final randIdx = rng.nextInt(tileCount);
      if (randIdx != index) {
        _onTapTile(randIdx); // recursive once to reuse logic (safe given low prob)
      }
    }

    // Reward tactical play: slight trace drop on successful tap that increases greens
    final greensBefore = lit.where((v) => v).length;
    // (We already flipped; compute after)
    final greensNow = lit.where((v) => v).length;
    if (greensNow > greensBefore) {
      trace = max(0, trace - 0.7);
    }

    setState(() {});

    if (_allGreen()) {
      _showBanner("+${level} souls freed");
      _nextLevel();
    }
  }

  // ---- UI helpers ----
  void _showBanner(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(milliseconds: 1200),
          backgroundColor: const Color(0xFF0E1116).withOpacity(0.95),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  void _taunt() {
    _showBanner(taunts[rng.nextInt(taunts.length)]);
  }

  // ---- Building blocks ----
  Color get _bg => const Color(0xFF0E1116);
  Color get _panel => const Color(0xFF131922);
  Color get _tileOff => const Color(0x22222A36);
  Color get _tileOffEdge => const Color(0xFF222A36);
  Color get _tileOn => const Color(0xFF00E5A8);
  Color get _tileOnGlow => const Color(0x8800E5A8);
  Color get _alert => const Color(0xFFFF3D3D);

  Widget _metricChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tileSize = min(width, 440) / cols - 12; // fit nicely with gaps
    final greens = lit.where((v) => v).length;

    return Stack(
      children: [
        // subtle shock overlay
        AnimatedOpacity(
          opacity: shock ? 0.35 : 0,
          duration: const Duration(milliseconds: 120),
          child: Container(color: _alert),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Text(
                      "NEUROTRACE",
                      style: TextStyle(fontSize: 26, letterSpacing: 1.5, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    Text("Souls: $souls", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 14),

                // Top metrics
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _metricChip(
                      icon: Icons.shutter_speed_rounded,
                      label: "Trace ${trace.clamp(0, 100).toStringAsFixed(0)}%",
                    ),
                    _metricChip(
                      icon: Icons.layers_rounded,
                      label: "Level $level (${rows}×$cols)",
                    ),
                    _metricChip(
                      icon: Icons.timer_rounded,
                      label: "${timeRemaining.clamp(0, 999).toStringAsFixed(0)}s",
                    ),
                    _metricChip(
                      icon: Icons.grid_on_rounded,
                      label: "$greens/$tileCount green",
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Grid
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _panel,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white10),
                        boxShadow: const [BoxShadow(blurRadius: 40, color: Colors.black54)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(rows, (r) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(cols, (c) {
                              final idx = r * cols + c;
                              final isOn = lit[idx];
                              return Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: GestureDetector(
                                  onTap: () => _onTapTile(idx),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 140),
                                    curve: Curves.easeOut,
                                    width: tileSize,
                                    height: tileSize,
                                    decoration: BoxDecoration(
                                      color: isOn ? _tileOn : _tileOff,
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: isOn ? Colors.white12 : _tileOffEdge,
                                        width: 1.2,
                                      ),
                                      boxShadow: isOn
                                          ? [
                                              BoxShadow(blurRadius: 28, spreadRadius: 2, color: _tileOnGlow),
                                              BoxShadow(blurRadius: 8, spreadRadius: -2, color: _tileOn),
                                            ]
                                          : [
                                              const BoxShadow(blurRadius: 12, spreadRadius: 0, color: Colors.black45),
                                            ],
                                      gradient: isOn
                                          ? const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [Color(0xFF00F0B6), Color(0xFF00C893)],
                                            )
                                          : const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [Color(0xFF1B2230), Color(0xFF161C27)],
                                            ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          );
                        }),
                      ),
                    ),
                  ),
                ),

                // Bottom controls
                const SizedBox(height: 10),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _startRun,
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: const Text("RESET RUN"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _panel,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => _showBanner("Tip: neighbour flips increase with level — plan chains."),
                      child: const Text("hint"),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
