import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/features/auth/presentation/screens/race_screen.dart';
import '../../../../core/services/signalr_service.dart';
import '../../../../core/services/storage_service.dart';
import 'dart:convert';
import 'dart:async'; // StreamSubscription için import ekliyorum

class WaitingRoomScreen extends ConsumerStatefulWidget {
  final int roomId;
  final DateTime? startTime;

  const WaitingRoomScreen({
    super.key,
    required this.roomId,
    this.startTime,
  });

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen> {
  late bool _hasStartTime;
  bool _isConnected = false;
  bool _isRaceStarting = false;
  List<String> _participants = [];
  String? _myUsername; // Kullanıcı adı
  String? _myEmail; // Email adresi
  String? _lastJoinedUser; // Son katılan kullanıcı

  // Stream subscriptions for cleanup
  List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _hasStartTime = widget.startTime != null;

    // Kullanıcı adını al
    _loadUsername();

    // SignalR bağlantısını başlat
    _setupSignalR();
  }

  Future<void> _loadUsername() async {
    try {
      final tokenJson = await StorageService.getToken();
      if (tokenJson != null) {
        final Map<String, dynamic> userData = jsonDecode(tokenJson);

        // Token'dan hem kullanıcı adını hem de email'i al
        if (userData.containsKey('username')) {
          setState(() {
            _myUsername = userData['username'];
          });
          debugPrint('Kendi kullanıcı adınız: $_myUsername');
        }

        if (userData.containsKey('email')) {
          setState(() {
            _myEmail = userData['email'];
          });
          debugPrint('Kendi email adresiniz: $_myEmail');
        }
      }
    } catch (e) {
      debugPrint('Kullanıcı bilgisi yüklenirken hata: $e');
    }
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

      // Liderlik tablosu güncellemelerini dinle (katılımcıların odaya katıldığını gösterir)
      _subscriptions.add(signalRService.leaderboardStream.listen((leaderboard) {
        if (!mounted) return; // Mounted kontrolü

        debugPrint(
            'Liderlik tablosu güncellendi! Katılımcı sayısı: ${leaderboard.length}');

        // Kullanıcı adlarını güncelle
        setState(() {
          _participants =
              leaderboard.map((participant) => participant.userName).toList();
        });

        debugPrint('Tüm katılımcılar: $_participants');
        debugPrint('Benim kullanıcı adım: $_myUsername');
      }));

      // Yarış başlama olayını dinle ve geri sayım süresi sonunda otomatik geçiş yap
      _subscriptions.add(signalRService.raceStartingStream.listen((data) {
        if (!mounted) return; // Mounted kontrolü

        debugPrint('Yarış başlama olayı alındı: $data');
        final int roomId = data['roomId'];
        final int countdownSeconds =
            data['countdownSeconds'] ?? 10; // Varsayılan 10 saniye

        if (roomId == widget.roomId) {
          debugPrint(
              'Yarış başlıyor: Oda $roomId, $countdownSeconds saniye sonra');
          setState(() {
            _isRaceStarting = true;
          });

          // Geri sayım süresi kadar bekleyip otomatik geçiş yap
          Future.delayed(Duration(seconds: countdownSeconds), () {
            if (mounted && _isRaceStarting) {
              _navigateToRaceScreen();
            }
          });
        } else {
          debugPrint(
              'Başka bir oda için yarış başlıyor: $roomId (bizim oda: ${widget.roomId})');
        }
      }));

      // Doğrudan yarış başladı eventi - hemen otomatik geçiş
      _subscriptions.add(signalRService.raceStartedStream.listen((_) {
        if (!mounted) return; // Mounted kontrolü

        debugPrint('Yarış başladı eventi alındı! Yarış ekranına geçiliyor...');
        setState(() {
          _isRaceStarting = true;
        });

        // Otomatik geçiş yap (küçük bir gecikme ile)
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _navigateToRaceScreen();
          }
        });
      }));

      // Kullanıcı katılma/ayrılma olaylarını dinle
      _subscriptions.add(signalRService.userJoinedStream.listen((username) {
        if (!mounted) return; // Mounted kontrolü

        debugPrint('Kullanıcı katıldı: $username');
        setState(() {
          if (!_participants.contains(username)) {
            _participants.add(username);
            _lastJoinedUser = username; // Son katılan kullanıcıyı kaydet

            // 3 saniye sonra vurguyu kaldır
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _lastJoinedUser = null;
                });
              }
            });
          }
        });
        _showInfoMessage('$username odaya katıldı');
      }));

      _subscriptions.add(signalRService.userLeftStream.listen((username) {
        if (!mounted) return; // Mounted kontrolü

        debugPrint('Kullanıcı ayrıldı: $username');
        setState(() {
          _participants.remove(username);
        });
        _showInfoMessage('$username odadan ayrıldı');
      }));
    } catch (e) {
      debugPrint('SignalR bağlantı hatası: $e');
      _showErrorMessage('SignalR bağlantı hatası: $e');
    }
  }

  void _showInfoMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToRaceScreen() {
    debugPrint('_navigateToRaceScreen metodu çağrıldı');
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => RaceScreen(
            roomId: widget.roomId,
            myUsername: _myUsername,
          ),
        ),
      );
      debugPrint('RaceScreen\'e navigasyon gerçekleşti');
    } else {
      debugPrint('Widget mounted değil, navigasyon gerçekleşmedi');
    }
  }

  @override
  void dispose() {
    debugPrint('WaitingRoomScreen dispose ediliyor...');

    // Tüm stream subscriptionları temizle
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    debugPrint('WaitingRoomScreen dispose edildi - tüm dinleyiciler kapatıldı');
    // SignalR bağlantısını kapatmayın - RaceScreen'e geçilince orada tekrar kullanılacak
    super.dispose();
  }

  // Kendime ait kullanıcı adı için özel bir stil
  Widget _buildParticipantChip(String username) {
    // Gelen username ile token'daki bilgileri karşılaştır
    // Email, username veya username@domain.com şeklinde gelebilir
    bool isMe = false;

    // 1. Direkt username karşılaştırması
    if (_myUsername != null &&
        username.toLowerCase() == _myUsername!.toLowerCase()) {
      isMe = true;
    }
    // 2. Email karşılaştırması
    else if (_myEmail != null &&
        username.toLowerCase() == _myEmail!.toLowerCase()) {
      isMe = true;
    }
    // 3. Email içinde username karşılaştırması (username@domain.com formatında ise)
    else if (_myUsername != null &&
        username.contains('@') &&
        username.split('@')[0].toLowerCase() == _myUsername!.toLowerCase()) {
      isMe = true;
    }
    // 4. Username içinde email karşılaştırması (eğer email username olarak geldiyse)
    else if (_myEmail != null &&
        _myEmail!.contains('@') &&
        _myEmail!.split('@')[0].toLowerCase() == username.toLowerCase()) {
      isMe = true;
    }

    debugPrint(
        'Username karşılaştırma: gelen=$username, my_username=$_myUsername, my_email=$_myEmail, isMe=$isMe');

    final bool isLastJoined = username == _lastJoinedUser;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      transform: isLastJoined
          ? (Matrix4.translationValues(0, -4, 0)..scale(1.05))
          : Matrix4.identity(),
      child: Chip(
        label: Text(
          isMe ? "$username (Ben)" : username,
          style: TextStyle(
            fontWeight:
                isMe || isLastJoined ? FontWeight.bold : FontWeight.normal,
            color: isMe ? Colors.black : Colors.black87,
          ),
        ),
        backgroundColor: isLastJoined
            ? const Color(0xFFC4FF62)
            : isMe
                ? const Color(0xFFC4FF62)
                : const Color(0xFFC4FF62).withOpacity(0.5),
        avatar: isLastJoined
            ? const Icon(Icons.person_add, size: 16)
            : isMe
                ? const Icon(Icons.person, size: 16)
                : null,
      ),
    );
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
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('30 minutes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC4FF62),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Outdoors'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC4FF62),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 60),
              Image.asset(
                'assets/images/waitingman.png',
                height: 300,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 20),
              Text(
                _isRaceStarting ? "Yarış başlıyor!" : "Yarış Odası",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              // Geri sayım yerine sabit bilgi metni
              const Text(
                "Yarışa istediğiniz zaman katılabilirsiniz",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                "Are you ready to win?",
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Room ID: ${widget.roomId}",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _isConnected ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _isConnected ? 'Connected' : 'Disconnected',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_participants.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Katılımcılar (${_participants.length})",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          if (_lastJoinedUser != null)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                "Yeni Katılımcı!",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: _participants
                            .map((p) => _buildParticipantChip(p))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              if (_participants.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    "Henüz katılımcı yok...",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 20),
              if (_isRaceStarting)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.timer, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          "Yarış başlıyor... Otomatik olarak geçiş yapılacak",
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
