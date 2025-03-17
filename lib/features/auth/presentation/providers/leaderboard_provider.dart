import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/leaderboard_service.dart';
import '../../domain/models/leaderboard_model.dart';

final leaderboardServiceProvider = Provider<LeaderboardService>((ref) {
  return LeaderboardService();
});

// Normal, non-auto-dispose sürümleri
final indoorLeaderboardProvider =
    FutureProvider<List<LeaderboardIndoorDto>>((ref) async {
  final leaderboardService = ref.watch(leaderboardServiceProvider);
  return await leaderboardService.getIndoorLeaderboard();
});

final outdoorLeaderboardProvider =
    FutureProvider<List<LeaderboardOutdoorDto>>((ref) async {
  final leaderboardService = ref.watch(leaderboardServiceProvider);
  return await leaderboardService.getOutdoorLeaderboard();
});

// Provider for toggling between indoor and outdoor leaderboard
final isOutdoorSelectedProvider = StateProvider<bool>((ref) => true);
