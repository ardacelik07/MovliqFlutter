import 'package:flutter/foundation.dart';

class ActivityStatsModel {
  final double totalDistance;
  final double avgDistancePerMinute;

  const ActivityStatsModel({
    required this.totalDistance,
    required this.avgDistancePerMinute,
  });

  // Manual fromJson factory
  factory ActivityStatsModel.fromJson(Map<String, dynamic> json) {
    // API'den gelen string değerleri double'a çevir, null veya hatalıysa 0.0 kullan
    // JSON anahtarlarını API yanıtına göre düzelt (camelCase)
    final double totalDistance =
        double.tryParse(json['totalDistance']?.toString() ?? '0.0') ?? 0.0;
    final double avgDistancePerMinute =
        double.tryParse(json['avgDistancePerMinute']?.toString() ?? '0.0') ??
            0.0;

    return ActivityStatsModel(
      totalDistance: totalDistance,
      avgDistancePerMinute: avgDistancePerMinute,
    );
  }

  // Optional: Implement equality and hashCode if needed for comparison
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityStatsModel &&
          runtimeType == other.runtimeType &&
          totalDistance == other.totalDistance &&
          avgDistancePerMinute == other.avgDistancePerMinute;

  @override
  int get hashCode => totalDistance.hashCode ^ avgDistancePerMinute.hashCode;

  // Optional: Implement toString for debugging
  @override
  String toString() {
    return 'ActivityStatsModel(totalDistance: $totalDistance, avgDistancePerMinute: $avgDistancePerMinute)';
  }
}
