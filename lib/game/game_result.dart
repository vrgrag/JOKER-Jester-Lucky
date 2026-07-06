/// Snapshot of a finished run, handed back to the Flutter UI.
class GameResult {
  const GameResult({
    required this.score,
    required this.coins,
    required this.isNewRecord,
  });

  final int score;
  final int coins;
  final bool isNewRecord;
}
