/// Central registry of every image asset used by the game.
///
/// Keeping paths in one place avoids typos scattered across the codebase
/// and gives the preloader a single source of truth for what must be
/// warmed up before the game is considered "ready".
class AppAssets {
  AppAssets._();

  static const String background = 'assets/Background_RoyalTreasury.webp';
  static const String coin = 'assets/Collectible_LuckyCoin.webp';
  static const String goblinThief = 'assets/Enemy_GoblinThief.webp';
  static const String mimicChest = 'assets/Enemy_MimicChest.webp';
  static const String gameLogo = 'assets/Game_Name.webp';
  static const String hero = 'assets/Hero.webp';
  static const String loadingHorizontal = 'assets/Horizontal_Loading.webp';
  static const String loadingVertical = 'assets/Vertical_Loading.webp';
  static const String icon = 'assets/Icon.png';
  static const String spinningCards = 'assets/Obstacle_SpinningCards.webp';
  static const String jackpot = 'assets/Powerup_Jackpot.webp';

  /// Every image that should be decoded/cached before the app is shown.
  static const List<String> all = [
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

  /// Bare filename (without the `assets/` prefix), the key format used by
  /// Flame's [Images] cache.
  static String fileName(String path) => path.split('/').last;
}
