import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around [SharedPreferences] persisting the player's
/// best run entirely on-device -- no network access required.
class StorageService {
  StorageService._(this._prefs);

  static const _kBestScore = 'best_score';
  static const _kBestCoins = 'best_coins';

  final SharedPreferences _prefs;

  static StorageService? _instance;

  static Future<StorageService> getInstance() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    _instance = StorageService._(prefs);
    return _instance!;
  }

  int get bestScore => _prefs.getInt(_kBestScore) ?? 0;
  int get bestCoins => _prefs.getInt(_kBestCoins) ?? 0;

  /// Stores the given run if it beats the previous record.
  /// Returns true when a new record was set.
  Future<bool> reportRun({required int score, required int coins}) async {
    var newRecord = false;
    if (score > bestScore) {
      await _prefs.setInt(_kBestScore, score);
      newRecord = true;
    }
    if (coins > bestCoins) {
      await _prefs.setInt(_kBestCoins, coins);
    }
    return newRecord;
  }
}
