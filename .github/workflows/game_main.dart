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
    await super.onLoad();
    add(progressBar = ProgressBar());
    add(statusText = TextComponent(
      text: 'Tap to begin',
      position: Vector2(size.x / 2, 50),
      anchor: Anchor.topCenter,
    ));
    add(healthBar = HealthBar(position: Vector2(50, 100)));

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
    Future.delayed(
      Duration(milliseconds: memorySequence.length * 700 + 500),
      () {
        statusText.text = 'Repeat the sequence';
        playerInput.clear();
      },
    );
  }

  void checkMemoryInput(int value) {
    if (playerInput.length < memorySequence.length) {
      playerInput.add(value);
      if (playerInput.last != memorySequence[playerInput.length - 1]) {
        health--;
        healthBar.updateHealth(health);
        statusText.text = 'Wrong! Brain damage!';
        if (health <= 0) {
          statusText.text = 'Brain fried! Game Over';
          memorySequence.clear();
        } else {
          Future.delayed(const Duration(seconds: 1), startTimingPhase);
        }
        return;
      }
      if (playerInput.length == memorySequence.length) {
        statusText.text = 'Good job! Next round';
        Future.delayed(const Duration(seconds: 1), startTimingPhase);
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (waitingForTap) progressBar.updateProgress(dt);
  }

  @override
  void onTapDown(TapDownInfo info) {
    if (!waitingForTap) {
      startTimingPhase();
      return;
    }

    waitingForTap = false;
    if (progressBar.progress >= sweetSpotStart &&
        progressBar.progress <= sweetSpotEnd) {
      statusText.text = 'Access Granted';
      Future.delayed(const Duration(seconds: 1), startMemoryPhase);
    } else {
      health--;
      healthBar.updateHealth(health);
      statusText.text = 'Too early/late! Neural hit!';
      if (health > 0) {
        Future.delayed(const Duration(seconds: 1), startTimingPhase);
      } else {
        statusText.text = 'Brain fried! Game Over';
        memorySequence.clear();
      }
    }
  }
}

class ProgressBar extends PositionComponent {
  double progress = 0.0;

  @override
  void render(Canvas canvas) {
    final bg = Paint()..color = Colors.grey;
    canvas.drawRect(Rect.fromLTWH(50, 200, 300, 20), bg);

    final fg = Paint()..color = Colors.greenAccent;
    canvas.drawRect(Rect.fromLTWH(50, 200, 300 * progress, 20), fg);
  }

  void updateProgress(double dt) {
    progress += dt * 0.4;
    if (progress > 1.0) progress = 0.0;
  }

  void reset() {
    progress = 0.0;
  }
}

class GlyphButton extends PositionComponent with Tappable {
  final int index;
  final VoidCallback onTap;

  GlyphButton({
    required this.index,
    required Vector2 position,
    required this.onTap,
  }) {
    this.position = position;
    size = Vector2(60, 60);
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.blueAccent;
    canvas.drawRect(size.toRect(), paint);
    final tp = TextPainter(
      text: TextSpan(
          text: '$index',
          style: const TextStyle(color: Colors.white, fontSize: 20)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas,
        Offset(size.x / 2 - tp.width / 2, size.y / 2 - tp.height / 2));
  }

  @override
  bool onTapDown(TapDownInfo info) {
    onTap();
    return true;
  }
}

class HealthBar extends PositionComponent {
  int health = 3;

  HealthBar({required Vector2 position}) {
    this.position = position;
    size = Vector2(120, 20);
  }

  void updateHealth(int newHealth) {
    health = newHealth.clamp(0, 3);
  }

  @override
  void render(Canvas canvas) {
    final bg = Paint()..color = Colors.red.withOpacity(0.3);
    canvas.drawRect(size.toRect(), bg);

    final fg = Paint()..color = Colors.red;
    final w = size.x * (health / 3);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, size.y), fg);
  }
}
