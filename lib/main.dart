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

  final List<int> memorySequence = [];
  final List<int> playerInput = [];
  final Random random = Random();
  int health = 3;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // UI
    progressBar = ProgressBar();
    add(progressBar);

    statusText = TextComponent(
      text: 'Tap to begin',
      position: Vector2(200, 50),
      anchor: Anchor.topCenter,
      priority: 10,
    );
    add(statusText);

    healthBar = HealthBar(position: Vector2(50, 100));
    add(healthBar);

    // 4 glyph buttons
    for (int i = 0; i < 4; i++) {
      add(GlyphButton(
        index: i,
        position: Vector2(60 + i * 80, 300),
        onTap: () => checkMemoryInput(i),
      ));
    }
  }

  void startTimingPhase() {
    progressBar.reset();
    waitingForTap = true;
    statusText.text = 'Tap in the sweet spot!';
  }

  void startMemoryPhase() {
    memorySequence.add(random.nextInt(4));
    statusText.text = 'Memorize the sequence';
    Future.delayed(const Duration(milliseconds: 800), showMemorySequence);
  }

  void showMemorySequence() {
    for (int i = 0; i < memorySequence.length; i++) {
      Future.delayed(Duration(milliseconds: i * 700), () {
        statusText.text = 'Glyph: ${memorySequence[i]}';
      });
    }
    Future.del
