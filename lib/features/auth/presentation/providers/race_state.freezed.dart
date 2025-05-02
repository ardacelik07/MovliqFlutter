// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'race_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$RaceState {
// Yarışın genel durumu
  bool get isRaceActive => throw _privateConstructorUsedError;
  bool get isPreRaceCountdownActive => throw _privateConstructorUsedError;
  int get preRaceCountdownValue => throw _privateConstructorUsedError;
  int? get roomId => throw _privateConstructorUsedError;
  DateTime? get raceStartTime => throw _privateConstructorUsedError;
  Duration? get raceDuration =>
      throw _privateConstructorUsedError; // Toplam süre
  Duration get remainingTime =>
      throw _privateConstructorUsedError; // Kalan süre
  bool get isIndoorRace => throw _privateConstructorUsedError;
  bool get isRaceFinished =>
      throw _privateConstructorUsedError; // <-- Flag to indicate normal finish
  bool get hasLocationPermission =>
      throw _privateConstructorUsedError; // UI'da izin durumu göstermek için
  bool get hasPedometerPermission =>
      throw _privateConstructorUsedError; // UI'da izin durumu göstermek için
// Anlık yarış verileri
  double get currentDistance => throw _privateConstructorUsedError;
  int get currentSteps => throw _privateConstructorUsedError;
  int get initialSteps =>
      throw _privateConstructorUsedError; // Adım sayacı başlangıç değeri
  int get currentCalories =>
      throw _privateConstructorUsedError; // <-- Yeni kalori alanı
  String? get userEmail =>
      throw _privateConstructorUsedError; // Mevcut kullanıcının email'i
  List<RaceParticipant> get leaderboard => throw _privateConstructorUsedError;
  Map<String, String?> get profilePictureCache =>
      throw _privateConstructorUsedError; // <-- Add cache map
// Hile kontrolü
  int get violationCount => throw _privateConstructorUsedError;
  bool get showFirstCheatWarning =>
      throw _privateConstructorUsedError; // <-- İlk hile uyarısını göstermek için
// Hata durumu
  String? get errorMessage => throw _privateConstructorUsedError;

  /// Create a copy of RaceState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RaceStateCopyWith<RaceState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RaceStateCopyWith<$Res> {
  factory $RaceStateCopyWith(RaceState value, $Res Function(RaceState) then) =
      _$RaceStateCopyWithImpl<$Res, RaceState>;
  @useResult
  $Res call(
      {bool isRaceActive,
      bool isPreRaceCountdownActive,
      int preRaceCountdownValue,
      int? roomId,
      DateTime? raceStartTime,
      Duration? raceDuration,
      Duration remainingTime,
      bool isIndoorRace,
      bool isRaceFinished,
      bool hasLocationPermission,
      bool hasPedometerPermission,
      double currentDistance,
      int currentSteps,
      int initialSteps,
      int currentCalories,
      String? userEmail,
      List<RaceParticipant> leaderboard,
      Map<String, String?> profilePictureCache,
      int violationCount,
      bool showFirstCheatWarning,
      String? errorMessage});
}

