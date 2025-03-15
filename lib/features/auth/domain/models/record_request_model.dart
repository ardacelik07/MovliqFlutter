class RecordRequestModel {
  final int? duration;
  final double? distance;
  final int? calories;
  final double steps;
  final int? averageSpeed;
  final DateTime? startTime;

  RecordRequestModel({
    this.duration,
    this.distance,
    this.calories,
    required this.steps,
    this.averageSpeed,
    this.startTime,
  });

  Map<String, dynamic> toJson() => {
        'duration': duration,
        'distance': distance,
        'calories': calories,
        'steps': steps,
        'averageSpeed': averageSpeed,
        'startTime': startTime?.toIso8601String(),
      };
}
