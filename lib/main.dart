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
      title: 'NeuroTrace',
      theme: ThemeData.dark(),
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
  int level = 1;
  int gridRows = 3;
  int gridCols = 5;
  int trace = 0;
  int souls = 0;
  int timeLeft = 15;
  late Timer timer;
  late List<List<bool>> grid;

  @override
  void initState() {
    super.initState();
    _startLevel();
  }

  void _startLevel() {
    grid = List.generate(
        gridRows, (_) => List.generate(gridCols, (_) => Random().nextBool()));

    timeLeft = max(8, 20 - level); // timer shrinks as level goes up
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        timeLeft--;
        if (timeLeft <= 0) {
          _gameOver();
        }
      });
    });
  }

  void _toggleTile(int r, int c) {
    setState(() {
      grid[r][c] = !grid[r][c];
      // optional: toggle neighbors
      if (r > 0) grid[r - 1][c] = !grid[r - 1][c];
      if (r < gridRows - 1) grid[r + 1][c] = !grid[r + 1][c];
      if (c > 0) grid[r][c - 1] = !grid[r][c - 1];
      if (c < gridCols - 1) grid[r][c + 1] = !grid[r][c + 1];
    });

    if (_checkWin()) {
      _levelUp();
    }
  }

  bool _checkWin() {
    return grid.every((row) => row.every((cell) => cell));
  }

  void _levelUp() {
    timer.cancel();
    setState(() {
      souls += level * 10;
      level++;
      trace = min(100, trace + 10);
      if (level % 2 == 0) {
        gridRows++;
      } else {
        gridCols++;
      }
    });
    _startLevel();
  }

  void _applyTrace(double change) {
    setState(() {
      trace = max(0, min(100, trace + change.toInt()));
      if (trace >= 100) {
        _gameOver();
      }
    });
  }

  void _gameOver() {
    timer.cancel();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("You’ve been traced!"),
        content: Text("Souls liberated: $souls"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                level = 1;
                gridRows = 3;
                gridCols = 5;
                souls = 0;
                trace = 0;
              });
              _startLevel();
            },
            child: const Text("Restart"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Trace ${trace}%",
                      style: const TextStyle(fontSize: 18)),
                  Text("Level $level (${gridRows}×$gridCols)",
                      style: const TextStyle(fontSize: 18)),
                  Text("⏱ $timeLeft s",
                      style: const TextStyle(fontSize: 18)),
                  Text("Souls: $souls",
                      style: const TextStyle(fontSize: 18)),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridCols,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: gridRows * gridCols,
                itemBuilder: (context, index) {
                  int r = index ~/ gridCols;
                  int c = index % gridCols;
                  bool lit = grid[r][c];
                  return GestureDetector(
                    onTap: () => _toggleTile(r, c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: lit ? Colors.greenAccent : Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: lit
                            ? [
                                BoxShadow(
                                  color: Colors.greenAccent.withOpacity(0.7),
                                  blurRadius: 15,
                                  spreadRadius: 3,
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
      ),
    );
  }
}