/// @nodoc
class _$RaceStateCopyWithImpl<$Res, $Val extends RaceState>
    implements $RaceStateCopyWith<$Res> {
  _$RaceStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RaceState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isRaceActive = null,
    Object? isPreRaceCountdownActive = null,
    Object? preRaceCountdownValue = null,
    Object? roomId = freezed,
    Object? raceStartTime = freezed,
    Object? raceDuration = freezed,
    Object? remainingTime = null,
    Object? isIndoorRace = null,
    Object? isRaceFinished = null,
    Object? hasLocationPermission = null,
    Object? hasPedometerPermission = null,
    Object? currentDistance = null,
    Object? currentSteps = null,
    Object? initialSteps = null,
    Object? currentCalories = null,
    Object? userEmail = freezed,
    Object? leaderboard = null,
    Object? profilePictureCache = null,
    Object? violationCount = null,
    Object? showFirstCheatWarning = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_value.copyWith(
      isRaceActive: null == isRaceActive
          ? _value.isRaceActive
          : isRaceActive // ignore: cast_nullable_to_non_nullable
              as bool,
      isPreRaceCountdownActive: null == isPreRaceCountdownActive
          ? _value.isPreRaceCountdownActive
          : isPreRaceCountdownActive // ignore: cast_nullable_to_non_nullable
              as bool,
      preRaceCountdownValue: null == preRaceCountdownValue
          ? _value.preRaceCountdownValue
          : preRaceCountdownValue // ignore: cast_nullable_to_non_nullable
              as int,
      roomId: freezed == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as int?,
      raceStartTime: freezed == raceStartTime
          ? _value.raceStartTime
          : raceStartTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      raceDuration: freezed == raceDuration
          ? _value.raceDuration
          : raceDuration // ignore: cast_nullable_to_non_nullable
              as Duration?,
      remainingTime: null == remainingTime
          ? _value.remainingTime
          : remainingTime // ignore: cast_nullable_to_non_nullable
              as Duration,
      isIndoorRace: null == isIndoorRace
          ? _value.isIndoorRace
          : isIndoorRace // ignore: cast_nullable_to_non_nullable
              as bool,
      isRaceFinished: null == isRaceFinished
          ? _value.isRaceFinished
          : isRaceFinished // ignore: cast_nullable_to_non_nullable
              as bool,
      hasLocationPermission: null == hasLocationPermission
          ? _value.hasLocationPermission
          : hasLocationPermission // ignore: cast_nullable_to_non_nullable
              as bool,
      hasPedometerPermission: null == hasPedometerPermission
          ? _value.hasPedometerPermission
          : hasPedometerPermission // ignore: cast_nullable_to_non_nullable
              as bool,
      currentDistance: null == currentDistance
          ? _value.currentDistance
          : currentDistance // ignore: cast_nullable_to_non_nullable
              as double,
      currentSteps: null == currentSteps
          ? _value.currentSteps
          : currentSteps // ignore: cast_nullable_to_non_nullable
              as int,
      initialSteps: null == initialSteps
          ? _value.initialSteps
          : initialSteps // ignore: cast_nullable_to_non_nullable
              as int,
      currentCalories: null == currentCalories
          ? _value.currentCalories
          : currentCalories // ignore: cast_nullable_to_non_nullable
              as int,
      userEmail: freezed == userEmail
          ? _value.userEmail
          : userEmail // ignore: cast_nullable_to_non_nullable
              as String?,
      leaderboard: null == leaderboard
          ? _value.leaderboard
          : leaderboard // ignore: cast_nullable_to_non_nullable
              as List<RaceParticipant>,
      profilePictureCache: null == profilePictureCache
          ? _value.profilePictureCache
          : profilePictureCache // ignore: cast_nullable_to_non_nullable
              as Map<String, String?>,
      violationCount: null == violationCount
          ? _value.violationCount
          : violationCount // ignore: cast_nullable_to_non_nullable
              as int,
      showFirstCheatWarning: null == showFirstCheatWarning
          ? _value.showFirstCheatWarning
          : showFirstCheatWarning // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$RaceStateImplCopyWith<$Res>
    implements $RaceStateCopyWith<$Res> {
  factory _$$RaceStateImplCopyWith(
          _$RaceStateImpl value, $Res Function(_$RaceStateImpl) then) =
      __$$RaceStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool isRaceActive,
      bool isPreRaceCountdownActive,
      int preRaceCountdownValue,
      int? roomId,
      DateTime? raceStartTime,
      Duration? raceDuration,
      Duration remainingTime,
      bool isIndoorRace,
      bool isRaceFinished,
      bool hasLocationPermission,
      bool hasPedometerPermission,
      double currentDistance,
      int currentSteps,
      int initialSteps,
      int currentCalories,
      String? userEmail,
      List<RaceParticipant> leaderboard,
      Map<String, String?> profilePictureCache,
      int violationCount,
      bool showFirstCheatWarning,
      String? errorMessage});
}

