import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart' show Curves;

import '../../core/app_assets.dart';
import '../jester_lucky_game.dart';
import 'coin_pop_component.dart';

/// The Jester's super ability: a burst of luck that fills the screen with
/// gold coins, wipes out every enemy currently on the field, and shows a
/// big "JACKPOT" badge at the hero's position.
class JackpotBurstComponent extends PositionComponent
    with HasGameReference<JesterLuckyGame> {
  JackpotBurstComponent({required Vector2 center})
      : super(position: center, anchor: Anchor.center, priority: 100);

  static final Random _rand = Random();

  @override
  Future<void> onLoad() async {
    final badge = SpriteComponent(
      sprite: Sprite(game.images.fromCache(AppAssets.fileName(AppAssets.jackpot))),
      size: Vector2.all(240),
      anchor: Anchor.center,
      scale: Vector2.all(0.05),
    );
    add(badge);
    badge.add(
      SequenceEffect(
        [
          ScaleEffect.to(
            Vector2.all(1.05),
            EffectController(duration: 0.32, curve: Curves.easeOutBack),
          ),
          ScaleEffect.to(
            Vector2.all(0.85),
            EffectController(
              duration: 0.5,
              startDelay: 0.55,
              curve: Curves.easeIn,
            ),
          ),
        ],
        onComplete: removeFromParent,
      ),
    );
    badge.add(
      OpacityEffect.fadeOut(
        EffectController(duration: 0.4, startDelay: 0.65),
      ),
    );

    for (var i = 0; i < 22; i++) {
      final angle = _rand.nextDouble() * pi * 2;
      final dir = Vector2(cos(angle), sin(angle));
      final speed = 240 + _rand.nextDouble() * 280;
      game.add(
        CoinPopComponent(startPosition: position.clone(), velocity: dir * speed),
      );
    }
  }
}
