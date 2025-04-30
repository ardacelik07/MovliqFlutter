import 'package:flutter/foundation.dart';

class ActivityStatsModel {
  // Alanları null olabilir yapalım
  final double? totalDistance;
  final double? avgDistancePerMinute;
  final int? totalSteps;
  final int? avgStepsPerMinute;

  const ActivityStatsModel({
    // Required kaldırıldı, null olabilirler
    this.totalDistance,
    this.avgDistancePerMinute,
    this.totalSteps,
    this.avgStepsPerMinute,
  });

  // Manual fromJson factory
  factory ActivityStatsModel.fromJson(Map<String, dynamic> json) {
    // API'den gelen değerleri güvenli bir şekilde ayrıştır
    // int veya double'a çevirmeyi dene, null veya hatalıysa null ata

    // Outdoor verileri (distance)
    final double? totalDistance =
        double.tryParse(json['totalDistance']?.toString() ?? '');
    final double? avgDistancePerMinute =
        double.tryParse(json['avgDistancePerMinute']?.toString() ?? '');

    // Indoor verileri (steps)
    final int? totalSteps = int.tryParse(json['totalSteps']?.toString() ?? '');
    final int? avgStepsPerMinute =
        int.tryParse(json['avgStepsPerMinute']?.toString() ?? '');

    return ActivityStatsModel(
      totalDistance: totalDistance,
      avgDistancePerMinute: avgDistancePerMinute,
      totalSteps: totalSteps,
      avgStepsPerMinute: avgStepsPerMinute,
    );
  }

  // Optional: Implement equality and hashCode if needed for comparison
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityStatsModel &&
          runtimeType == other.runtimeType &&
          totalDistance == other.totalDistance &&
          avgDistancePerMinute == other.avgDistancePerMinute &&
          totalSteps == other.totalSteps &&
          avgStepsPerMinute == other.avgStepsPerMinute;

  @override
  int get hashCode =>
      totalDistance.hashCode ^
      avgDistancePerMinute.hashCode ^
      totalSteps.hashCode ^
      avgStepsPerMinute.hashCode;

  // Optional: Implement toString for debugging
  @override
  String toString() {
    return 'ActivityStatsModel(totalDistance: $totalDistance, avgDistancePerMinute: $avgDistancePerMinute, totalSteps: $totalSteps, avgStepsPerMinute: $avgStepsPerMinute)';
  }
}
