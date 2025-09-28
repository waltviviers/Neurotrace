import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';

class NeuroTraceGame extends FlameGame with TapDetector {
  late RectangleComponent progressBar;
  late RectangleComponent healthBar;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Simple progress bar
    progressBar = RectangleComponent(
      size: Vector2(200, 20),
      paint: Paint()..color = const Color(0xFF00FF00),
    )
      ..position = Vector2(50, 50);
    add(progressBar);

    // Simple health bar
    healthBar = RectangleComponent(
      size: Vector2(200, 20),
      paint: Paint()..color = const Color(0xFFFF0000),
    )
      ..position = Vector2(50, 100);
    add(healthBar);
  }

  @override
  void onTapDown(TapDownInfo info) {
    // For now just shrink the progress bar when you tap
    progressBar.size.x -= 10;
    if (progressBar.size.x < 0) progressBar.size.x = 0;
  }
}
