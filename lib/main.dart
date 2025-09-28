import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'dart:math';

void main() {
  runApp(GameWidget(game: NeuroTraceGame()));
}

class NeuroTraceGame extends FlameGame with TapDetector {
  late ProgressBar progressBar;
  late TextComponent statusText;
  late HealthBar healthBar;

  double sweetSpotStart = 0.7;
  double sweetSpotEnd = 0.9;
  bool waitingForTap = false;

  List<int> memorySequence = [];
  List<int> playerInput = [];

  Random random = Random();
  int health = 3;

  @override
  Future<void> onLoad() async {
    progressBar = ProgressBar()
      ..position = Vector2(50, size.y / 2)
      ..size = Vector2(size.x - 100, 30);
    add(progressBar);

    healthBar = HealthBar(health)
      ..position = Vector2(50, size.y - 50)
      ..size = Vector2(size.x - 100, 20);
    add(healthBar);

    statusText = TextComponent(
      text: "Hack Started...",
      position: Vector2(50, 100),
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.green, fontSize: 18),
      ),
    );
    add(statusText);

    addToMemory();
  }

  void addToMemory() {
    memorySequence.add(random.nextInt(4));
    playerInput.clear();
    statusText.text = "Memorize: ${memorySequence.join('-')}";
    waitingForTap = false;
    progressBar.reset();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!waitingForTap) {
      progressBar.updateBar(dt);
      if (progressBar.value >= 1.0) {
        waitingForTap = true;
        statusText.text = "Tap now!";
        progressBar.reset();
      }
    } else {
      progressBar.updateBar(dt);
      if (progressBar.value
