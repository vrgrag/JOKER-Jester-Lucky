import 'dart:math';
import 'dart:ui';

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../core/app_assets.dart';
import 'components/aim_guide_component.dart';
import 'components/card_projectile_component.dart';
import 'components/coin_pop_component.dart';
import 'components/enemy_component.dart';
import 'components/hero_component.dart';
import 'components/jackpot_burst_component.dart';
import 'difficulty.dart';

/// Core game loop for Jester Lucky: aim with a drag, release to throw an
/// enchanted card, defend the treasury at the center of the screen.
class JesterLuckyGame extends FlameGame with DragCallbacks {
  JesterLuckyGame({required this.onGameOver});

  /// Called exactly once per run, the moment an enemy reaches the treasury.
  final void Function(int score, int coins) onGameOver;

  final ValueNotifier<int> score = ValueNotifier<int>(0);
  final ValueNotifier<int> coins = ValueNotifier<int>(0);
  final ValueNotifier<double> jackpot = ValueNotifier<double>(0);
  final ValueNotifier<bool> jackpotReady = ValueNotifier<bool>(false);

  late final HeroComponent hero;

  bool isRunning = true;
  double elapsedTime = 0;

  static const double killRadius = 74;
  static const double _jackpotTarget = 14;
  static const int _jackpotBonusScore = 120;

  final Random _rng = Random();
  double _spawnTimer = 1.0;

  bool _isAiming = false;
  Vector2? _dragStart;
  Vector2? _dragCurrent;

  Iterable<EnemyComponent> get enemies => children.query<EnemyComponent>();

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/';
    await images.loadAll(AppAssets.all.map(AppAssets.fileName).toList());

    hero = HeroComponent();
    add(hero);
    add(AimGuideComponent());
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isRunning) return;
    elapsedTime += dt;
    _updateSpawning(dt);
  }

  // Spawning ---------------------------------------------------------------

  void _updateSpawning(double dt) {
    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      _spawnWave();
      _spawnTimer = Difficulty.spawnInterval(elapsedTime);
    }
  }

  void _spawnWave() {
    _spawnOne();
    if (_rng.nextDouble() < Difficulty.doubleSpawnChance(elapsedTime)) {
      _spawnOne();
    }
  }

  void _spawnOne() {
    final angle = _rng.nextDouble() * pi * 2;
    final radius = size.length / 2 + 80;
    final center = size / 2;
    final spawnPosition = center + Vector2(cos(angle), sin(angle)) * radius;

    final useMimic = _rng.nextDouble() < Difficulty.mimicChance(elapsedTime);
    final enemy = useMimic
        ? EnemyComponent.mimic(spawnPosition: spawnPosition)
        : EnemyComponent.goblin(spawnPosition: spawnPosition);
    add(enemy);
  }

  // Input: drag to aim, release to throw -----------------------------------

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!isRunning) return;
    _isAiming = true;
    _dragStart = event.canvasPosition.clone();
    _dragCurrent = event.canvasPosition.clone();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    if (!isRunning || !_isAiming || _dragStart == null) return;
    _dragCurrent = event.canvasEndPosition.clone();
    final delta = _dragCurrent! - _dragStart!;
    if (delta.length > 6) {
      hero.aimTowards(delta.normalized());
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _throwIfAiming();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _isAiming = false;
    _dragStart = null;
    _dragCurrent = null;
    hero.resetAim();
  }

  void _throwIfAiming() {
    if (_isAiming && isRunning && _dragStart != null && _dragCurrent != null) {
      final delta = _dragCurrent! - _dragStart!;
      if (delta.length >= 22) {
        add(
          CardProjectileComponent(
            startPosition: hero.position.clone(),
            direction: delta.normalized(),
          ),
        );
        hero.punch();
      }
    }
    _isAiming = false;
    _dragStart = null;
    _dragCurrent = null;
    hero.resetAim();
  }

  /// The current aim line, used by the HUD/overlay painter. Null when the
  /// player isn't currently dragging.
  (Vector2 origin, Vector2 direction)? get aimLine {
    if (!_isAiming || _dragStart == null || _dragCurrent == null) return null;
    final delta = _dragCurrent! - _dragStart!;
    if (delta.length < 6) return null;
    return (hero.position, delta.normalized());
  }

  // Combat -------------------------------------------------------------

  void onEnemyKilled(EnemyComponent enemy) {
    score.value += enemy.scoreValue;
    coins.value += enemy.coinValue;
    _spawnCoinPops(enemy.position, enemy.coinValue);
    _advanceJackpot(enemy.coinValue);
  }

  void _spawnCoinPops(Vector2 origin, int count) {
    for (var i = 0; i < count.clamp(1, 3); i++) {
      final angle = _rng.nextDouble() * pi * 2;
      final speed = 150 + _rng.nextDouble() * 150;
      add(
        CoinPopComponent(
          startPosition: origin.clone(),
          velocity: Vector2(cos(angle), sin(angle)) * speed,
        ),
      );
    }
  }

  void _advanceJackpot(int coinValue) {
    if (jackpotReady.value) return;
    final next = (jackpot.value + coinValue / _jackpotTarget).clamp(0.0, 1.0);
    jackpot.value = next;
    if (next >= 1.0) {
      jackpotReady.value = true;
    }
  }

  /// Triggered by the player tapping the Jackpot button once it's full:
  /// a burst of luck wipes every enemy currently on screen.
  void activateJackpot() {
    if (!jackpotReady.value || !isRunning) return;

    score.value += _jackpotBonusScore;
    for (final enemy in enemies.toList()) {
      score.value += enemy.scoreValue;
      coins.value += enemy.coinValue;
      enemy.obliterate();
    }

    add(JackpotBurstComponent(center: hero.position.clone()));
    hero.punch();

    jackpot.value = 0;
    jackpotReady.value = false;
  }

  void triggerGameOver() {
    if (!isRunning) return;
    isRunning = false;
    _isAiming = false;
    onGameOver(score.value, coins.value);
  }

  /// Wipes the field and starts a brand new run without recreating the
  /// whole Flame engine/widget.
  void reset() {
    for (final enemy in enemies.toList()) {
      enemy.removeFromParent();
    }
    for (final projectile in children.query<CardProjectileComponent>().toList()) {
      projectile.removeFromParent();
    }

    score.value = 0;
    coins.value = 0;
    jackpot.value = 0;
    jackpotReady.value = false;
    elapsedTime = 0;
    _spawnTimer = 0.8;
    isRunning = true;
  }
}
