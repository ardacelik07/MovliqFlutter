import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/leaderboard_service.dart';
import '../../domain/models/user_ranks_model.dart';

final userRanksProvider = FutureProvider<UserRanksModel>((ref) async {
  try {
    final leaderboardService = LeaderboardService();
    final response = await leaderboardService.getUserLeaderboardRanks();
    return UserRanksModel.fromJson(response);
  } catch (e) {
    // Hata durumunda varsayılan değerlerle model döndür
    return UserRanksModel(indoorRank: 0, outdoorRank: 0);
  }
});
