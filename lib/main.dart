import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(GameWidget(game: NeuroTraceGame()));
}

class NeuroTraceGame extends FlameGame with HasTappables {
  late TextComponent statusText;
  final Random _rand = Random();

  final List<int> memorySequence = [];
  final List<int> playerInput = [];
  final List<GlyphButton> buttons = [];

  bool showing = false;

  @override
  Color backgroundColor() => const Color(0xFF0A0A0F);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Fixed logical size so it looks consistent on the runner
    camera.viewport = FixedResolutionViewport(Vector2(320, 480));

    statusText = TextComponent(
      text: 'Tap PLAY',
      position: Vector2(10, 10),
      anchor: Anchor.topLeft,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
        ),
      ),
    );
    add(statusText);

    // Create 4 buttons in a 2x2 grid
    final positions = <Vector2>[
      Vector2(60, 160),
      Vector2(180, 160),
      Vector2(60, 280),
      Vector2(180, 280),
    ];

    for (int i = 0; i < 4; i++) {
      final btn = GlyphButton(
        id: i,
        position: positions[i],
        size: Vector2(80, 80),
        onPressed: onButtonPressed,
      );
      buttons.add(btn);
      add(btn);
    }

    // PLAY button
    add(PlayButton(
      position: Vector2(160, 90),
      onPressed: startRound,
    ));
  }

  void startRound() {
    if (showing) return;
    playerInput.clear();
    memorySequence.add(_rand.nextInt(4));
    statusText.text = 'Memorize…';
    showMemorySequence();
  }

  Future<void> showMemorySequence() async {
    showing = true;
    for (final id in memorySequence) {
      await buttons[id].flash();
      await Future.delayed(const Duration(milliseconds: 250));
    }
    showing = false;
    statusText.text = 'Your turn';
  }

  void onButtonPressed(int id) {
    if (showing || memorySequence.isEmpty) return;

    playerInput.add(id);
    final idx = playerInput.length - 1;

    if (playerInput[idx] != memorySequence[idx]) {
      statusText.text =
          'Wrong! Score: ${memorySequence.length - 1}  (tap PLAY)';
      memorySequence.clear();
      playerInput.clear();
      return;
    }

    if (playerInput.length == memorySequence.length) {
      statusText.text = 'Great! Next round…';
      Future.delayed(const Duration(milliseconds: 600), startRound);
    }
  }
}

class GlyphButton extends PositionComponent
    with TapCallbacks, HasGameRef<NeuroTraceGame> {
  GlyphButton({
    required this.id,
    required Vector2 position,
    required Vector2 size,
    required this.onPressed,
  }) {
    this.position = position;
    this.size = size;
    anchor = Anchor.center;
  }

  final int id;
  final void Function(int) onPressed;
  bool _highlight = false;

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    final paint = Paint()
      ..color = _highlight ? Colors.tealAccent : _colorFor(id);
    canvas.drawRRect(rrect, paint);

    // Label (A/B/C/D)
    final label = ['A', 'B', 'C', 'D'][id];
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(size.x / 2 - tp.width / 2, size.y / 2 - tp.height / 2),
    );
  }

  Color _colorFor(int i) {
    switch (i) {
      case 0:
        return const Color(0xFF64FFDA);
      case 1:
        return const Color(0xFF7C4DFF);
      case 2:
        return const Color(0xFFFFD54F);
      default:
        return const Color(0xFFE57373);
    }
  }

  Future<void> flash() async {
    _highlight = true;
    await Future.delayed(const Duration(milliseconds: 350));
    _highlight = false;
  }

  @override
  void onTapUp(TapUpEvent event) {
    onPressed(id);
  }
}

class PlayButton extends PositionComponent with TapCallbacks {
  PlayButton({required Vector2 position, required this.onPressed}) {
    this.position = position;
    size = Vector2(120, 36);
    anchor = Anchor.center;
  }

  final VoidCallback onPressed;

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    final paint = Paint()..color = Colors.white;
    canvas.drawRRect(rrect, paint);

    final tp = TextPainter(
      text: const TextSpan(
        text: 'PLAY',
        style: TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(size.x / 2 - tp.width / 2, size.y / 2 - tp.height / 2),
    );
  }

  @override
  void onTapUp(TapUpEvent event) {
    onPressed();
  }
}
