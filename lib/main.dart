import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(GameWidget(game: NeuroTraceGame()));
}

class NeuroTraceGame extends FlameGame with TapCallbacks {
  late ProgressBar progressBar;
  late HealthBar healthBar;

  final Random random = Random();
  int health = 3;

  bool waitingForTap = false;
  final List<int> memorySequence = [];
  final List<int> playerInput = [];

  @override
  Future<void> onLoad() async {
    // UI bars
    progressBar = ProgressBar(
      position: Vector2(50, 40),
      size: Vector2(260, 18),
    );
    healthBar = HealthBar(
      position: Vector2(50, 70),
      size: Vector2(260, 12),
      health: health,
    );
    add(progressBar);
    add(healthBar);

    // 4 buttons in a 2x2 grid
    const double btnSize = 100;
    for (int i = 0; i < 4; i++) {
      final x = 50 + (i % 2) * (btnSize + 20);
      final y = 120 + (i ~/ 2) * (btnSize + 20);
      add(GlyphButton(
        index: i,
        position: Vector2(x.toDouble(), y.toDouble()),
        size: Vector2(btnSize, btnSize),
        onPressed: () => checkMemoryInput(i),
      ));
    }

    await Future.delayed(const Duration(milliseconds: 300));
    await showMemorySequence();
  }

  Future<void> showMemorySequence() async {
    // Extend the sequence by one random glyph and “animate” the bar
    memorySequence.add(random.nextInt(4));
    waitingForTap = false;
    playerInput.clear();

    progressBar.setValue(0);
    for (int i = 0; i < memorySequence.length; i++) {
      progressBar.setValue((i + 1) / memorySequence.length);
      await Future.delayed(const Duration(milliseconds: 400));
    }

    waitingForTap = true;
  }

  void checkMemoryInput(int i) {
    if (!waitingForTap) return;

    playerInput.add(i);

    // If wrong input: reduce health and restart showing sequence
    final idx = playerInput.length - 1;
    if (playerInput[idx] != memorySequence[idx]) {
      health -= 1;
      healthBar.setHealth(health);
      waitingForTap = false;

      if (health <= 0) {
        // reset game
        health = 3;
        memorySequence.clear();
        playerInput.clear();
        healthBar.setHealth(health);
      }

      // show again (and add a new element if we reset)
      Future.delayed(const Duration(milliseconds: 400), () async {
        await showMemorySequence();
      });
      return;
    }

    // If finished current sequence correctly, add a new step
    if (playerInput.length == memorySequence.length) {
      waitingForTap = false;
      Future.delayed(const Duration(milliseconds: 400), () async {
        await showMemorySequence();
      });
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
  }
}

/// ---------- Components (declared below for convenience) ----------

class ProgressBar extends PositionComponent {
  double _value = 0; // 0..1
  final Paint _bg = Paint()..color = const Color(0xFF30343A);
  final Paint _fg = Paint()..color = const Color(0xFF64B5F6);

  ProgressBar({super.position, super.size});

  void setValue(double v) {
    _value = v.clamp(0, 1);
  }

  @override
  void render(Canvas canvas) {
    // background
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(6)),
      _bg,
    );
    // foreground
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.x * _value, size.y), const Radius.circular(6)),
      _fg,
    );
  }
}

class HealthBar extends PositionComponent {
  int _health; // 0..3
  final Paint _slot = Paint()..color = const Color(0xFFE0E0E0);
  final Paint _full = Paint()..color = const Color(0xFFEF5350);

  HealthBar({required int health, super.position, super.size}) : _health = health;

  void setHealth(int h) {
    _health = h.clamp(0, 3);
  }

  @override
  void render(Canvas canvas) {
    // 3 small segments
    const gap = 4.0;
    final segmentW = (size.x - gap * 2) / 3;
    for (int i = 0; i < 3; i++) {
      final rect = Rect.fromLTWH(i * (segmentW + gap), 0, segmentW, size.y);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), _slot);
      if (i < _health) {
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), _full);
      }
    }
  }
}

class GlyphButton extends PositionComponent with TapCallbacks {
  final int index;
  final VoidCallback onPressed;

  GlyphButton({
    required this.index,
    required this.onPressed,
    super.position,
    super.size,
  });

  final Paint _bg = Paint()..color = const Color(0xFF424B57);
  final Paint _outline = Paint()
    ..color = const Color(0xFF90CAF9)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  final TextPaint _label = TextPaint(
    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600),
  );

  @override
  void render(Canvas canvas) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(14),
    );
    canvas.drawRRect(rrect, _bg);
    canvas.drawRRect(rrect, _outline);

    final text = 'Glyph $index';
    final tp = _label.toTextPainter(text);
    tp.layout();
    tp.paint(canvas, Offset((size.x - tp.width) / 2, (size.y - tp.height) / 2));
  }

  @override
  void onTapDown(TapDownEvent event) {
    onPressed();
  }
}
