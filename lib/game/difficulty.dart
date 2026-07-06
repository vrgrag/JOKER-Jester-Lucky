/// Pure functions describing how the challenge ramps up over a run.
///
/// The first 20-30 seconds stay easy (Goblins only, slow spawns) and then
/// spawn-rate, speed and enemy variety all increase the longer the player
/// survives.
class Difficulty {
  Difficulty._();

  /// Seconds between enemy spawns at time [t] (seconds since run start).
  static double spawnInterval(double t) {
    final value = 1.75 - t * 0.016;
    return value.clamp(0.42, 1.75);
  }

  /// Multiplier applied to every enemy's base movement speed.
  static double speedMultiplier(double t) {
    final ramp = (t / 50).clamp(0.0, 1.0);
    return 1.0 + ramp * 0.9;
  }

  /// Mimic Chests only start appearing once the player has warmed up.
  static bool mimicUnlocked(double t) => t >= 22;

  /// Chance (0-1) that a spawn wave picks a Mimic Chest once unlocked.
  static double mimicChance(double t) {
    if (!mimicUnlocked(t)) return 0;
    return ((t - 22) / 60).clamp(0.0, 0.55);
  }

  /// Past this point, spawns occasionally throw two enemies at once from
  /// different sides, forcing the player to aim faster.
  static bool doubleSpawnUnlocked(double t) => t >= 38;

  static double doubleSpawnChance(double t) {
    if (!doubleSpawnUnlocked(t)) return 0;
    return ((t - 38) / 90).clamp(0.0, 0.45);
  }
}