/// @nodoc
class __$$RaceStateImplCopyWithImpl<$Res>
    extends _$RaceStateCopyWithImpl<$Res, _$RaceStateImpl>
    implements _$$RaceStateImplCopyWith<$Res> {
  __$$RaceStateImplCopyWithImpl(
      _$RaceStateImpl _value, $Res Function(_$RaceStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of RaceState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isRaceActive = null,
    Object? isPreRaceCountdownActive = null,
    Object? preRaceCountdownValue = null,
    Object? roomId = freezed,
    Object? raceStartTime = freezed,
    Object? raceDuration = freezed,
    Object? remainingTime = null,
    Object? isIndoorRace = null,
    Object? isRaceFinished = null,
    Object? hasLocationPermission = null,
    Object? hasPedometerPermission = null,
    Object? currentDistance = null,
    Object? currentSteps = null,
    Object? initialSteps = null,
    Object? currentCalories = null,
    Object? userEmail = freezed,
    Object? leaderboard = null,
    Object? profilePictureCache = null,
    Object? violationCount = null,
    Object? showFirstCheatWarning = null,
    Object? errorMessage = freezed,
  }) {
    return _then(_$RaceStateImpl(
      isRaceActive: null == isRaceActive
          ? _value.isRaceActive
          : isRaceActive // ignore: cast_nullable_to_non_nullable
              as bool,
      isPreRaceCountdownActive: null == isPreRaceCountdownActive
          ? _value.isPreRaceCountdownActive
          : isPreRaceCountdownActive // ignore: cast_nullable_to_non_nullable
              as bool,
      preRaceCountdownValue: null == preRaceCountdownValue
          ? _value.preRaceCountdownValue
          : preRaceCountdownValue // ignore: cast_nullable_to_non_nullable
              as int,
      roomId: freezed == roomId
          ? _value.roomId
          : roomId // ignore: cast_nullable_to_non_nullable
              as int?,
      raceStartTime: freezed == raceStartTime
          ? _value.raceStartTime
          : raceStartTime // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      raceDuration: freezed == raceDuration
          ? _value.raceDuration
          : raceDuration // ignore: cast_nullable_to_non_nullable
              as Duration?,
      remainingTime: null == remainingTime
          ? _value.remainingTime
          : remainingTime // ignore: cast_nullable_to_non_nullable
              as Duration,
      isIndoorRace: null == isIndoorRace
          ? _value.isIndoorRace
          : isIndoorRace // ignore: cast_nullable_to_non_nullable
              as bool,
      isRaceFinished: null == isRaceFinished
          ? _value.isRaceFinished
          : isRaceFinished // ignore: cast_nullable_to_non_nullable
              as bool,
      hasLocationPermission: null == hasLocationPermission
          ? _value.hasLocationPermission
          : hasLocationPermission // ignore: cast_nullable_to_non_nullable
              as bool,
      hasPedometerPermission: null == hasPedometerPermission
          ? _value.hasPedometerPermission
          : hasPedometerPermission // ignore: cast_nullable_to_non_nullable
              as bool,
      currentDistance: null == currentDistance
          ? _value.currentDistance
          : currentDistance // ignore: cast_nullable_to_non_nullable
              as double,
      currentSteps: null == currentSteps
          ? _value.currentSteps
          : currentSteps // ignore: cast_nullable_to_non_nullable
              as int,
      initialSteps: null == initialSteps
          ? _value.initialSteps
          : initialSteps // ignore: cast_nullable_to_non_nullable
              as int,
      currentCalories: null == currentCalories
          ? _value.currentCalories
          : currentCalories // ignore: cast_nullable_to_non_nullable
              as int,
      userEmail: freezed == userEmail
          ? _value.userEmail
          : userEmail // ignore: cast_nullable_to_non_nullable
              as String?,
      leaderboard: null == leaderboard
          ? _value._leaderboard
          : leaderboard // ignore: cast_nullable_to_non_nullable
              as List<RaceParticipant>,
      profilePictureCache: null == profilePictureCache
          ? _value._profilePictureCache
          : profilePictureCache // ignore: cast_nullable_to_non_nullable
              as Map<String, String?>,
      violationCount: null == violationCount
          ? _value.violationCount
          : violationCount // ignore: cast_nullable_to_non_nullable
              as int,
      showFirstCheatWarning: null == showFirstCheatWarning
          ? _value.showFirstCheatWarning
          : showFirstCheatWarning // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _value.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$RaceStateImpl implements _RaceState {
  const _$RaceStateImpl(
      {this.isRaceActive = false,
      this.isPreRaceCountdownActive = false,
      this.preRaceCountdownValue = 0,
      this.roomId = null,
      this.raceStartTime = null,
      this.raceDuration = null,
      this.remainingTime = Duration.zero,
      this.isIndoorRace = false,
      this.isRaceFinished = false,
      this.hasLocationPermission = false,
      this.hasPedometerPermission = false,
      this.currentDistance = 0.0,
      this.currentSteps = 0,
      this.initialSteps = 0,
      this.currentCalories = 0,
      this.userEmail = null,
      final List<RaceParticipant> leaderboard = const [],
      final Map<String, String?> profilePictureCache = const {},
      this.violationCount = 0,
      this.showFirstCheatWarning = false,
      this.errorMessage = null})
      : _leaderboard = leaderboard,
        _profilePictureCache = profilePictureCache;

// Yarışın genel durumu
  @override
  @JsonKey()
  final bool isRaceActive;
  @override
  @JsonKey()
  final bool isPreRaceCountdownActive;
  @override
  @JsonKey()
  final int preRaceCountdownValue;
  @override
  @JsonKey()
  final int? roomId;
  @override
  @JsonKey()
  final DateTime? raceStartTime;
  @override
  @JsonKey()
  final Duration? raceDuration;
// Toplam süre
  @override
  @JsonKey()
  final Duration remainingTime;
// Kalan süre
  @override
  @JsonKey()
  final bool isIndoorRace;
  @override
  @JsonKey()
  final bool isRaceFinished;
// <-- Flag to indicate normal finish
  @override
  @JsonKey()
  final bool hasLocationPermission;
// UI'da izin durumu göstermek için
  @override
  @JsonKey()
  final bool hasPedometerPermission;
// UI'da izin durumu göstermek için
// Anlık yarış verileri
  @override
  @JsonKey()
  final double currentDistance;
  @override
  @JsonKey()
  final int currentSteps;
  @override
  @JsonKey()
  final int initialSteps;
// Adım sayacı başlangıç değeri
  @override
  @JsonKey()
  final int currentCalories;
// <-- Yeni kalori alanı
  @override
  @JsonKey()
  final String? userEmail;
// Mevcut kullanıcının email'i
  final List<RaceParticipant> _leaderboard;
// Mevcut kullanıcının email'i
  @override
  @JsonKey()
  List<RaceParticipant> get leaderboard {
    if (_leaderboard is EqualUnmodifiableListView) return _leaderboard;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_leaderboard);
  }

  final Map<String, String?> _profilePictureCache;
  @override
  @JsonKey()
  Map<String, String?> get profilePictureCache {
    if (_profilePictureCache is EqualUnmodifiableMapView)
      return _profilePictureCache;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_profilePictureCache);
  }

// <-- Add cache map
// Hile kontrolü
  @override
  @JsonKey()
  final int violationCount;
  @override
  @JsonKey()
  final bool showFirstCheatWarning;
// <-- İlk hile uyarısını göstermek için
// Hata durumu
  @override
  @JsonKey()
  final String? errorMessage;

  @override
  String toString() {
    return 'RaceState(isRaceActive: $isRaceActive, isPreRaceCountdownActive: $isPreRaceCountdownActive, preRaceCountdownValue: $preRaceCountdownValue, roomId: $roomId, raceStartTime: $raceStartTime, raceDuration: $raceDuration, remainingTime: $remainingTime, isIndoorRace: $isIndoorRace, isRaceFinished: $isRaceFinished, hasLocationPermission: $hasLocationPermission, hasPedometerPermission: $hasPedometerPermission, currentDistance: $currentDistance, currentSteps: $currentSteps, initialSteps: $initialSteps, currentCalories: $currentCalories, userEmail: $userEmail, leaderboard: $leaderboard, profilePictureCache: $profilePictureCache, violationCount: $violationCount, showFirstCheatWarning: $showFirstCheatWarning, errorMessage: $errorMessage)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RaceStateImpl &&
            (identical(other.isRaceActive, isRaceActive) ||
                other.isRaceActive == isRaceActive) &&
            (identical(
                    other.isPreRaceCountdownActive, isPreRaceCountdownActive) ||
                other.isPreRaceCountdownActive == isPreRaceCountdownActive) &&
            (identical(other.preRaceCountdownValue, preRaceCountdownValue) ||
                other.preRaceCountdownValue == preRaceCountdownValue) &&
            (identical(other.roomId, roomId) || other.roomId == roomId) &&
            (identical(other.raceStartTime, raceStartTime) ||
                other.raceStartTime == raceStartTime) &&
            (identical(other.raceDuration, raceDuration) ||
                other.raceDuration == raceDuration) &&
            (identical(other.remainingTime, remainingTime) ||
                other.remainingTime == remainingTime) &&
            (identical(other.isIndoorRace, isIndoorRace) ||
                other.isIndoorRace == isIndoorRace) &&
            (identical(other.isRaceFinished, isRaceFinished) ||
                other.isRaceFinished == isRaceFinished) &&
            (identical(other.hasLocationPermission, hasLocationPermission) ||
                other.hasLocationPermission == hasLocationPermission) &&
            (identical(other.hasPedometerPermission, hasPedometerPermission) ||
                other.hasPedometerPermission == hasPedometerPermission) &&
            (identical(other.currentDistance, currentDistance) ||
                other.currentDistance == currentDistance) &&
            (identical(other.currentSteps, currentSteps) ||
                other.currentSteps == currentSteps) &&
            (identical(other.initialSteps, initialSteps) ||
                other.initialSteps == initialSteps) &&
            (identical(other.currentCalories, currentCalories) ||
                other.currentCalories == currentCalories) &&
            (identical(other.userEmail, userEmail) ||
                other.userEmail == userEmail) &&
            const DeepCollectionEquality()
                .equals(other._leaderboard, _leaderboard) &&
            const DeepCollectionEquality()
                .equals(other._profilePictureCache, _profilePictureCache) &&
            (identical(other.violationCount, violationCount) ||
                other.violationCount == violationCount) &&
            (identical(other.showFirstCheatWarning, showFirstCheatWarning) ||
                other.showFirstCheatWarning == showFirstCheatWarning) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        isRaceActive,
        isPreRaceCountdownActive,
        preRaceCountdownValue,
        roomId,
        raceStartTime,
        raceDuration,
        remainingTime,
        isIndoorRace,
        isRaceFinished,
        hasLocationPermission,
        hasPedometerPermission,
        currentDistance,
        currentSteps,
        initialSteps,
        currentCalories,
        userEmail,
        const DeepCollectionEquality().hash(_leaderboard),
        const DeepCollectionEquality().hash(_profilePictureCache),
        violationCount,
        showFirstCheatWarning,
        errorMessage
      ]);

  /// Create a copy of RaceState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RaceStateImplCopyWith<_$RaceStateImpl> get copyWith =>
      __$$RaceStateImplCopyWithImpl<_$RaceStateImpl>(this, _$identity);
}

