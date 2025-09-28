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
      debugShowCheckedModeBanner: false,
      title: 'NeuroTrace',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E6A8),
          secondary: Color(0xFFFF0099),
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
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
  // simple 3x3 grid; tap toggles "lit" state
  static const int gridSide = 3;
  late List<bool> lit;

  @override
  void initState() {
    super.initState();
    lit = List<bool>.filled(gridSide * gridSide, false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NeuroTrace – prototype'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          const Text(
            'Tap tiles to toggle. You should SEE colors.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: GridView.builder(
                  itemCount: lit.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridSide,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) => GestureDetector(
                    onTap: () => setState(() => lit[index] = !lit[index]),
                    child: _Tile(lit: lit[index]),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final bool lit;

  // Visible neon-ish colors so a blank screen is impossible to miss
  final Color _highlightColor = const Color(0xFF00E6A8);
  final Color _baseColor = const Color(0xFF1E2A39);

  const _Tile({super.key, this.lit = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: lit ? _highlightColor.withOpacity(0.9) : _baseColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (lit)
            BoxShadow(
              color: _highlightColor.withOpacity(0.6),
              blurRadius: 12,
              spreadRadius: 2,
            ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
    );
  }
}
