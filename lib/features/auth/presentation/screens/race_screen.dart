import 'dart:async';
import 'dart:convert';
import 'dart:convert' show jsonDecode;
import 'dart:convert' show utf8;
import 'dart:convert' show base64Url;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/signalr_service.dart';
import '../screens/tabs.dart';
import '../../../../core/services/storage_service.dart';
import 'finish_race_screen.dart';

class RaceScreen extends ConsumerStatefulWidget {
  final int roomId;
  final String? myUsername;
  final int? raceDuration; // Minutes

  const RaceScreen({
    super.key,
    required this.roomId,
    this.myUsername,
    this.raceDuration,
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
  Timer? _raceTimerTimer;
  Duration _remainingRaceTime =
      const Duration(minutes: 10); // Default to 10 minutes
  bool _isTimerInitialized = false;

  // Stream subscriptions for cleanup
  List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _setupSignalR();
    _startLocationUpdates();
    _initializeRaceTimer();
  }

  void _initializeRaceTimer() {
    // Use the race duration from the widget, or default to 10 minutes
    final raceDurationMinutes = widget.raceDuration ?? 10;

    setState(() {
      _remainingRaceTime = Duration(minutes: raceDurationMinutes);
      _isTimerInitialized = true;
    });

    _raceTimerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_remainingRaceTime.inSeconds > 0) {
        setState(() {
          _remainingRaceTime = _remainingRaceTime - const Duration(seconds: 1);
        });
      } else {
        // Race time is over, but we'll wait for the server to tell us it's over
        timer.cancel();
        _raceTimerTimer = null;

        // If the server hasn't already told us the race is over, we'll show a message
        if (_isRaceActive) {
          debugPrint('Race timer ended, waiting for server confirmation...');
        }
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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
          if (_myEmail == null &&
              leaderboard.isNotEmpty &&
              widget.myUsername != null) {
            // Kullanıcı adı bilgisini kullanarak kendimizi tanıyalım
            final me = leaderboard.firstWhere(
              (p) =>
                  p.userName.toLowerCase() == widget.myUsername!.toLowerCase(),
              orElse: () {
                debugPrint(
                    'Kullanıcı "${widget.myUsername}" leaderboard içinde bulunamadı, ilk kullanıcı seçiliyor.');
                return leaderboard.first;
              },
            );
            _myEmail = me.email;
            debugPrint('Kullanıcı bulundu: ${me.userName} (${me.email})');
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
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

    // Popup yerine yeni ekrana yönlendir
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => FinishRaceScreen(
          leaderboard: _leaderboard,
          myEmail: _myEmail,
        ),
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

    // Race timer'ı iptal et
    _raceTimerTimer?.cancel();
    _raceTimerTimer = null;

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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Race Room #${widget.roomId}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              _isRaceActive ? 'Race in progress' : 'Race ended',
              style: TextStyle(
                fontSize: 12,
                color: _isRaceActive ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: _isConnected ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _isConnected ? 'Connected' : 'Disconnected',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Exit Race?'),
                content:
                    const Text('Are you sure you want to leave this race?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const TabsScreen()),
                        (route) => false,
                      );
                    },
                    child:
                        const Text('Exit', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
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
              const SizedBox(height: 8),
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
                    // Timer display
                    _buildStatItem(
                      icon: Icons.timer,
                      value: _isTimerInitialized
                          ? _formatDuration(_remainingRaceTime)
                          : '00:00',
                      label: 'Time Left',
                      valueColor:
                          _remainingRaceTime.inSeconds < 60 ? Colors.red : null,
                    ),
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
              // Leaderboard başlığı
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFC4FF62), Colors.green],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events, color: Colors.black87),
                    SizedBox(width: 8),
                    Text(
                      'Yarış Sıralaması',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
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
    Color? valueColor,
  }) {
    // İkon renklerini belirle
    Color iconColor;
    if (icon == Icons.timer) {
      iconColor = Colors.red;
    } else if (icon == Icons.directions_run) {
      iconColor = Colors.blue;
    } else if (icon == Icons.directions_walk) {
      iconColor = Colors.green;
    } else if (icon == Icons.speed) {
      iconColor = Colors.orange;
    } else {
      iconColor = Colors.black87;
    }

    return Column(
      children: [
        // 3D efekti ile ikon
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: iconColor.withOpacity(0.2),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 24, color: iconColor),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.black87,
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
    // Sıralamaya göre renkleri belirle
    Color rankColor;
    if (participant.rank == 1) {
      rankColor = const Color(0xFFFFD700); // Altın
    } else if (participant.rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Gümüş
    } else if (participant.rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronz
    } else {
      rankColor = Colors.grey[300]!;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: isMe ? const Color(0xFFC4FF62).withOpacity(0.2) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: participant.rank <= 3
            ? BorderSide(color: rankColor, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Profil fotoğrafı ve sıralama
            Stack(
              alignment: Alignment.center,
              children: [
                // Avatar (profil fotoğrafı)
                CircleAvatar(
                  radius: 24,
                  backgroundColor: rankColor,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: Text(
                      participant.userName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            participant.rank <= 3 ? rankColor : Colors.black54,
                      ),
                    ),
                  ),
                ),

                // Sıralama rozeti
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: rankColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        participant.rank.toString(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color:
                              participant.rank <= 3 ? rankColor : Colors.black,
                        ),
                      ),
                      if (isMe)
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Text(
                            '(Ben)',
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
                    'Mesafe: ${participant.distance.toStringAsFixed(2)} m • Adım: ${participant.steps}',
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
