import 'package:equatable/equatable.dart'; // Equality için Equatable kullanalım

// Katılımcı modelini buraya taşıyalım veya ayrı bir dosyadan import edelim
class RaceParticipant extends Equatable {
  final String email; // Veya userId?
  final String userName;
  final double distance; // Sunucudan gelen birim (km veya m?)
  final int steps;
  final int rank;
  // final String? profilePictureUrl; // Profil resmi URL'si gerekebilir

  const RaceParticipant({
    required this.email,
    required this.userName,
    required this.distance,
    required this.steps,
    required this.rank,
    // this.profilePictureUrl,
  });

  // Native taraftan gelen Map'ten veya Backend'den gelen Map'ten parse etmek için factory constructor
  factory RaceParticipant.fromJson(Map<String, dynamic> json) {
    // Anahtarların Native ve Backend'den gelenlerle EŞLEŞTİĞİNDEN EMİN OLUN!
    // Backend'den büyük harfle (Distance, Steps), Native'den küçük harfle (distanceKm, steps) gelebilir.
    return RaceParticipant(
      // Email ve UserName genellikle tutarlıdır
      email: json['email'] as String? ?? json['Email'] as String? ?? '',
      userName: json['userName'] as String? ??
          json['UserName'] as String? ??
          'Bilinmiyor',

      // Mesafe: Önce 'Distance' (Backend), sonra 'distanceKm' (Native), sonra 'distance' (Eski Native?)
      distance: (json['Distance'] as num? ?? // Backend'den gelen büyük harfli
              json['distanceKm']
                  as num? ?? // Native servisten gelen küçük harfli
              json['distance'] as num? ?? // Eski/Diğer ihtimal
              0.0)
          .toDouble(),

      // Adım: Önce 'Steps' (Backend), sonra 'steps' (Native)
      steps: json['Steps'] as int? ?? // Backend'den gelen büyük harfli
          json['steps'] as int? ?? // Native servisten gelen küçük harfli
          0,

      // Rank genellikle tutarlıdır
      rank: json['rank'] as int? ?? json['Rank'] as int? ?? 0,

      // profilePictureUrl: json['profilePictureUrl'] as String?,
    );
  }

  @override
  List<Object?> get props => [email, userName, distance, steps, rank];

  @override
  bool get stringify => true;
}

enum RaceStatus { idle, starting, running, paused, stopped, error }

// Freezed yerine manuel sınıf
class RaceState extends Equatable {
  final RaceStatus status;
  final int elapsedSeconds;
  final int? remainingSeconds; // Nullable for non-timed races
  final double distanceKm;
  final int steps;
  final double speedKmh; // Hız km/h
  final String? errorMessage;
  final List<RaceParticipant> leaderboard; // Liderlik tablosu eklendi

  const RaceState({
    this.status = RaceStatus.idle,
    this.elapsedSeconds = 0,
    this.remainingSeconds,
    this.distanceKm = 0.0,
    this.steps = 0,
    this.speedKmh = 0.0,
    this.errorMessage,
    this.leaderboard = const [], // Başlangıçta boş liste
  });

  // copyWith metodu
  RaceState copyWith({
    RaceStatus? status,
    int? elapsedSeconds,
    int? remainingSeconds,
    bool forceRemainingNull = false, // remainingSeconds'ı null yapmak için
    double? distanceKm,
    int? steps,
    double? speedKmh,
    String? errorMessage,
    bool forceErrorNull = false, // errorMessage'ı null yapmak için
    List<RaceParticipant>? leaderboard, // copyWith'e eklendi
  }) {
    return RaceState(
      status: status ?? this.status,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      remainingSeconds: forceRemainingNull
          ? null
          : (remainingSeconds ?? this.remainingSeconds),
      distanceKm: distanceKm ?? this.distanceKm,
      steps: steps ?? this.steps,
      speedKmh: speedKmh ?? this.speedKmh,
      errorMessage: forceErrorNull ? null : (errorMessage ?? this.errorMessage),
      leaderboard: leaderboard ?? this.leaderboard, // leaderboard güncellendi
    );
  }

  // Equatable için props listesi
  @override
  List<Object?> get props => [
        status,
        elapsedSeconds,
        remainingSeconds,
        distanceKm,
        steps,
        speedKmh,
        errorMessage,
        leaderboard, // props'a eklendi
      ];

  // toString metodu (debug için)
  @override
  bool get stringify => true;
}
