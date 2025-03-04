import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import 'storage_service.dart';

final signalRServiceProvider = Provider<SignalRService>((ref) {
  return SignalRService();
});

class RaceParticipant {
  final String email;
  final String userName;
  final double distance;
  final int steps;
  final int rank;

  RaceParticipant({
    required this.email,
    required this.userName,
    required this.distance,
    required this.steps,
    required this.rank,
  });

  factory RaceParticipant.fromJson(Map<String, dynamic> json) {
    return RaceParticipant(
      email: json['email'] as String,
      userName: json['userName'] as String,
      distance: (json['distance'] as num).toDouble(),
      steps: json['steps'] as int,
      rank: json['rank'] as int,
    );
  }
}

class SignalRService {
  HubConnection? _hubConnection;
  bool _isConnected = false;

  // Stream controllers
  final StreamController<List<RaceParticipant>> _leaderboardController =
      StreamController<List<RaceParticipant>>.broadcast();
  final StreamController<bool> _raceStartedController =
      StreamController<bool>.broadcast();
  final StreamController<int> _raceEndedController =
      StreamController<int>.broadcast();
  final StreamController<String> _userJoinedController =
      StreamController<String>.broadcast();
  final StreamController<String> _userLeftController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _locationUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _raceStartingController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Stream getters
  Stream<List<RaceParticipant>> get leaderboardStream =>
      _leaderboardController.stream;
  Stream<bool> get raceStartedStream => _raceStartedController.stream;
  Stream<int> get raceEndedStream => _raceEndedController.stream;
  Stream<String> get userJoinedStream => _userJoinedController.stream;
  Stream<String> get userLeftStream => _userLeftController.stream;
  Stream<Map<String, dynamic>> get locationUpdatedStream =>
      _locationUpdatedController.stream;
  Stream<Map<String, dynamic>> get raceStartingStream =>
      _raceStartingController.stream;

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected) return;

    final tokenJson = await StorageService.getToken();
    if (tokenJson == null) {
      throw Exception('Authentication token not found');
    }

    final Map<String, dynamic> tokenData = jsonDecode(tokenJson);
    final String token = tokenData['token'];

    try {
      // Hub URL oluşturma - API_Config'deki baseUrl'i kullanarak SignalR hub URL'ini oluştur
      final hubUrl = 'http://10.0.2.2:5041/racehub';

      // Hub bağlantısını başlat
      _hubConnection = HubConnectionBuilder()
          .withUrl(hubUrl,
              options: HttpConnectionOptions(
                accessTokenFactory: () async => token,
              ))
          .withAutomaticReconnect()
          .build();

      // Event handlers for all hub events
      _hubConnection!.on('LeaderboardUpdated', _handleLeaderboardUpdated);
      _hubConnection!.on('RaceStarting', _handleRaceStarting);
      _hubConnection!.on('RaceEnded', _handleRaceEnded);
      _hubConnection!.on('UserJoined', _handleUserJoined);
      _hubConnection!.on('UserLeft', _handleUserLeft);
      _hubConnection!.on('LocationUpdated', _handleLocationUpdated);

      // Hub bağlantısını başlat
      await _hubConnection!.start();
      _isConnected = true;

      debugPrint('SignalR bağlantısı başarıyla kuruldu');
    } catch (e) {
      _isConnected = false;
      debugPrint('SignalR bağlantı hatası: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (_hubConnection != null) {
      await _hubConnection!.stop();
      _isConnected = false;
      debugPrint('SignalR bağlantısı kapatıldı');
    }
  }

  // Odaya katılmak için metod
  Future<void> joinRaceRoom(int roomId) async {
    if (_hubConnection == null || !_isConnected) {
      await connect();
    }

    try {
      await _hubConnection!.invoke('JoinRoom', args: [roomId]);
      debugPrint('Yarış odasına katılındı: $roomId');
    } catch (e) {
      debugPrint('Yarış odasına katılma hatası: $e');
      rethrow;
    }
  }

  // Odadan ayrılmak için metod
  Future<void> leaveRaceRoom(int roomId) async {
    if (_hubConnection == null || !_isConnected) return;

    try {
      await _hubConnection!.invoke('LeaveRoom', args: [roomId]);
      debugPrint('Yarış odasından ayrılındı: $roomId');
    } catch (e) {
      debugPrint('Yarış odasından ayrılma hatası: $e');
    }
  }

  // Konum güncellemek için metod
  Future<void> updateLocation(int roomId, double distance, int steps) async {
    if (_hubConnection == null || !_isConnected) return;

    try {
      await _hubConnection!
          .invoke('UpdateLocation', args: [roomId, distance, steps]);
      debugPrint('Konum güncellendi: $distance m, $steps adım');
    } catch (e) {
      debugPrint('Konum güncelleme hatası: $e');
    }
  }

  // Liderlik tablosu güncellemelerini işleyen metod
  void _handleLeaderboardUpdated(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) return;

    try {
      final List<dynamic> leaderboardData = arguments[0] as List<dynamic>;
      final participants = leaderboardData
          .map((item) => RaceParticipant.fromJson(item as Map<String, dynamic>))
          .toList();

      _leaderboardController.add(participants);
      debugPrint(
          'Liderlik tablosu güncellendi: ${participants.length} katılımcı');
    } catch (e) {
      debugPrint('Liderlik tablosu işleme hatası: $e');
    }
  }

  // Yarış başlayacak olayını işleyen metod
  void _handleRaceStarting(List<Object?>? arguments) {
    if (arguments == null || arguments.length < 2) return;

    try {
      final int roomId = arguments[0] as int;
      final int countdownSeconds = arguments[1] as int;

      _raceStartingController.add({
        'roomId': roomId,
        'countdownSeconds': countdownSeconds,
      });

      debugPrint(
          'Yarış başlıyor! Oda: $roomId, Kalan süre: $countdownSeconds saniye');
    } catch (e) {
      debugPrint('Yarış başlama olayı işleme hatası: $e');
    }
  }

  // Yarışın bittiğini işleyen metod
  void _handleRaceEnded(List<Object?>? arguments) {
    debugPrint(
        'SignalR: RaceEnded olayı alındı: ${arguments?.toString() ?? "null"}');

    if (arguments == null || arguments.isEmpty) {
      debugPrint(
          'SignalR: RaceEnded olayı boş argümanlarla geldi, varsayılan oda ID (0) kullanılacak');
      // Boş argüman gelse bile olayı tetikle (varsayılan oda ID 0)
      _raceEndedController.add(0);
      return;
    }

    try {
      final int roomId = arguments[0] as int;
      _raceEndedController.add(roomId);
      debugPrint('SignalR: Yarış bitti! Oda ID: $roomId');
    } catch (e) {
      debugPrint('SignalR: Yarış bitme olayı işleme hatası: $e');
      // Hata olsa bile olayı tetikle (varsayılan oda ID)
      _raceEndedController.add(0);
    }
  }

  // Kullanıcı katıldı olayını işleyen metod
  void _handleUserJoined(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) return;

    try {
      final String username = arguments[0] as String;
      _userJoinedController.add(username);
      debugPrint('Kullanıcı katıldı: $username');
    } catch (e) {
      debugPrint('Kullanıcı katılma olayı işleme hatası: $e');
    }
  }

  // Kullanıcı ayrıldı olayını işleyen metod
  void _handleUserLeft(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) return;

    try {
      final String username = arguments[0] as String;
      _userLeftController.add(username);
      debugPrint('Kullanıcı ayrıldı: $username');
    } catch (e) {
      debugPrint('Kullanıcı ayrılma olayı işleme hatası: $e');
    }
  }

  // Konum güncellendi olayını işleyen metod
  void _handleLocationUpdated(List<Object?>? arguments) {
    if (arguments == null || arguments.length < 3) return;

    try {
      final String email = arguments[0] as String;
      final double distance = (arguments[1] as num).toDouble();
      final int steps = arguments[2] as int;

      _locationUpdatedController.add({
        'email': email,
        'distance': distance,
        'steps': steps,
      });

      debugPrint('Konum güncellendi: $email, $distance m, $steps adım');
    } catch (e) {
      debugPrint('Konum güncelleme olayı işleme hatası: $e');
    }
  }

  // Servis dispose edildiğinde kaynakları temizle
  void dispose() {
    disconnect();
    _leaderboardController.close();
    _raceStartedController.close();
    _raceEndedController.close();
    _userJoinedController.close();
    _userLeftController.close();
    _locationUpdatedController.close();
    _raceStartingController.close();
  }
}
