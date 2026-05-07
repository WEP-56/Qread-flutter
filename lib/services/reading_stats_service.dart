import 'dart:math';

import 'storage_service.dart';

class ReadingStatsSnapshot {
  final int totalSeconds;
  final int todaySeconds;

  const ReadingStatsSnapshot({
    required this.totalSeconds,
    required this.todaySeconds,
  });
}

class ReadingStatsService {
  static ReadingStatsService? _instance;
  static ReadingStatsService get instance =>
      _instance ??= ReadingStatsService._();

  static const _keyTotalSeconds = 'reading_stats_total_seconds';
  static const _keyTodaySeconds = 'reading_stats_today_seconds';
  static const _keyTodayDate = 'reading_stats_today_date';

  DateTime? _sessionStart;

  ReadingStatsService._();

  void startSession() {
    _sessionStart ??= DateTime.now();
  }

  Future<void> endSession() async {
    final start = _sessionStart;
    _sessionStart = null;
    if (start == null) return;

    final elapsedSeconds = max(0, DateTime.now().difference(start).inSeconds);
    if (elapsedSeconds <= 0) return;

    final storage = await StorageService.instance;
    final todayKey = _todayKey(DateTime.now());
    final lastDate = storage.readString(_keyTodayDate);
    final total = storage.readInt(_keyTotalSeconds) ?? 0;
    final today =
        lastDate == todayKey ? (storage.readInt(_keyTodaySeconds) ?? 0) : 0;

    await storage.setInt(_keyTotalSeconds, total + elapsedSeconds);
    await storage.setInt(_keyTodaySeconds, today + elapsedSeconds);
    await storage.setString(_keyTodayDate, todayKey);
  }

  Future<ReadingStatsSnapshot> loadStats() async {
    final storage = await StorageService.instance;
    final todayKey = _todayKey(DateTime.now());
    final lastDate = storage.readString(_keyTodayDate);
    final total = storage.readInt(_keyTotalSeconds) ?? 0;
    final today =
        lastDate == todayKey ? (storage.readInt(_keyTodaySeconds) ?? 0) : 0;

    if (lastDate != todayKey && (storage.readInt(_keyTodaySeconds) ?? 0) != 0) {
      await storage.setInt(_keyTodaySeconds, 0);
      await storage.setString(_keyTodayDate, todayKey);
    }

    return ReadingStatsSnapshot(
      totalSeconds: total,
      todaySeconds: today,
    );
  }

  String _todayKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
