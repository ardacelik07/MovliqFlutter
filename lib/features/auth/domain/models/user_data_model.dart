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
  final int? coins;

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
    this.coins,
  });

  // copyWith metodu
  UserDataModel copyWith({
    int? id,
    String? name,
    String? surname,
    String? userName,
    String? email,
    String? phoneNumber,
    String? address,
    int? age,
    double? height,
    double? weight,
    String? gender,
    String? profilePicturePath,
    int? runprefer,
    int? active,
    bool? isActive,
    double? distancekm,
    double? steps,
    int? rank,
    int? generalRank,
    DateTime? birthday,
    DateTime? createdAt,
    int? coins,
  }) {
    return UserDataModel(
      id: id ?? this.id,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      userName: userName ?? this.userName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      age: age ?? this.age,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      gender: gender ?? this.gender,
      profilePicturePath: profilePicturePath ?? this.profilePicturePath,
      runprefer: runprefer ?? this.runprefer,
      active: active ?? this.active,
      isActive: isActive ?? this.isActive,
      distancekm: distancekm ?? this.distancekm,
      steps: steps ?? this.steps,
      rank: rank ?? this.rank,
      generalRank: generalRank ?? this.generalRank,
      birthday: birthday ?? this.birthday,
      createdAt: createdAt ?? this.createdAt,
      coins: coins ?? this.coins,
    );
  }

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
      coins: json['coins'] ?? 0,
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
