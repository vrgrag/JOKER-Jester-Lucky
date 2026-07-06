import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';

import '../jester_lucky_game.dart';

/// Draws a dotted trajectory guide from the Jester towards the current
/// drag direction, giving the player clear "drag to aim" feedback.
class AimGuideComponent extends Component
    with HasGameReference<JesterLuckyGame> {
  AimGuideComponent() : super(priority: 50);

  static const double _maxLength = 280;
  static const int _dotCount = 7;

  final Paint _dotPaint = Paint();

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final aim = game.aimLine;
    if (aim == null) return;

    final (origin, direction) = aim;
    for (var i = 1; i <= _dotCount; i++) {
      final t = i / _dotCount;
      final point = origin + direction * (_maxLength * t);
      final radius = 7.0 * (1 - t * 0.55);
      final opacity = (1 - t * 0.75).clamp(0.0, 1.0);
      _dotPaint.color = const Color(0xFFFFD966).withValues(alpha: opacity);
      canvas.drawCircle(point.toOffset(), radius, _dotPaint);
    }
  }
}
