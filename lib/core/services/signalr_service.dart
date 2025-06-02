import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import 'storage_service.dart';
import '../../features/auth/domain/models/room_participant.dart';
import 'package:signalr_netcore/iretry_policy.dart'; // IRetryPolicy için import

// --- YENİ: Özel Yeniden Deneme Politikası ---
class ContinuousRetryPolicy implements IRetryPolicy {
  final int retryIntervalMilliseconds;

  ContinuousRetryPolicy(
      {this.retryIntervalMilliseconds = 5000}); // Varsayılan 5 saniye

  @override
  int? nextRetryDelayInMilliseconds(RetryContext retryContext) {
    return retryIntervalMilliseconds; // Her zaman belirlenen aralığı döndür
  }
}
// --- YENİ SONU ---

final signalRServiceProvider = Provider<SignalRService>((ref) {
  final service = SignalRService();
  ref.onDispose(() => service.dispose()); // Ensure dispose is called
  return service;
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
  String? _currentConnectionId;

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
  final StreamController<List<RoomParticipant>> _roomParticipantsController =
      StreamController<List<RoomParticipant>>.broadcast();

  // New StreamControllers for reconnection events
  final StreamController<HubConnectionState> _connectionStateController =
      StreamController<HubConnectionState>.broadcast();
  final StreamController<String?> _reconnectedController =
      StreamController<String?>.broadcast();
  final StreamController<Exception?> _reconnectingController =
      StreamController<Exception?>.broadcast();

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
  Stream<List<RoomParticipant>> get roomParticipantsStream =>
      _roomParticipantsController.stream;

  // New Stream getters for reconnection
  Stream<HubConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<String?> get reconnectedStream => _reconnectedController.stream;
  Stream<Exception?> get reconnectingStream => _reconnectingController.stream;

  bool get isConnected => _isConnected;
  String? get connectionId => _currentConnectionId;

  Future<void> resetConnection() async {
    // Önce mevcut bağlantıyı kapat
    if (_hubConnection != null) {
      try {
        // Remove listeners before stopping to prevent issues during stop
        _hubConnection!.off('LeaderboardUpdated');
        _hubConnection!.off('RaceStarting');
        _hubConnection!.off('RaceEnded');
        _hubConnection!.off('UserJoined');
        _hubConnection!.off('UserLeft');
        _hubConnection!.off('LocationUpdated');
        _hubConnection!.off('RoomParticipants');
        // We don't off stateStream, onreconnecting, onreconnected as they are part of the client library management

        await _hubConnection!.stop();
      } catch (e) {}
    }

    // Tüm değişkenleri sıfırla
    _hubConnection = null;
    _isConnected = false;
    _currentConnectionId = null;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(HubConnectionState.Disconnected);
    }

    // Clear data from streams (optional, or let them be if UI handles empty states)
    // _leaderboardController.add([]);
    // ... etc for other data streams
  }

  Future<void> connect() async {
    if (_hubConnection != null &&
        (_hubConnection!.state == HubConnectionState.Connected ||
            _hubConnection!.state == HubConnectionState.Connecting ||
            _hubConnection!.state == HubConnectionState.Reconnecting)) {
      return;
    }

    // If there's an old connection, ensure it's reset properly before creating a new one
    if (_hubConnection != null) {
      await resetConnection();
    }

    final tokenJson = await StorageService.getToken();
    if (tokenJson == null) {
      _connectionStateController
          .addError(Exception('Authentication token not found'));
      throw Exception('Authentication token not found');
    }

    final String token = tokenJson;

    try {
      final hubUrl = 'https://backend.movliq.com/racehub'; // Use ApiConfig

      _hubConnection = HubConnectionBuilder()
          .withUrl(hubUrl,
              options: HttpConnectionOptions(
                accessTokenFactory: () async => token,
                skipNegotiation: true,
                transport: HttpTransportType.WebSockets,
                // logger: Logger("SignalRClient"), // Optional: for detailed logging
                //logMessageContent: true,
              ))
          // Enable automatic reconnection with a sequence of delays (in milliseconds)
          // [0ms, 2s, 5s, 10s, 20s, 30s, then stop]
          .withAutomaticReconnect(
              reconnectPolicy:
                  ContinuousRetryPolicy(retryIntervalMilliseconds: 5000))
          .build();

      // Listen to connection state changes
      _hubConnection!.stateStream.listen((state) {
        _isConnected = (state == HubConnectionState.Connected);
        _currentConnectionId = _hubConnection?.connectionId;
        if (!_connectionStateController.isClosed) {
          _connectionStateController.add(state);
        }
      });

      // Listen to specific reconnection events
      _hubConnection!.onreconnecting(({error}) {
        _isConnected = false; // Update status
        if (!_reconnectingController.isClosed) {
          _reconnectingController.add(error);
        }
      });

      _hubConnection!.onreconnected(({connectionId}) {
        _isConnected = true; // Update status
        _currentConnectionId = connectionId;
        if (!_reconnectedController.isClosed) {
          _reconnectedController.add(connectionId);
        }
        // IMPORTANT: The client (e.g., WaitingRoomScreen or RaceNotifier)
        // listening to `reconnectedStream` should now re-join the room.
      });

      // Register server-to-client message handlers (Hub methods)
      _hubConnection!.on('LeaderboardUpdated', _handleLeaderboardUpdated);
      _hubConnection!.on('RaceStarting', _handleRaceStarting);
      _hubConnection!.on('RaceEnded', _handleRaceEnded);
      _hubConnection!.on('UserJoined', _handleUserJoined);
      _hubConnection!.on('UserLeft', _handleUserLeft);
      _hubConnection!.on('LocationUpdated', _handleLocationUpdated);
      _hubConnection!.on('RoomParticipants', _handleRoomParticipants);
      _hubConnection!.on('RaceAlreadyStarted', _handleRaceAlreadyStarted);
      _hubConnection!.on('RaceFinished', _handleRaceFinished);

      await _hubConnection!.start();
      // _isConnected will be set by the stateStream listener
    } catch (e) {
      _isConnected = false;
      _currentConnectionId = null;
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(HubConnectionState.Disconnected);
        _connectionStateController
            .addError(e is Exception ? e : Exception(e.toString()));
      }
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (_hubConnection != null) {
      // Explicitly stop, which should prevent automatic reconnections for this instance.
      await _hubConnection!.stop();
      // State will be updated by the stateStream listener to Disconnected
    }
    _isConnected = false;
    _currentConnectionId = null;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(HubConnectionState.Disconnected);
    }
  }

  // Odaya katılmak için metod
  Future<void> joinRaceRoom(int roomId) async {
    if (_hubConnection == null || !_isConnected) {
      await connect();
    }

    try {
      await _hubConnection!.invoke('JoinRoom', args: [roomId]);
    } catch (e) {
      rethrow;
    }
  }

  // Odadan ayrılmak için metod
  Future<void> leaveRaceRoom(int roomId) async {
    if (_hubConnection == null || !_isConnected) return;

    try {
      await _hubConnection!.invoke('LeaveRoom', args: [roomId]);
    } catch (e) {
      rethrow;
    }
  }

  // Yarış esnasında odadan ayrılmak için metod (kullanıcının istatistiklerini sıfırlar)
  Future<void> leaveRoomDuringRace(int roomId) async {
    if (_hubConnection == null || !_isConnected) return;

    try {
      await _hubConnection!.invoke('LeaveRoomDuringRace', args: [roomId]);
    } catch (e) {
      rethrow;
    }
  }

  // Konum güncellemek için metod
  Future<void> updateLocation(
      int roomId, double distance, int steps, int calories) async {
    if (_hubConnection == null || !_isConnected) return;

    try {
      await _hubConnection!
          .invoke('UpdateLocation', args: [roomId, distance, steps, calories]);
    } catch (e) {
      rethrow;
    }
  }

  // Liderlik tablosu güncellemelerini işleyen metod
  void _handleLeaderboardUpdated(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) {
      return;
    }

    try {
      final List<dynamic> leaderboardData = arguments[0] as List<dynamic>;
      final participants = leaderboardData
          .map((item) => RaceParticipant.fromJson(item as Map<String, dynamic>))
          .toList();

      _leaderboardController.add(participants);
    } catch (e, stackTrace) {}
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
        'isRaceAlreadyStarted': false,
      });
    } catch (e) {}
  }

  // Yarışın bittiğini işleyen metod
  void _handleRaceEnded(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) {
      // Boş argüman gelse bile olayı tetikle (varsayılan oda ID 0)
      _raceEndedController.add(0);
      return;
    }

    try {
      final int roomId = arguments[0] as int;
      _raceEndedController.add(roomId);
    } catch (e) {
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
    } catch (e) {}
  }

  // Kullanıcı ayrıldı olayını işleyen metod
  void _handleUserLeft(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) return;

    try {
      final String username = arguments[0] as String;
      _userLeftController.add(username);
    } catch (e) {}
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
    } catch (e) {}
  }

  // Yeni eklenen metod - Oda katılımcılarını işleyen metod
  void _handleRoomParticipants(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) {
      _roomParticipantsController.add([]); // Boş liste gönder
      return;
    }

    try {
      final List<dynamic> participantsData = arguments[0] as List<dynamic>;

      final List<RoomParticipant> participants = [];

      for (final item in participantsData) {
        // Veri bir map ise (DTO formatında), RoomParticipant'a dönüştür
        if (item is Map<String, dynamic>) {
          participants.add(RoomParticipant.fromJson(item));
        }
        // Geriye dönük uyumluluk: Eğer sadece string ise, sadece userName içeren bir RoomParticipant oluştur
        else if (item is String) {
          participants.add(RoomParticipant(userName: item));
        }
        // Diğer durumlar için en azından toString() dönüşümünü dene
        else {
          participants.add(RoomParticipant(userName: item.toString()));
        }
      }

      _roomParticipantsController.add(participants);
    } catch (e, stackTrace) {
      _roomParticipantsController.add([]); // Hata durumunda boş liste gönder
    }
  }

  // Handler for RaceAlreadyStarted (when trying to join/rejoin an ongoing race)
  void _handleRaceAlreadyStarted(List<Object?>? arguments) {
    if (arguments == null || arguments.isEmpty) return;
    try {
      final data = arguments[0] as Map<String, dynamic>;
      final int roomId = data['RoomId'] as int;
      final double remainingTimeSeconds =
          (data['RemainingTimeSeconds'] as num).toDouble();
      // Potentially forward this to a specific stream if UI needs to react, e.g., by joining the race directly
      // For now, RaceNotifier would typically handle the state transition if it tries to join and gets this.
      // This could also be used to directly trigger race start logic in RaceNotifier if appropriate.
      _raceStartingController.add({
        'roomId': roomId,
        'countdownSeconds': 0, // No countdown, race is ongoing
        'remainingTimeSeconds': remainingTimeSeconds, // Pass remaining time
        'isRaceAlreadyStarted': true
      });
    } catch (e) {}
  }

  // Handler for RaceFinished (when trying to join/rejoin a finished race)
  void _handleRaceFinished(List<Object?>? arguments) {
    // This is similar to _handleRaceEnded, but specifically for join attempts.
    // It might carry different data or imply a different UI action (e.g., show results, navigate away).
    _handleRaceEnded(arguments); // Reuse existing logic for now
    _raceStartingController.close();
    _roomParticipantsController.close();
    // Close new controllers
    _connectionStateController.close();
    _reconnectedController.close();
    _reconnectingController.close();
  }

  // Servis dispose edildiğinde kaynakları temizle
  void dispose() {
    disconnect(); // Ensure connection is stopped
    _leaderboardController.close();
    _raceStartedController.close();
    _raceEndedController.close();
    _userJoinedController.close();
    _userLeftController.close();
    _locationUpdatedController.close();
    _raceStartingController.close();
    _roomParticipantsController.close();
    // Close new controllers
    _connectionStateController.close();
    _reconnectedController.close();
    _reconnectingController.close();
  }
}
