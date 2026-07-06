import 'package:flame/components.dart';
import 'package:flame/effects.dart';

import '../../core/app_assets.dart';
import '../jester_lucky_game.dart';

/// A small Lucky Coin that pops out of a defeated enemy and arcs away
/// before fading, giving hits a satisfying bit of extra juice.
class CoinPopComponent extends SpriteComponent
    with HasGameReference<JesterLuckyGame> {
  CoinPopComponent({
    required Vector2 startPosition,
    required Vector2 velocity,
  })  : _velocity = velocity,
        super(
          anchor: Anchor.center,
          size: Vector2.all(32),
          position: startPosition,
        );

  final Vector2 _velocity;

  @override
  Future<void> onLoad() async {
    sprite = Sprite(game.images.fromCache(AppAssets.fileName(AppAssets.coin)));
    add(
      OpacityEffect.fadeOut(
        EffectController(duration: 0.5, startDelay: 0.3),
        onComplete: removeFromParent,
      ),
    );
    add(ScaleEffect.to(Vector2.all(0.35), EffectController(duration: 0.8)));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _velocity.y += 520 * dt;
    position += _velocity * dt;
  }
}
