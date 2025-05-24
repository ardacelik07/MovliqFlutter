import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/record_service.dart';
import '../../domain/models/record_request_model.dart';

final recordServiceProvider = Provider<RecordService>((ref) {
  return RecordService();
});

final recordSubmissionProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, RecordRequestModel>((ref, request) async {
  final recordService = ref.read(recordServiceProvider);
  return await recordService.addUserRecord(request);
});

// Yeni Provider: Aktivite kaydı sonrası coin kazanma isteği için
final recordEarnCoinProvider =
    FutureProvider.autoDispose.family<double, double>((ref, distance) async {
  final recordService = ref.read(recordServiceProvider);
  // Mesafe 0 veya daha küçükse istek atmayı engelle (opsiyonel)
  if (distance <= 0) {
    print(
        "recordEarnCoinProvider: Mesafe 0 olduğu için coin kazanma isteği atlanıyor.");
    return 0.0;
  }
  print(
      "recordEarnCoinProvider: Coin kazanma isteği gönderiliyor - Mesafe: $distance");
  return await recordService.recordEarnCoin(distance);
});
