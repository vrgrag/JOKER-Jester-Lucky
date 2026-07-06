import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart' show Colors;

import '../../core/app_assets.dart';
import '../difficulty.dart';
import '../jester_lucky_game.dart';

enum EnemyKind { goblin, mimic }

/// A greedy creature marching in a straight line towards the treasury.
///
/// Both enemy types share the exact same behaviour (walk towards the
/// center, die after N hits, reward the player on death) -- only their
/// stats and art differ, so a single configurable class is used instead
/// of duplicating logic across subclasses.
class EnemyComponent extends SpriteComponent
    with HasGameReference<JesterLuckyGame> {
  EnemyComponent.goblin({required Vector2 spawnPosition})
      : kind = EnemyKind.goblin,
        baseSpeed = 118,
        maxHealth = 1,
        scoreValue = 10,
        coinValue = 1,
        hitRadius = 46,
        super(
          anchor: Anchor.center,
          size: Vector2.all(96),
          position: spawnPosition,
        ) {
    health = maxHealth;
  }

  EnemyComponent.mimic({required Vector2 spawnPosition})
      : kind = EnemyKind.mimic,
        baseSpeed = 70,
        maxHealth = 2,
        scoreValue = 25,
        coinValue = 2,
        hitRadius = 52,
        super(
          anchor: Anchor.center,
          size: Vector2.all(108),
          position: spawnPosition,
        ) {
    health = maxHealth;
  }

  final EnemyKind kind;
  final double baseSpeed;
  final int maxHealth;
  final int scoreValue;
  final int coinValue;
  final double hitRadius;

  late int health;
  late Vector2 direction;
  bool dead = false;

  @override
  Future<void> onLoad() async {
    final assetPath =
        kind == EnemyKind.goblin ? AppAssets.goblinThief : AppAssets.mimicChest;
    sprite = Sprite(game.images.fromCache(AppAssets.fileName(assetPath)));
    direction = (game.hero.position - position).normalized();
  }

  double get currentSpeed =>
      baseSpeed * Difficulty.speedMultiplier(game.elapsedTime);

  @override
  void update(double dt) {
    super.update(dt);
    if (dead || !game.isRunning) return;

    position += direction * currentSpeed * dt;

    final distanceToHero = position.distanceTo(game.hero.position);
    if (distanceToHero <= JesterLuckyGame.killRadius + hitRadius * 0.4) {
      game.triggerGameOver();
    }
  }

  /// Returns true if the enemy died from this hit.
  bool receiveHit() {
    if (dead) return false;
    health -= 1;
    if (health <= 0) {
      _die();
      return true;
    } else {
      _flashHit();
      return false;
    }
  }

  void _flashHit() {
    add(
      ColorEffect(
        Colors.white,
        EffectController(duration: 0.08, alternate: true),
        opacityFrom: 0,
        opacityTo: 0.85,
      ),
    );
  }

  void _die() {
    dead = true;
    game.onEnemyKilled(this);
    removeFromParent();
  }

  /// Instant kill used by the Jackpot super ability (bypasses health/reward
  /// bookkeeping which the caller handles itself).
  void obliterate() {
    if (dead) return;
    dead = true;
    removeFromParent();
  }
}
