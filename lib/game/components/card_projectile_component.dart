import 'package:flame/components.dart';

import '../../core/app_assets.dart';
import '../jester_lucky_game.dart';

/// The Jester's enchanted playing card, flung towards whatever direction
/// the player aimed and dragged.
class CardProjectileComponent extends SpriteComponent
    with HasGameReference<JesterLuckyGame> {
  CardProjectileComponent({
    required Vector2 startPosition,
    required Vector2 direction,
  })  : _direction = direction.normalized(),
        super(
          anchor: Anchor.center,
          size: Vector2.all(46),
          position: startPosition,
        );

  final Vector2 _direction;

  static const double speed = 1050;
  static const double hitRadius = 28;

  @override
  Future<void> onLoad() async {
    sprite =
        Sprite(game.images.fromCache(AppAssets.fileName(AppAssets.spinningCards)));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!game.isRunning) {
      removeFromParent();
      return;
    }

    position += _direction * speed * dt;
    angle += dt * 16;

    for (final enemy in game.enemies) {
      if (enemy.dead) continue;
      final reach = hitRadius + enemy.hitRadius * 0.55;
      if (position.distanceTo(enemy.position) <= reach) {
        enemy.receiveHit();
        removeFromParent();
        return;
      }
    }

    const margin = 100.0;
    final size = game.size;
    if (position.x < -margin ||
        position.y < -margin ||
        position.x > size.x + margin ||
        position.y > size.y + margin) {
      removeFromParent();
    }
  }
}
