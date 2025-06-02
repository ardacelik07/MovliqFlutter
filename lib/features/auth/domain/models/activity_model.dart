class ActivityModel {
  final int id;
  final int userId;
  final String userName;
  final String email;
  final double distancekm;
  final int steps;
  final DateTime startTime;
  final String roomType;
  final int duration;
  final int? calories;
  final int? avarageSpeed;

  ActivityModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.email,
    required this.distancekm,
    required this.steps,
    required this.startTime,
    required this.roomType,
    required this.duration,
    this.calories,
    this.avarageSpeed,
  });

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id'],
      userId: json['userId'],
      userName: json['userName'],
      email: json['email'],
      distancekm: json['distancekm']?.toDouble() ?? 0.0,
      steps: json['steps'] ?? 0,
      startTime: DateTime.parse(json['startTime']),
      roomType: json['roomType'],
      duration: json['duration'] ?? 0,
      calories: json['calories'],
      avarageSpeed: json['avarageSpeed'],
    );
  }
}
