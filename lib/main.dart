import 'package:flutter/material.dart';

void main() {
  runApp(const NeuroTraceApp());
}

class NeuroTraceApp extends StatelessWidget {
  const NeuroTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const NeuroTraceGame(),
    );
  }
}

class NeuroTraceGame extends StatefulWidget {
  const NeuroTraceGame({super.key});

  @override
  State<NeuroTraceGame> createState() => _NeuroTraceGameState();
}

class _NeuroTraceGameState extends State<NeuroTraceGame> {
  static const int gridSize = 3; // 3x3 grid for now
  late List<bool> tileStates;

  int soulsFreed = 0;
  int traceLevel = 0; // 0–100%
  int timerSeconds = 15; // countdown timer

  @override
  void initState() {
    super.initState();
    tileStates = List.generate(gridSize * gridSize, (_) => false);

    // Start the countdown timer
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && timerSeconds > 0) {
        setState(() {
          timerSeconds--;
          traceLevel += 3; // trace goes up every second
        });
        return true;
      }
      return false;
    });
  }

  void toggleTile(int index) {
    setState(() {
      tileStates[index] = !tileStates[index];
    });

    // Check win/lose state
    if (tileStates.every((t) => t)) {
      setState(() {
        soulsFreed++;
        timerSeconds = 15; // reset timer
        tileStates = List.generate(gridSize * gridSize, (_) => false);
      });
    } else if (tileStates.every((t) => !t)) {
      setState(() {
        timerSeconds = 0; // you got fried
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("NEUROTRACE"),
        backgroundColor: Colors.black,
        actions: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Center(
              child: Text("Souls: $soulsFreed"),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text("Trace ${traceLevel.clamp(0, 100)}%"),
              Text("Level 1 (${gridSize}×$gridSize)"),
              Text("⏱ $timerSeconds s"),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: gridSize,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              padding: const EdgeInsets.all(24),
              itemCount: gridSize * gridSize,
              itemBuilder: (context, index) {
                final lit = tileStates[index];
                return GestureDetector(
                  onTap: () => toggleTile(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: lit ? Colors.greenAccent : Colors.blueGrey[900],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: lit
                          ? [
                              BoxShadow(
                                color: Colors.greenAccent.withOpacity(0.6),
                                blurRadius: 20,
                                spreadRadius: 2,
                              )
                            ]
                          : [],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
