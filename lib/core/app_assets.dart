/// Central registry of every image asset shipped with the app.
///
/// Split into two logical packs:
///   • [_gamePrefix] — art the native game uses (loaded by Flame).
///   • [_extraPrefix] — art the shell (loading / notification / offline)
///     stages use. Renamed per project so the compiled asset paths do
///     not match any other release.
class AppAssets {
  AppAssets._();

  // Root of every asset path we ship.
  static const String _gamePrefix = 'assets';
  // [FINGERPRINT] Do not reuse across projects. See
  // .cursor/rules/custom_screens.md → [FINGERPRINT] block.
  static const String _extraPrefix = 'assets/jester_extra_pack';

  // ── Game (white part) art ────────────────────────────────
  static const String background = '$_gamePrefix/Background_RoyalTreasury.webp';
  static const String coin = '$_gamePrefix/Collectible_LuckyCoin.webp';
  static const String goblinThief = '$_gamePrefix/Enemy_GoblinThief.webp';
  static const String mimicChest = '$_gamePrefix/Enemy_MimicChest.webp';
  static const String gameLogo = '$_gamePrefix/Game_Name.webp';
  static const String hero = '$_gamePrefix/Hero.webp';
  static const String loadingHorizontal = '$_gamePrefix/Horizontal_Loading.webp';
  static const String loadingVertical = '$_gamePrefix/Vertical_Loading.webp';
  static const String icon = '$_gamePrefix/icon2.png';
  static const String spinningCards = '$_gamePrefix/Obstacle_SpinningCards.webp';
  static const String jackpot = '$_gamePrefix/Powerup_Jackpot.webp';

  // ── Shell (gray part) art ────────────────────────────────
  static const String noSignalVertical = '$_extraPrefix/vertical_no_signal.webp';
  static const String noSignalHorizontal = '$_extraPrefix/horizontal_no_signal.webp';
  static const String beaconVertical = '$_extraPrefix/vertical_beacon.webp';
  static const String beaconHorizontal = '$_extraPrefix/horizontal_beacon.webp';

  /// Every image the game needs to have warmed before the first frame.
  static const List<String> gameArt = [
    background,
    coin,
    goblinThief,
    mimicChest,
    gameLogo,
    hero,
    loadingHorizontal,
    loadingVertical,
    spinningCards,
    jackpot,
  ];

  /// Legacy alias for existing splash / preload paths.
  static const List<String> all = gameArt;

  /// Bare filename (without the `assets/` prefix), the key format used by
  /// Flame's [Images] cache.
  static String fileName(String path) => path.split('/').last;
}
