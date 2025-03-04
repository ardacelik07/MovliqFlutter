import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/signalr_service.dart';
import '../screens/tabs.dart';

class RaceScreen extends ConsumerStatefulWidget {
  final int roomId;
  final String? myUsername;

  const RaceScreen({
    super.key,
    required this.roomId,
    this.myUsername,
  });

  @override
  ConsumerState<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends ConsumerState<RaceScreen> {
  List<RaceParticipant> _leaderboard = [];
  bool _isConnected = false;
  bool _isRaceActive = true;
  double _myDistance = 0.0;
  int _mySteps = 0;
  String? _myEmail;
  Timer? _locationUpdateTimer;

  // Stream subscriptions for cleanup
  List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _setupSignalR();
    _startLocationUpdates();
  }

  Future<void> _setupSignalR() async {
    final signalRService = ref.read(signalRServiceProvider);

    try {
      // SignalR bağlantısını başlat ve odaya katıl
      await signalRService.connect();
      await signalRService.joinRaceRoom(widget.roomId);

      setState(() {
        _isConnected = signalRService.isConnected;
      });

      // Liderlik tablosu güncellemelerini dinle
      _subscriptions.add(signalRService.leaderboardStream.listen((leaderboard) {
        if (!mounted) return;

        setState(() {
          _leaderboard = leaderboard;

          // Kendi email'imi al ve konumumu güncelle
          if (_myEmail == null && leaderboard.isNotEmpty) {
            // Widget'ten gelen kullanıcı adını kullan veya
            // İlk kişiyi kendimiz olarak kabul et (test için)
            if (widget.myUsername != null) {
              // Kullanıcı adı bilgisini kullanarak kendimizi tanıyalım
              final me = leaderboard.firstWhere(
                (p) => p.userName == widget.myUsername,
                orElse: () => leaderboard.first,
              );
              _myEmail = me.email;
              debugPrint('Kendimi buldum: ${me.userName} (${me.email})');
            } else {
              // Fallback: ilk kullanıcıyı kendim kabul et
              _myEmail = leaderboard.first.email;
              debugPrint(
                  'Varsayılan olarak ilk kullanıcıyı kendim kabul ediyorum: ${leaderboard.first.userName}');
            }
          }
        });
      }));

      // Konum güncellemelerini dinle
      _subscriptions.add(signalRService.locationUpdatedStream.listen((data) {
        if (!mounted) return;

        debugPrint(
            'Konum güncellendi: ${data['email']}, ${data['distance']} m, ${data['steps']} adım');
      }));

      // Kullanıcı katılma/ayrılma olaylarını dinle
      _subscriptions.add(signalRService.userJoinedStream.listen((username) {
        if (!mounted) return;
        _showInfoMessage('$username odaya katıldı');
      }));

      _subscriptions.add(signalRService.userLeftStream.listen((username) {
        if (!mounted) return;
        _showInfoMessage('$username odadan ayrıldı');
      }));

      // Yarış sona erdiğinde
      _subscriptions.add(signalRService.raceEndedStream.listen((roomId) {
        if (!mounted) return;

        debugPrint('RaceScreen: Yarış sona erdi olayı alındı! Oda ID: $roomId');

        // Eğer kendi odamızın ID'si ile eşleşiyorsa veya genel bir bildirimse (0)
        if (roomId == widget.roomId || roomId == 0) {
          debugPrint(
              'RaceScreen: Bu odanın yarışı sona erdi, sonuç ekranı gösteriliyor');

          setState(() {
            _isRaceActive = false;
          });

          _showRaceEndedMessage();
          _stopLocationUpdates();
        }
      }));
    } catch (e) {
      _showErrorMessage('SignalR bağlantı hatası: $e');
    }
  }

  void _startLocationUpdates() {
    // Gerçek uygulamada, konum servisinden gerçek konum alınır
    // Bu örnek için simüle edilmiş veriler kullanıyoruz
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isRaceActive) {
        _stopLocationUpdates();
        return;
      }

      // Simüle edilmiş konum güncellemesi
      setState(() {
        _myDistance += 5.0; // Her güncellemede 5 metre ekle
        _mySteps += 10; // Her güncellemede 10 adım ekle
      });

      // SignalR üzerinden konum güncellemesi gönder
      _updateLocation();
    });
  }

  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  Future<void> _updateLocation() async {
    if (!_isConnected || !_isRaceActive) return;

    try {
      await ref
          .read(signalRServiceProvider)
          .updateLocation(widget.roomId, _myDistance, _mySteps);
    } catch (e) {
      debugPrint('Konum güncellemesi gönderilirken hata: $e');
    }
  }

  void _showRaceEndedMessage() {
    debugPrint('RaceScreen: _showRaceEndedMessage() çağrıldı');

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Yarış Sona Erdi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Yarış tamamlandı! Sonuçlar:'),
            const SizedBox(height: 16),
            if (_leaderboard.isNotEmpty)
              Text(
                '${_leaderboard.first.userName} kazandı!\n'
                'Mesafe: ${_leaderboard.first.distance} m\n'
                'Adım: ${_leaderboard.first.steps}',
                textAlign: TextAlign.center,
              )
            else
              const Text(
                'Sonuçlar henüz yüklenemedi.',
                textAlign: TextAlign.center,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const TabsScreen()),
                (route) => false,
              );
            },
            child: const Text('Ana Sayfaya Dön'),
          ),
        ],
      ),
    );
  }

  void _showInfoMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    debugPrint('RaceScreen dispose ediliyor...');

    // Zamanlayıcıyı iptal et
    _stopLocationUpdates();

    // Stream aboneliklerini iptal et
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    final signalRService = ref.read(signalRServiceProvider);
    signalRService.leaveRaceRoom(widget.roomId);

    debugPrint('RaceScreen dispose edildi - tüm dinleyiciler kapatıldı');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            stops: [0.0, 0.95],
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 255, 255, 255),
              Color(0xFFC4FF62),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Race Room #${widget.roomId}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _isConnected ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isConnected ? 'Connected' : 'Disconnected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // İlerleme bilgisi
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      icon: Icons.directions_run,
                      value: _myDistance.toStringAsFixed(1),
                      label: 'Mesafe (m)',
                    ),
                    _buildStatItem(
                      icon: Icons.directions_walk,
                      value: _mySteps.toString(),
                      label: 'Adım',
                    ),
                    _buildStatItem(
                      icon: Icons.speed,
                      value: _mySteps > 0
                          ? (_myDistance / _mySteps * 2).toStringAsFixed(1)
                          : '0.0',
                      label: 'Hız (m/adım)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Leaderboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _leaderboard.isEmpty
                    ? const Center(
                        child: Text(
                          'Waiting for participants...',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black54,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _leaderboard.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final participant = _leaderboard[index];
                          final bool isMe = participant.email == _myEmail;

                          return ParticipantTile(
                            participant: participant,
                            isMe: isMe,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.black87),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}

class ParticipantTile extends StatelessWidget {
  final RaceParticipant participant;
  final bool isMe;

  const ParticipantTile({
    super.key,
    required this.participant,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: isMe ? const Color(0xFFC4FF62).withOpacity(0.2) : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: participant.rank <= 3
                    ? const Color(0xFFC4FF62)
                    : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  participant.rank.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        participant.rank <= 3 ? Colors.black : Colors.black54,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        participant.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (isMe)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Text(
                            '(You)',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Distance: ${participant.distance.toStringAsFixed(2)} m • Steps: ${participant.steps}',
                    style: const TextStyle(
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
