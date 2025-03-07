import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/features/auth/presentation/screens/race_screen.dart';
import '../../../../core/services/signalr_service.dart';
import '../../../../core/services/storage_service.dart';
import '../providers/race_settings_provider.dart';
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
    _participants = []; // Boş liste ile başlat
    debugPrint('🔄 WaitingRoom initState - Başlangıç durumu:');
    debugPrint('🏠 Oda ID: ${widget.roomId}');

    // Kullanıcı adını al
    _loadUsername();

    // SignalR bağlantısını başlat
    _setupSignalR().then((_) {
      // SignalR bağlantısı kurulduktan sonra ilk katılımcı listesini al
      if (_isConnected) {
        debugPrint('📥 İlk katılımcı listesi alınıyor...');
        ref.read(signalRServiceProvider).joinRaceRoom(widget.roomId);
      }
    });
  }

  Future<void> _loadUsername() async {
    try {
      final tokenJson = await StorageService.getToken();
      if (tokenJson != null) {
        final Map<String, dynamic> tokenData = jsonDecode(tokenJson);
        final String token = tokenData['token'];

        // Token'ı parçalara ayır
        final parts = token.split('.');
        if (parts.length != 3) {
          throw Exception('Invalid JWT token format');
        }

        // Base64 encoded payload kısmını decode et
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final decodedPayload = utf8.decode(base64Url.decode(normalized));
        final Map<String, dynamic> userData = jsonDecode(decodedPayload);

        debugPrint('Token payload içeriği: $userData');

        // Token'dan hem kullanıcı adını hem de email'i al
        if (userData.containsKey('Username')) {
          setState(() {
            _myUsername = userData['Username'].toString().trim();
          });
          debugPrint('Kendi kullanıcı adınız: $_myUsername');
        }

        if (userData.containsKey(
            'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress')) {
          setState(() {
            _myEmail = userData[
                'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'];
          });
          debugPrint('Kendi email adresiniz: $_myEmail');
        }

        // Eğer name claim'inden username alamadıysak, email'den oluşturalım
        if (_myUsername == null && _myEmail != null) {
          setState(() {
            _myUsername = _myEmail!.split('@')[0];
          });
          debugPrint('Email\'den kullanıcı adı oluşturuldu: $_myUsername');
        }
      }
    } catch (e) {
      debugPrint('Kullanıcı bilgisi yüklenirken hata: $e');
    }
  }

  Future<void> _setupSignalR() async {
    final signalRService = ref.read(signalRServiceProvider);

    try {
      // SignalR bağlantısını başlat
      await signalRService.connect();

      setState(() {
        _isConnected = signalRService.isConnected;
      });

      // Liderlik tablosu güncellemelerini dinle (katılımcıların odaya katıldığını gösterir)
      _subscriptions.add(signalRService.leaderboardStream.listen((leaderboard) {
        if (!mounted) return;

        debugPrint(
            '📊 Liderlik tablosu güncellendi! Katılımcı sayısı: ${leaderboard.length}');

        // Artık burada _participants'ı güncellemeyelim, sadece debug için yazdıralım
        final leaderboardUsers =
            leaderboard.map((participant) => participant.userName).toList();
        debugPrint('📋 Liderlik tablosundaki kullanıcılar: $leaderboardUsers');
        debugPrint('👤 Benim kullanıcı adım: $_myUsername');
      }));

      // Mevcut oda katılımcılarını dinle
      _subscriptions
          .add(signalRService.roomParticipantsStream.listen((participants) {
        if (!mounted) return;

        debugPrint('🏠 WaitingRoom - Katılımcı Listesi Alındı');
        debugPrint('📋 Gelen Katılımcılar: ${participants.join(", ")}');
        debugPrint('📊 Toplam Katılımcı Sayısı: ${participants.length}');

        _updateParticipantsList(participants);

        // Yeni katılan kullanıcıyı belirle
        if (participants.isNotEmpty && participants.last != _lastJoinedUser) {
          setState(() {
            _lastJoinedUser = participants.last;
          });

          // 3 saniye sonra yeni katılan kullanıcı vurgusunu kaldır
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _lastJoinedUser = null;
              });
            }
          });
        }
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

  void _navigateToRaceScreen() async {
    print('1. WaitingRoom -> RaceScreen geçişi başlıyor');
    print('2. Mevcut _myUsername değeri: $_myUsername');

    // Kullanıcı adı null ise, yüklemeyi deneyelim
    if (_myUsername == null) {
      print('3. _myUsername null olduğu için yükleme başlıyor');
      await _loadUsername();
      print('4. _loadUsername çağrısı tamamlandı, yeni değer: $_myUsername');

      // Yükleme sonrası hala null ise, son çare olarak token'dan doğrudan okuyalım
      if (_myUsername == null) {
        print('5. Hala null, token\'dan okuma deneniyor');
        final tokenJson = await StorageService.getToken();
        print('6. Token değeri: $tokenJson');

        if (tokenJson != null) {
          final Map<String, dynamic> userData = jsonDecode(tokenJson);
          print('7. Token içeriği: $userData');

          if (userData.containsKey('username')) {
            setState(() {
              _myUsername = userData['username'];
            });
            print('8. Token\'dan username alındı: $_myUsername');
          } else if (userData.containsKey('email')) {
            final email = userData['email'];
            setState(() {
              _myUsername = email.contains('@') ? email.split('@')[0] : email;
            });
            print('9. Email\'den username oluşturuldu: $_myUsername');
          }
        } else {
          print('10. Token null geldi! Kullanıcı adı alınamadı');
          _showErrorMessage('Kullanıcı bilgileri alınamadı!');
          return; // Kullanıcı adı olmadan devam etmeyelim
        }
      }
    }

    // Son bir kontrol yapalım
    if (_myUsername == null) {
      print('11. Tüm denemelere rağmen kullanıcı adı alınamadı!');
      _showErrorMessage('Kullanıcı adı alınamadı, lütfen tekrar giriş yapın');
      return;
    }

    print('12. RaceScreen\'e geçiş yapılıyor, kullanıcı adı: $_myUsername');

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => RaceScreen(
            roomId: widget.roomId,
            myUsername: _myUsername,
            raceDuration: ref.read(raceSettingsProvider).duration,
          ),
        ),
      );
      print('13. RaceScreen\'e geçiş tamamlandı');
    } else {
      print('14. Widget mounted değil, geçiş yapılamadı');
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

  // Katılımcı listesini güncelleyen yardımcı metod
  void _updateParticipantsList(List<String> newParticipants) {
    if (!mounted) return;

    debugPrint('🔄 Katılımcı listesi güncelleniyor...');
    debugPrint('📋 Mevcut liste: $_participants');
    debugPrint('📋 Yeni liste: $newParticipants');

    setState(() {
      if (newParticipants.isEmpty && _myUsername != null) {
        // Eğer liste boşsa ve kullanıcı adı varsa, kendimizi ekleyelim
        _participants = [_myUsername!];
        debugPrint('👤 İlk kullanıcı olarak kendimi ekliyorum: $_myUsername');
      } else {
        // Liste boş değilse veya kullanıcı adı yoksa, gelen listeyi kullan
        _participants = List<String>.from(newParticipants);
      }
      debugPrint('✅ Katılımcı listesi güncellendi: $_participants');
    });
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
              // Katılımcılar bölümü
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_participants.isEmpty)
                      const Text(
                        "Henüz katılımcı yok...",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFC4FF62),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: _participants
                                  .map((p) => _buildParticipantChip(p))
                                  .toList(),
                            ),
                            if (_participants.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Debug: ${_participants.length} katılımcı',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
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
