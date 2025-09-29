import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ✅ Lock orientation to portrait
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

/// ---------------------- SPLASH (glitch) ----------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Timer _navTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = Tween(begin: 0.92, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();

    _navTimer = Timer(const Duration(milliseconds: 1900), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const GameScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _navTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _ScanlinePainter())),
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
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: NeuroTheme.bg,
                          child: const Center(
                            child: Icon(Icons.bolt, color: Colors.white54, size: 60),
                          ),
                        ),
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
                  const _GlitchText(
                    baseText: 'TRACE DETECTED',
                    altText: 'SIGNAL LOCK INBOUND',
                    duration: Duration(milliseconds: 1200),
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

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.04)..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlitchText extends StatefulWidget {
  final String baseText;
  final String altText;
  final Duration duration;
  const _GlitchText({required this.baseText, required this.altText, required this.duration});
  @override
  State<_GlitchText> createState() => _GlitchTextState();
}
class _GlitchTextState extends State<_GlitchText> {
  late Timer _t; late DateTime _start; final _rng = Random();
  String _txt = ''; double _jx = 0, _jy = 0, _op = 1;
  @override void initState() {
    super.initState(); _start = DateTime.now(); _txt = widget.baseText;
    _t = Timer.periodic(const Duration(milliseconds: 60), _tick);
  }
  void _tick(Timer _) {
    final elapsed = DateTime.now().difference(_start);
    if (elapsed > widget.duration) { setState(() { _txt = widget.baseText; _jx = 0; _jy = 0; _op = 1; }); _t.cancel(); return; }
    final useAlt = _rng.nextDouble() < 0.18; final src = useAlt ? widget.altText : widget.baseText;
    final chars = src.split(''); for (int i=0;i<2;i++){ final pos=_rng.nextInt(chars.length); chars[pos] = _g(); }
    setState(() { _txt = chars.join(); _jx = (_rng.nextDouble()-0.5)*2; _jy = (_rng.nextDouble()-0.5)*1.5; _op = 0.85+_rng.nextDouble()*0.15; });
  }
  String _g(){ const g=r'█▓▒░#%*@/+=-<>|[]{}()'; return g[Random().nextInt(g.length)]; }
  @override void dispose(){ _t.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineSmall!;
    return Opacity(
      opacity: _op,
      child: Stack(alignment: Alignment.center, children: [
        Transform.translate(offset: Offset(_jx-1.2,_jy),
          child: Text(_txt, style: style.copyWith(color: NeuroTheme.teal.withOpacity(0.8)))),
        Transform.translate(offset: Offset(_jx+1.2,_jy),
          child: Text(_txt, style: style.copyWith(color: NeuroTheme.amber.withOpacity(0.8)))),
        Transform.translate(offset: Offset(_jx,_jy),
          child: Text(_txt, style: style.copyWith(color: Colors.white))),
      ]),
    );
  }
}

/// ---------------------- GAME (Simon-style 3×5) ----------------------
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
  Set<int> _lit = {};          // green flash
  Set<int> _wrongLit = {};     // red flash (❌ when wrong)
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
    setState(() { _showingSequence = true; _lit.clear(); _wrongLit.clear(); });
    await Future.delayed(const Duration(milliseconds: 400));

    // Speed up as it grows
    final onMs = max(220, 560 - _sequence.length * 25);
    for (final idx in _sequence) {
      setState(() { _lit = {idx}; _wrongLit.clear(); });
      await Future.delayed(Duration(milliseconds: onMs));
      setState(() => _lit.clear());
      await Future.delayed(const Duration(milliseconds: 180));
    }

    setState(() => _showingSequence = false);
  }

  void _onTileTap(int index) {
    if (_showingSequence) return;

    final correct = _sequence[_inputIndex] == index;

    // brief feedback on tap (green or red handled below)
    if (correct) {
      setState(() => _lit = {index});
      Future.delayed(const Duration(milliseconds: 140),
          () => mounted ? setState(() => _lit.clear()) : null);
    }

    if (!correct) {
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

  /// 🔴 Flash the tapped tile red a couple of times, then continue.
  Future<void> _flashWrong(int index) async {
    setState(() { _wrongLit = {index}; _lit.clear(); });
    await Future.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    setState(() => _wrongLit.clear());
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() => _wrongLit = {index});
    await Future.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    setState(() => _wrongLit.clear());
  }

  Future<void> _gameOver() async {
    setState(() => _showingSequence = true);
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: NeuroTheme.panel,
        title:
            const Text('TRACE LOCKED', style: TextStyle(fontWeight: FontWeight.w800)),
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
    final pad = 16.0;

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
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            children: [
              _chip(Icons.visibility, _showingSequence ? 'Watch' : 'Your turn'),
              _chip(Icons.layers, 'Round $_round'),
              _chip(Icons.star, 'Best $_best'),
            ],
          ),
          const SizedBox(height: 10),
          // Grid fills portrait nicely
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12),
              child: LayoutBuilder(
                builder: (context, c) {
                  final gap = 12.0;
                  final totalGapW = (cols - 1) * gap;
                  final size = ((c.maxWidth - totalGapW) / cols).clamp(44, 160);
                  final gridH = size * rows + gap * (rows - 1);

                  return Center(
                    child: SizedBox(
                      width: size * cols + totalGapW,
                      height: gridH,
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: gap,
                          mainAxisSpacing: gap,
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
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
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
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: NeuroTheme.amber),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// ---------------------- TILE ----------------------
class _Tile extends StatelessWidget {
  final bool on;        // green lit (sequence/confirm)
  final bool wrong;     // red flash when incorrect
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