abstract class _RaceState implements RaceState {
  const factory _RaceState(
      {final bool isRaceActive,
      final bool isPreRaceCountdownActive,
      final int preRaceCountdownValue,
      final int? roomId,
      final DateTime? raceStartTime,
      final Duration? raceDuration,
      final Duration remainingTime,
      final bool isIndoorRace,
      final bool isRaceFinished,
      final bool hasLocationPermission,
      final bool hasPedometerPermission,
      final double currentDistance,
      final int currentSteps,
      final int initialSteps,
      final int currentCalories,
      final String? userEmail,
      final List<RaceParticipant> leaderboard,
      final Map<String, String?> profilePictureCache,
      final int violationCount,
      final bool showFirstCheatWarning,
      final String? errorMessage}) = _$RaceStateImpl;

// Yarışın genel durumu
  @override
  bool get isRaceActive;
  @override
  bool get isPreRaceCountdownActive;
  @override
  int get preRaceCountdownValue;
  @override
  int? get roomId;
  @override
  DateTime? get raceStartTime;
  @override
  Duration? get raceDuration; // Toplam süre
  @override
  Duration get remainingTime; // Kalan süre
  @override
  bool get isIndoorRace;
  @override
  bool get isRaceFinished; // <-- Flag to indicate normal finish
  @override
  bool get hasLocationPermission; // UI'da izin durumu göstermek için
  @override
  bool get hasPedometerPermission; // UI'da izin durumu göstermek için
// Anlık yarış verileri
  @override
  double get currentDistance;
  @override
  int get currentSteps;
  @override
  int get initialSteps; // Adım sayacı başlangıç değeri
  @override
  int get currentCalories; // <-- Yeni kalori alanı
  @override
  String? get userEmail; // Mevcut kullanıcının email'i
  @override
  List<RaceParticipant> get leaderboard;
  @override
  Map<String, String?> get profilePictureCache; // <-- Add cache map
// Hile kontrolü
  @override
  int get violationCount;
  @override
  bool get showFirstCheatWarning; // <-- İlk hile uyarısını göstermek için
// Hata durumu
  @override
  String? get errorMessage;

  /// Create a copy of RaceState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RaceStateImplCopyWith<_$RaceStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
