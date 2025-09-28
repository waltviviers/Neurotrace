import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const NeuroTraceApp());
}

class NeuroTraceApp extends StatelessWidget {
  const NeuroTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEUROTRACE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E6A8),
          secondary: Color(0xFF00E6A8),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF111827),
          contentTextStyle: TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Game state
  int level = 1;
  int rows = 3;
  int cols = 3;
  int souls = 0;

  // Trace (lose at 100)
  double trace = 52; // percent

  // Timer
  static const int baseSeconds = 15;
  int secondsLeft = baseSeconds;
  Timer? _timer;

  late List<bool> tiles; // true = ON (green), false = OFF (dark)

  final rnd = Random();

  @override
  void initState() {
    super.initState();
    _startLevel(resetLevelNumber: false);

    // 🔸 Any context-dependent UI (e.g., SnackBar) is deferred until after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showToast("⚠️ TRACE DETECTED — stay alive & free souls!");
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---------------- UI helpers ----------------
  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(msg),
      ),
    );
  }

  // ---------------- Game logic ----------------
  void _startLevel({bool resetLevelNumber = false}) {
    _timer?.cancel();

    if (resetLevelNumber) {
      level = 1;
      rows = 3;
      cols = 3;
      souls = 0;
      trace = 52;
    }

    // Progressive difficulty
    final progression = level.clamp(1, 999);
    if (progression >= 3 && rows == 3 && cols < 5) cols = 5; // 3x5 early to fill space
    if (progression >= 5) rows = 4;
    if (progression >= 7) cols = 6;
    if (progression >= 9) rows = 5;

    // Allocate tiles and seed a solvable random board (not all same).
    final count = rows * cols;
    tiles = List<bool>.generate(count, (_) => rnd.nextBool());
    if (_allGreen() || _allRed()) {
      // Flip a random tile to ensure challenge.
      tiles[rnd.nextInt(count)] = !tiles[rnd.nextInt(count)];
    }

    // Timer scales with level; never below 8s.
    secondsLeft = max(8, baseSeconds + 4 - (level ~/ 2));

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        secondsLeft--;
        if (secondsLeft <= 0) {
          _applyTrace(12); // timeout hurts
          _showToast("⏱️ Timeout! Trace spiked +12%");
          _restartOrGameOver();
        }
      });
    });

    setState(() {});
  }

  void _restartOrGameOver() {
    if (trace >= 100) {
      _timer?.cancel();
      _showGameOver();
    } else {
      // soft fail -> reshuffle same level
      _startLevel();
    }
  }

  void _applyTrace(double delta) {
    trace = (trace + delta).clamp(0, 100);
  }

  bool _allGreen() => tiles.every((t) => t == true);
  bool _allRed() => tiles.every((t) => t == false);

  void _onTileTap(int index) {
    setState(() {
      _toggle(index);
      // Optional: also flip neighbors for “Lights Out” flavor.
      final r = index ~/ cols;
      final c = index % cols;
      final neighbors = <int>[
        _idx(r - 1, c),
        _idx(r + 1, c),
        _idx(r, c - 1),
        _idx(r, c + 1),
      ];
      for (final n in neighbors) {
        if (n != -1) _toggle(n);
      }

      // Penalty/bonus moment-to-moment (small)
      _applyTrace(tiles[index] ? -0.8 : 0.8);

      if (_allGreen()) {
        souls += max(1, 2 + level ~/ 2);
        level++;
        _applyTrace(-min(6, 2 + level ~/ 3)); // cool down trace a bit on win
        _showToast("✅ Souls freed: $souls  |  Trace -${min(6, 2 + level ~/ 3)}%");
        _startLevel();
      } else if (_allRed()) {
        _applyTrace(10);
        _showToast("🔥 System lock! Trace +10%");
        _restartOrGameOver();
      }
    });
  }

  int _idx(int r, int c) {
    if (r < 0 || c < 0 || r >= rows || c >= cols) return -1;
    return r * cols + c;
    }

  void _toggle(int i) => tiles[i] = !tiles[i];

  void _showGameOver() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('TRACE COMPLETE', style: TextStyle(color: Colors.white)),
        content: Text(
          "You were fried.\nSouls liberated: $souls\nLevel reached: $level",
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startLevel(resetLevelNumber: true);
            },
            child: const Text('REBOOT'),
          )
        ],
      ),
    );
  }

  // ---------------- Build ----------------
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final green = cs.primary;
    const darkTile = Color(0xFF1F2937);
    final glow = green.withOpacity(0.6);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + Souls
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'NEUROTRACE',
                      style: TextStyle(
                        fontSize: 28,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _badge(icon: Icons.favorite, label: 'Souls: $souls'),
                ],
              ),
              const SizedBox(height: 16),

              // HUD badges
              Row(
                children: [
                  _badge(
                    icon: Icons.bolt,
                    label: 'Trace ${trace.toStringAsFixed(0)}%',
                  ),
                  const SizedBox(width: 10),
                  _badge(
                    icon: Icons.layers,
                    label: 'Level $level (${rows}×$cols)',
                  ),
                  const SizedBox(width: 10),
                  _badge(
                    icon: Icons.timer,
                    label: '${secondsLeft}s',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Grid
              Expanded(
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    // make square-ish tiles that breathe inside available space
                    final pad = 10.0;
                    final w = (constraints.maxWidth - pad * (cols - 1)) / cols;
                    final h = (constraints.maxHeight - pad * (rows - 1)) / rows;
                    final size = min(w, h);

                    return Center(
                      child: SizedBox(
                        width: cols * size + (cols - 1) * pad,
                        height: rows * size + (rows - 1) * pad,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            crossAxisSpacing: pad,
                            mainAxisSpacing: pad,
                          ),
                          itemCount: tiles.length,
                          itemBuilder: (_, i) {
                            final on = tiles[i];
                            return GestureDetector(
                              onTap: () => _onTileTap(i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 120),
                                decoration: BoxDecoration(
                                  color: on ? green : darkTile,
                                  borderRadius: BorderRadius.circular(22),
                                  boxShadow: on
                                      ? [
                                          BoxShadow(
                                            color: glow,
                                            blurRadius: 28,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : const [],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              letterSpacing: 0.3,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
