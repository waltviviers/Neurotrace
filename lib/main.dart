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
  static const int rows = 3;
  static const int cols = 5;

  List<List<bool>> grid = List.generate(
    rows,
    (_) => List.generate(cols, (_) => false),
  );

  int souls = 0;
  int level = 1;
  double trace = 0.0;
  int timeLeft = 30;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (timeLeft > 0) {
          timeLeft--;
        } else {
          // trace increases if time runs out
          trace += 0.1;
          timeLeft = 30;
        }
      });
      return true;
    });
  }

  void toggleTile(int row, int col) {
    setState(() {
      grid[row][col] = !grid[row][col];
    });
    checkWin();
  }

  void checkWin() {
    final allGreen = grid.every((r) => r.every((c) => c));
    if (allGreen) {
      setState(() {
        souls += 10 * level;
        level++;
        trace = (trace - 0.1).clamp(0.0, 1.0);
        timeLeft = 30;
        grid = List.generate(
          rows,
          (_) => List.generate(cols, (_) => false),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Removed `const` here so it works with headerStyle
            Text('NEUROTRACE', style: headerStyle),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Trace ${(trace * 100).round()}%"),
                  Text("Level $level"),
                  Text("⏱ ${timeLeft}s"),
                  Text("Souls: $souls"),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: rows * cols,
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final row = index ~/ cols;
                    final col = index % cols;
                    final isOn = grid[row][col];
                    return GestureDetector(
                      onTap: () => toggleTile(row, col),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          color: isOn ? Colors.greenAccent : Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isOn
                              ? [
                                  BoxShadow(
                                    color: Colors.greenAccent.withOpacity(0.8),
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
            ),
          ],
        ),
      ),
    );
  }
}