import 'package:flutter/material.dart';

void main() {
  runApp(const NeurohackApp());
}

class NeurohackApp extends StatelessWidget {
  const NeurohackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neurohack',
      theme: ThemeData.dark(useMaterial3: true),
      home: const NeurohackHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class NeurohackHome extends StatefulWidget {
  const NeurohackHome({super.key});

  @override
  State<NeurohackHome> createState() => _NeurohackHomeState();
}

class _NeurohackHomeState extends State<NeurohackHome>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity; // <- double animation target
  bool _toggled = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // CHANGED: explicit double tween. Using 0.0 and 1.0 avoids int inference.
    _opacity = Tween<double>(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_controller);

    // Start once so there’s something to see.
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _toggled = !_toggled);
    if (_toggled) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F13),
      appBar: AppBar(
        title: const Text('Neurohack (debug build)'),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: FadeTransition(
          opacity: _opacity, // <- expects Animation<double>
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF121821),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1C2A3A)),
            ),
            child: const Text(
              'Engram Uplink Ready',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggle,
        label: const Text('Toggle'),
        icon: const Icon(Icons.bolt),
      ),
    );
  }
}
