import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
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
      headlineSmall:
          TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white70),
      bodyMedium: TextStyle(fontSize: 14, color: Colors.white70),
    ),
    useMaterial3: true,
  );
}

/// ---------------------- PARALLAX BACKGROUND ----------------------
class NeuroBg extends StatefulWidget {
  const NeuroBg({super.key, this.trigger});
  /// Increment this notifier to make the background drift & ease back.
  final ValueNotifier<int>? trigger;

  @override
  State<NeuroBg> createState() => _NeuroBgState();
}

class _NeuroBgState extends State<NeuroBg> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _anim;
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
    _anim = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    widget.trigger?.addListener(_nudge);
  }

  void _nudge() {
    final dx = (_rng.nextDouble() - 0.5) * 24; // pixels to drift
    final dy = (_rng.nextDouble() - 0.5) * 24;
    _anim = Tween<Offset>(begin: Offset(dx, dy), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    widget.trigger?.removeListener(_nudge);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        return Stack(children: [
          Positioned.fill(
            child: Transform.translate(
              offset: _anim.value,
              child: Image.asset(
                'assets/bg_circuit.png',
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.55),
                colorBlendMode: BlendMode.darken,
              ),
            ),
          ),
          // Soft vertical vignette
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.14),
                    Colors.transparent,
                    Colors.black.withOpacity(0.22),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }
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

/// ---------------------- SPLASH (with parallax) ----------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scale;
  late final Timer _navTimer;

  // Background parallax trigger: gently pulse + a couple of stronger nudges
  final ValueNotifier<int> _bgTrigger = ValueNotifier<int>(0);
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _scale = Tween(begin: 0.92, end: 1.0)
        .animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutCubic));
    _scaleCtrl.forward();

    // Subtle repeating pulse to the background
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _bgTrigger.value++; // nudge
          _pulseCtrl.reverse();
        } else if (s == AnimationStatus.dismissed) {
          _pulseCtrl.forward();
        }
      });
    _pulseCtrl.forward();

    _navTimer = Timer(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GameScreen()),
      );
    });

    // A couple of extra nudges for a lively first impression
    Future.delayed(const Duration(milliseconds: 300), () => _bgTrigger.value++);
    Future.delayed(const Duration(milliseconds: 900), () => _bgTrigger.value++);
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _pulseCtrl.dispose();
    _navTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Stack(
        children: [
          NeuroBg(trigger: _bgTrigger),
          Center(
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: min(180, w * 0.45),
                    height: min(180, w * 0.45),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: NeuroTheme.brandGradient(),
                      boxShadow: NeuroTheme.shadowGlow,
                    ),
                    padding: const EdgeInsets.all(14),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset('assets/logo.png', fit: BoxFit.cover),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------- GAME (memory: Simon-like) ----------------------
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
  Set<int> _wrongLit = {};
  int _round = 0;
  int _best = 0;

  bool _screenFlash = false;

  final ValueNotifier<int> _bgTrigger = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _nudgeBackground() {
    _bgTrigger.value++;
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
    setState(() { _showingSequence = true; _lit.clear(); _wrongLit.clear(); });
    await Future.delayed(const Duration(milliseconds: 400));

    final onMs = max(220, 560 - _sequence.length * 25);
    for (final idx in _sequence) {
      _nudgeBackground();
      setState(() { _lit = {idx}; _wrongLit.clear(); });
      await Future.delayed(Duration(milliseconds: onMs));
      setState(() => _lit.clear());
      await Future.delayed(const Duration(milliseconds: 180));
    }

    setState(() => _showingSequence = false);
  }

  void _onTileTap(int index) {
    if (_showingSequence) return;
    _nudgeBackground();

    final correct = _sequence[_inputIndex] == index;

    if (correct) {
      setState(() => _lit = {index});
      Future.delayed(const Duration(milliseconds: 140),
          () => mounted ? setState(() => _lit.clear()) : null);
    } else {
      _flashWrong(index).then((_) {
        _best = max(_best, _round - 1);
        _gameOver();
      });
      return;
    }

    _inputIndex += 1;
    if (_inputIndex >= _sequence.length) {
      _nextRound();
    }
  }

  Future<void> _flashWrong(int index) async {
    setState(() { _wrongLit = {index}; _lit.clear(); _screenFlash = true; });
    _nudgeBackground();
    await Future.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    setState(() { _wrongLit.clear(); _screenFlash = false; });
  }

  Future<void> _gameOver() async {
    setState(() => _showingSequence = true);
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: NeuroTheme.panel,
        title: const Text('TRACE LOCKED', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('You matched ${max(0, _round - 1)} rounds.\nBest: $_best',
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
      body: Stack(children: [
        NeuroBg(trigger: _bgTrigger),
        Column(
          children: [
            const SizedBox(height: 56),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Expanded(
                    child: ShaderMask(
                      shaderCallback: (r) =>
                          NeuroTheme.brandGradient().createShader(r),
                      child: const Text('NEUROTRACE',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                  ),
                  Text('Best $_best',
                      style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: gridSize,
                itemBuilder: (context, i) {
                  final isOn = _lit.contains(i);
                  final isWrong = _wrongLit.contains(i);
                  return _Tile(
                    on: isOn,
                    wrong: isWrong,
                    disabled: _showingSequence,
                    onTap: () => _onTileTap(i),
                  );
                },
              ),
            ),
          ],
        ),
        // screen flash on error
        IgnorePointer(
          ignoring: true,
          child: AnimatedOpacity(
            opacity: _screenFlash ? 0.18 : 0.0,
            duration: const Duration(milliseconds: 100),
            child: Container(color: NeuroTheme.error),
          ),
        ),
      ]),
    );
  }
}

/// ---------------------- TILE ----------------------
class _Tile extends StatelessWidget {
  final bool on;
  final bool wrong;
  final bool disabled;
  final VoidCallback onTap;

  const _Tile({
    required this.on,
    required this.wrong,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = wrong
        ? NeuroTheme.error
        : (on ? NeuroTheme.tileOn : NeuroTheme.tileOff);

    final shadow = wrong
        ? const [BoxShadow(color: Color(0x66FF4D4D), blurRadius: 26, spreadRadius: 2)]
        : (on
            ? const [BoxShadow(color: Color(0x4022E5B2), blurRadius: 24, spreadRadius: 2)]
            : const []);

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: shadow,
        ),
      ),
    );
  }
}