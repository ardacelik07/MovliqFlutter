import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import 'storage_service.dart';
import '../../features/auth/domain/models/room_participant.dart';

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
    debugPrint('SignalR bağlantısını sıfırlama başlatılıyor...');

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
        debugPrint('Mevcut SignalR bağlantısı kapatıldı');
      } catch (e) {
        debugPrint('Bağlantı kapatma hatası: $e');
      }
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

    debugPrint('SignalR bağlantısı tamamen sıfırlandı');
  }

  Future<void> connect() async {
    if (_hubConnection != null &&
        (_hubConnection!.state == HubConnectionState.Connected ||
            _hubConnection!.state == HubConnectionState.Connecting ||
            _hubConnection!.state == HubConnectionState.Reconnecting)) {
      debugPrint('SignalR zaten bağlı, bağlanıyor veya yeniden bağlanıyor.');
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
      final hubUrl =
          'http://movliq.mehmetalicakir.tr:5000/racehub'; // Use ApiConfig

      _hubConnection = HubConnectionBuilder()
          .withUrl(hubUrl,
              options: HttpConnectionOptions(
                accessTokenFactory: () async => token,
                // logger: Logger("SignalRClient"), // Optional: for detailed logging
                //logMessageContent: true,
              ))
          // Enable automatic reconnection with a sequence of delays (in milliseconds)
          // [0ms, 2s, 5s, 10s, 20s, 30s, then stop]
          .withAutomaticReconnect()
          .build();

      // Listen to connection state changes
      _hubConnection!.stateStream.listen((state) {
        debugPrint('[SignalR] Connection State Changed: $state');
        _isConnected = (state == HubConnectionState.Connected);
        _currentConnectionId = _hubConnection?.connectionId;
        if (!_connectionStateController.isClosed) {
          _connectionStateController.add(state);
        }
      });

      // Listen to specific reconnection events
      _hubConnection!.onreconnecting(({error}) {
        debugPrint('[SignalR] Reconnecting... Error: ${error?.toString()}');
        _isConnected = false; // Update status
        if (!_reconnectingController.isClosed) {
          _reconnectingController.add(error);
        }
      });

      _hubConnection!.onreconnected(({connectionId}) {
        debugPrint('[SignalR] Reconnected. New Connection ID: $connectionId');
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
      debugPrint(
          'SignalR bağlantısı başlatıldı. Durum: ${_hubConnection?.state}');
    } catch (e) {
      debugPrint('SignalR bağlantı hatası: $e');
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
      debugPrint('SignalR bağlantısı istemci tarafından kapatıldı.');
    } else {
      debugPrint('SignalR bağlantısı zaten null, kapatma işlemi atlandı.');
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
      debugPrint('📡 SignalR: JoinRoom çağrısı yapılıyor - roomId: $roomId');
      await _hubConnection!.invoke('JoinRoom', args: [roomId]);
      debugPrint('✅ SignalR: JoinRoom çağrısı başarılı - roomId: $roomId');
    } catch (e) {
      debugPrint('❌ SignalR: JoinRoom çağrısı başarısız - hata: $e');
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

  // Yarış esnasında odadan ayrılmak için metod (kullanıcının istatistiklerini sıfırlar)
  Future<void> leaveRoomDuringRace(int roomId) async {
    if (_hubConnection == null || !_isConnected) return;

    try {
      await _hubConnection!.invoke('LeaveRoomDuringRace', args: [roomId]);
      debugPrint(
          'Yarış esnasında odadan ayrılındı: $roomId (istatistikler sıfırlandı)');
    } catch (e) {
      debugPrint('Yarış esnasında odadan ayrılma hatası: $e');
    }
  }

  // Konum güncellemek için metod
  Future<void> updateLocation(
      int roomId, double distance, int steps, int calories) async {
    if (_hubConnection == null || !_isConnected) return;

    try {
      await _hubConnection!
          .invoke('UpdateLocation', args: [roomId, distance, steps, calories]);
      debugPrint(
          'Konum güncellendi: ${distance.toStringAsFixed(2)} km, $steps adım, $calories kalori');
    } catch (e) {
      debugPrint('Konum güncelleme hatası: $e');
    }
  }

  // Liderlik tablosu güncellemelerini işleyen metod
  void _handleLeaderboardUpdated(List<Object?>? arguments) {
    debugPrint(
        '[SignalR Handler] _handleLeaderboardUpdated CALLED with arguments: $arguments');
    if (arguments == null || arguments.isEmpty) {
      debugPrint(
          '[SignalR Handler] _handleLeaderboardUpdated - Arguments are null or empty. Returning.');
      return;
    }

    try {
      final List<dynamic> leaderboardData = arguments[0] as List<dynamic>;
      debugPrint(
          '[SignalR Handler] _handleLeaderboardUpdated - Raw leaderboardData: $leaderboardData');
      final participants = leaderboardData
          .map((item) => RaceParticipant.fromJson(item as Map<String, dynamic>))
          .toList();

      _leaderboardController.add(participants);
      debugPrint(
          '[SignalR Handler] _handleLeaderboardUpdated - SUCCESS: ${participants.length} participants added to stream.');
    } catch (e, stackTrace) {
      debugPrint(
          '[SignalR Handler] _handleLeaderboardUpdated - ERROR processing leaderboard: $e');
      debugPrint('[SignalR Handler] Stack Trace: $stackTrace');
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

  // Yeni eklenen metod - Oda katılımcılarını işleyen metod
  void _handleRoomParticipants(List<Object?>? arguments) {
    debugPrint('🔍 SignalR RoomParticipants - Olay Tetiklendi');
    debugPrint('📝 Gelen Raw Arguments: $arguments');

    if (arguments == null || arguments.isEmpty) {
      debugPrint(
          '⚠️ HATA: RoomParticipants boş veya null arguments ile geldi!');
      _roomParticipantsController.add([]); // Boş liste gönder
      return;
    }

    try {
      final List<dynamic> participantsData = arguments[0] as List<dynamic>;
      debugPrint('📋 Ham Katılımcı Verisi: $participantsData');

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

      debugPrint(
          '👥 İşlenmiş Katılımcılar: ${participants.map((p) => p.userName).join(", ")}');
      debugPrint('📊 Toplam Katılımcı Sayısı: ${participants.length}');

      _roomParticipantsController.add(participants);
      debugPrint('✅ RoomParticipants Stream başarıyla güncellendi!');
    } catch (e, stackTrace) {
      debugPrint('❌ RoomParticipants İşleme HATASI: $e');
      debugPrint(
          '📍 Hata Detayı - Arguments[0] Tipi: ${arguments[0]?.runtimeType}');
      debugPrint('🔍 Stack Trace: $stackTrace');
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
      debugPrint(
          '[SignalR] RaceAlreadyStarted received for Room: $roomId, Remaining: $remainingTimeSeconds');
      // Potentially forward this to a specific stream if UI needs to react, e.g., by joining the race directly
      // For now, RaceNotifier would typically handle the state transition if it tries to join and gets this.
      // This could also be used to directly trigger race start logic in RaceNotifier if appropriate.
      _raceStartingController.add({
        'roomId': roomId,
        'countdownSeconds': 0, // No countdown, race is ongoing
        'remainingTimeSeconds': remainingTimeSeconds, // Pass remaining time
        'isRaceAlreadyStarted': true
      });
    } catch (e) {
      debugPrint('_handleRaceAlreadyStarted işleme hatası: $e');
    }
  }

  // Handler for RaceFinished (when trying to join/rejoin a finished race)
  void _handleRaceFinished(List<Object?>? arguments) {
    // This is similar to _handleRaceEnded, but specifically for join attempts.
    // It might carry different data or imply a different UI action (e.g., show results, navigate away).
    _handleRaceEnded(arguments); // Reuse existing logic for now
    debugPrint('[SignalR] RaceFinished (on join attempt) received.');
  }

  // Servis dispose edildiğinde kaynakları temizle
  void dispose() {
    debugPrint('[SignalRService] dispose çağrıldı.');
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
    debugPrint('[SignalRService] tüm stream controllerlar kapatıldı.');
  }
}
