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
