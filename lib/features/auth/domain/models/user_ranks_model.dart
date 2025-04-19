class UserRanksModel {
  final int indoorRank;
  final int outdoorRank;

  UserRanksModel({
    required this.indoorRank,
    required this.outdoorRank,
  });

  factory UserRanksModel.fromJson(Map<String, dynamic> json) {
    return UserRanksModel(
      indoorRank: json['indoorRank'] ?? 0,
      outdoorRank: json['outdoorRank'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'indoorRank': indoorRank,
      'outdoorRank': outdoorRank,
    };
  }
}
