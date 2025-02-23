class UserProfileModel {
  final String name;
  final String username;
  final DateTime birthDate;
  final String gender;
  final double height; // cm cinsinden
  final double weight; // kg cinsinden
  final String activityLevel;
  final String runningPreference;

  UserProfileModel({
    required this.name,
    required this.username,
    required this.birthDate,
    required this.gender,
    required this.height,
    required this.weight,
    required this.activityLevel,
    required this.runningPreference,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'username': username,
        'birthday': birthDate.toIso8601String(),
        'gender': gender,
        'height': height,
        'weight': weight,
        'active': _convertActivityLevel(activityLevel),
        'runPrefer': _convertRunningPreference(runningPreference),
        'age': _calculateAge(birthDate),
      };

  int _convertActivityLevel(String level) {
    switch (level.toLowerCase()) {
      case 'beginner':
        return 1;
      case 'intermediate':
        return 2;
      case 'advanced':
        return 3;
      default:
        return 1;
    }
  }

  int _convertRunningPreference(String preference) {
    switch (preference.toLowerCase()) {
      case 'outdoors':
        return 1;
      case 'gym':
        return 2;
      default:
        return 1;
    }
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}
