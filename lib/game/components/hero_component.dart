import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart' show Curves;

import '../../core/app_assets.dart';
import '../jester_lucky_game.dart';

/// The Lucky Jester, fixed at the center of the arena, guarding the
/// treasury behind him. Purely cosmetic idle motion + a subtle lean in
/// the direction the player is currently aiming.
class HeroComponent extends SpriteComponent
    with HasGameReference<JesterLuckyGame> {
  HeroComponent() : super(anchor: Anchor.center, size: Vector2.all(172));

  double _targetTilt = 0;

  @override
  Future<void> onLoad() async {
    sprite = Sprite(game.images.fromCache(AppAssets.fileName(AppAssets.hero)));
    position = game.size / 2;
    add(
      ScaleEffect.to(
        Vector2.all(1.045),
        EffectController(
          duration: 0.85,
          reverseDuration: 0.85,
          infinite: true,
          curve: Curves.easeInOut,
        ),
      ),
    );
  }

  void aimTowards(Vector2 direction) {
    _targetTilt = direction.x.clamp(-1.0, 1.0) * 0.16;
  }

  void resetAim() => _targetTilt = 0;

  void punch() {
    add(
      SequenceEffect([
        ScaleEffect.to(Vector2.all(0.92), EffectController(duration: 0.05)),
        ScaleEffect.to(
          Vector2.all(1.0),
          EffectController(duration: 0.15, curve: Curves.easeOut),
        ),
      ]),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    angle += (_targetTilt - angle) * min(1, dt * 9);
  }
}
