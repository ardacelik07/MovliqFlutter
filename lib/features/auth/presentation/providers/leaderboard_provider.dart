import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:riverpod_annotation/riverpod_annotation.dart'; // Remove this

import '../../../../core/services/leaderboard_service.dart';
import '../../domain/models/leaderboard_model.dart';

// part 'leaderboard_provider.g.dart'; // Remove this line

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

// NEW: Standard FutureProvider definition for user leaderboard entry
final userLeaderboardEntryProvider =
    FutureProvider.autoDispose<UserLeaderboardEntryDto?>((ref) async {
  final bool isOutdoor = ref.watch(isOutdoorSelectedProvider);
  final String leaderboardType = isOutdoor ? 'outdoor' : 'indoor';

  // Use the service provider if defined, otherwise instantiate directly
  // final leaderboardService = ref.watch(leaderboardServiceProvider);
  final leaderboardService =
      LeaderboardService(); // Assuming direct instantiation is ok

  final result = await leaderboardService.getLeaderboardByUser(leaderboardType);
  return result;
});
