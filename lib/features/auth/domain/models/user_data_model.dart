class UserDataModel {
  final int? id;
  final String? name;
  final String? surname;
  final String? userName;
  final String email;
  final String? phoneNumber;
  final String? address;
  final int? age;
  final double? height;
  final double? weight;
  final String? gender;
  final String? profilePicturePath;
  final int? runprefer;
  final int? active;
  final bool isActive;
  final double? distancekm;
  final double? steps;
  final int? rank;
  final int? generalRank;
  final DateTime? birthday;
  final DateTime? createdAt;

  UserDataModel({
    this.id,
    this.name,
    this.surname = '',
    this.userName,
    required this.email,
    this.phoneNumber,
    this.address,
    this.age,
    this.height,
    this.weight,
    this.gender,
    this.profilePicturePath,
    this.runprefer,
    this.active,
    this.isActive = true,
    this.distancekm,
    this.steps,
    this.rank,
    this.generalRank,
    this.birthday,
    this.createdAt,
  });

  factory UserDataModel.fromJson(Map<String, dynamic> json) {
    return UserDataModel(
      id: json['id'],
      name: json['name'],
      surname: json['surname'],
      userName: json['userName'],
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'],
      address: json['address'],
      age: json['age'],
      height: json['height']?.toDouble(),
      weight: json['weight']?.toDouble(),
      gender: json['gender'],
      profilePicturePath: json['profilePictureUrl'],
      runprefer: json['runPrefer'],
      active: json['active'],
      isActive: json['isActive'] == true || json['isActive'] == 1,
      distancekm: json['distancekm']?.toDouble(),
      steps: json['steps']?.toDouble(),
      rank: json['rank'],
      generalRank: json['generalRank'],
      birthday:
          json['birthDay'] != null ? DateTime.parse(json['birthDay']) : null,
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  // Kullanıcı dostu getter metodları
  String get fullName => '${name ?? ''} ${surname ?? ''}'.trim();

  String get runningPreference {
    if (runprefer == null) return 'Belirlenmemiş';
    return runprefer == 1 ? 'Outdoors' : 'Gym';
  }

  String get activityLevel {
    if (active == null) return 'Belirlenmemiş';
    return active == 1 ? 'Active' : 'Beginner';
  }

  // profilePictureUrl getter metodu (UI kodu uyumsuzluğunu önlemek için)
  String? get profilePictureUrl => profilePicturePath;
}
