import 'dart:async';
import 'dart:convert';
import 'dart:convert' show jsonDecode;
import 'dart:convert' show utf8;
import 'dart:convert' show base64Url;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/services/signalr_service.dart';
import '../screens/tabs.dart';
import '../../../../core/services/storage_service.dart';
import 'finish_race_screen.dart';

class RaceScreen extends ConsumerStatefulWidget {
  final int roomId;
  final String? myUsername;
  final int? raceDuration; // Minutes
  final Map<String, String?> profilePictureCache; // Cache parametresini ekledik

  const RaceScreen({
    super.key,
    required this.roomId,
    this.myUsername,
    this.raceDuration,
    required this.profilePictureCache, // Constructor'a ekledik
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

  // Konum takibi için gerekli özellikler
  Position? _currentPosition;
  Position?
      _previousPosition; // Bu değişkeni kullanmayacağız, RecordScreen'deki gibi
  bool _hasLocationPermission = false;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Adım sayar için gerekli özellikler
  int _initialSteps = 0;
  bool _hasPedometerPermission = false;
  StreamSubscription<StepCount>? _stepCountSubscription;

  @override
  void initState() {
    super.initState();

    // Bildirimleri temizleyen kodu kaldırıyorum
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (mounted) {
    //     ScaffoldMessenger.of(context).clearSnackBars();
    //   }
    // });

    _setupSignalR();
    _initPermissions(); // Konum ve adım izinlerini başlat
    _initializeRaceTimer();
  }

  // Tüm izinleri başlatan fonksiyon
  Future<void> _initPermissions() async {
    // Konum servislerinin açık olup olmadığını kontrol et
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Konum servisleri kapalıysa, kullanıcıyı uyar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen konum servislerini açın'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      // Konum servislerini açma isteği göster
      await Geolocator.openLocationSettings();
      return;
    }

    await _checkLocationPermission();
    await _checkActivityPermission();
  }

  // Aktivite izinlerini kontrol eden fonksiyon
  Future<void> _checkActivityPermission() async {
    // Platform-specific permission checks
    if (Platform.isAndroid) {
      // Android'de adım sayar iznini kontrol et
      if (await Permission.activityRecognition.request().isGranted) {
        setState(() {
          _hasPedometerPermission = true;
        });
        _initPedometer();
      }
    } else if (Platform.isIOS) {
      // iOS'ta motion sensörü izni için
      if (await Permission.sensors.request().isGranted) {
        setState(() {
          _hasPedometerPermission = true;
        });
        _initPedometer();
      }
    }
  }

  // Konum izinlerini kontrol eden fonksiyon
  Future<void> _checkLocationPermission() async {
    try {
      final LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        final LocationPermission requestedPermission =
            await Geolocator.requestPermission();

        setState(() {
          _hasLocationPermission =
              requestedPermission != LocationPermission.denied &&
                  requestedPermission != LocationPermission.deniedForever;
        });
      } else {
        setState(() {
          _hasLocationPermission = permission != LocationPermission.denied &&
              permission != LocationPermission.deniedForever;
        });
      }

      debugPrint('Konum izin durumu: $_hasLocationPermission');

      if (_hasLocationPermission) {
        // İzin varsa ilk konumu al
        await _getCurrentLocation();
        // Eğer yarış aktifse konum takibini başlat
        if (_isRaceActive) {
          _startLocationUpdates();
        }
      }
    } catch (e) {
      debugPrint('Konum izni hatası: $e');
    }
  }

  // Mevcut konumu alan fonksiyon
  Future<void> _getCurrentLocation() async {
    try {
      debugPrint('Konum alınıyor...');
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high); // RecordScreen ile aynı

      debugPrint('Konum alındı: ${position.latitude}, ${position.longitude}');

      setState(() {
        // Sadece mevcut konumu ayarla, RecordScreen gibi
        _currentPosition = position;
      });
    } catch (e) {
      debugPrint('Konum alınamadı: $e');
    }
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

      // Kullanıcı katılma olayını dinle ama bildirim gösterme
      _subscriptions.add(signalRService.userJoinedStream.listen((username) {
        if (!mounted) return;
        // Sadece log yazdıralım, bildirim göstermeyelim
        debugPrint(
            'Kullanıcı yarışa katıldı (bildirim gösterilmedi): $username');
      }));

      // Kullanıcı ayrılma olayını dinle
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

  // Adım sayar başlatma fonksiyonu
  void _initPedometer() {
    _stepCountSubscription =
        Pedometer.stepCountStream.listen((StepCount event) {
      if (!mounted) return;

      setState(() {
        if (_isRaceActive && _initialSteps == 0) {
          _initialSteps = event.steps;
          _mySteps = 0;
          debugPrint('Başlangıç adım sayısı ayarlandı: $_initialSteps');
        } else if (_isRaceActive) {
          int newSteps = event.steps - _initialSteps;
          // Adım sayısı azalmadıysa güncelle (mantık hatası kontrolü)
          if (newSteps >= _mySteps) {
            _mySteps = newSteps;
            debugPrint('Adım sayısı güncellendi: $_mySteps');

            // Adım güncellemesini sunucuya gönder
            _updateLocation();
          }
        }
      });
    }, onError: (error) {
      debugPrint('Adım sayar hatası: $error');
    });
  }

  void _startLocationUpdates() {
    if (!_hasLocationPermission) {
      _checkLocationPermission();
      return;
    }

    try {
      debugPrint('Konum takibi başlatılıyor...');

      // RecordScreen ile tamamen aynı:
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // RecordScreen ile birebir aynı
        ),
      ).listen((Position position) {
        if (!mounted || !_isRaceActive) return;

        debugPrint(
            'Konum güncellendi: ${position.latitude}, ${position.longitude}');

        setState(() {
          // Eski konum varsa, iki nokta arasındaki mesafeyi hesapla
          // RecordScreen ile aynı mantık:
          if (_currentPosition != null) {
            double newDistance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              position.latitude,
              position.longitude,
            );

            // ÖNEMLİ DEĞİŞİKLİK: RecordScreen'deki gibi kilometre cinsine çevirip ekle
            _myDistance += newDistance / 1000;
            debugPrint(
                'Mesafe eklendi: ${newDistance / 1000} km. Toplam: $_myDistance km');
          }

          // RecordScreen'de olduğu gibi doğrudan güncelle
          _currentPosition = position;

          // Konum güncellemesi gönder
          _updateLocation();
        });
      }, onError: (e) {
        debugPrint('Konum takibi hatası: $e');
      });
    } catch (e) {
      debugPrint('Konum takibi başlatma hatası: $e');
    }
  }

  void _stopLocationUpdates() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
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
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Fiziksel geri tuşuna basıldığında doğrudan odadan ayrılma diyalogunu göster
        return await _showLeaveConfirmationDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              _showLeaveConfirmationDialog();
            },
          ),
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
                        valueColor: _remainingRaceTime.inSeconds < 60
                            ? Colors.red
                            : null,
                      ),
                      _buildStatItem(
                        icon: Icons.directions_run,
                        value: _myDistance.toStringAsFixed(2),
                        label: 'Mesafe (km)',
                      ),
                      _buildStatItem(
                        icon: Icons.directions_walk,
                        value: _mySteps.toString(),
                        label: 'Adım',
                      ),
                      _buildStatItem(
                        icon: Icons.speed,
                        value: _mySteps > 0
                            ? (_myDistance / _mySteps).toStringAsFixed(1)
                            : '0.0',
                        label: 'Hız (km/adım)',
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
                      Icon(Icons.emoji_events, color: Colors.amber),
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
                            final isMe = participant.email == _myEmail;

                            return ParticipantTile(
                              participant: participant,
                              isMe: isMe,
                              profilePictureUrl: widget.profilePictureCache[
                                  participant
                                      .userName], // Cache'den profil fotoğrafını al
                            );
                          },
                        ),
                ),
              ],
            ),
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

  // Kullanıcının yarış esnasında odadan ayrılmasını onaylatan dialog
  Future<bool> _showLeaveConfirmationDialog() async {
    bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yarıştan Ayrıl'),
        content: const Text(
            'Yarış devam ediyor. Ayrılmak istediğinize emin misiniz? İstatistikleriniz sıfırlanacak ve liderlik tablosundan çıkarılacaksınız.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hayır'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: const Text('Evet, Ayrıl'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _leaveRaceRoom();
      return true;
    }

    return false;
  }

  // Yarış esnasında odadan ayrılma işlemini yapan metod
  Future<void> _leaveRaceRoom() async {
    try {
      // Konum güncellemelerini durdur
      _stopLocationUpdates();

      // Adım sayacı aboneliğini iptal et
      _stepCountSubscription?.cancel();

      // SignalR bağlantısını kur ve LeaveRoomDuringRace metodunu çağır
      final signalRService = ref.read(signalRServiceProvider);

      if (signalRService.isConnected) {
        // Yarış esnasında ayrılma özel metodunu çağır
        await signalRService.leaveRoomDuringRace(widget.roomId);
        debugPrint(
            'SignalR: Yarış esnasında odadan ayrılma başarılı - Oda ID: ${widget.roomId}');
      } else {
        debugPrint('SignalR bağlantısı yok, önce bağlantı kuruluyor...');
        await signalRService.connect();
        await signalRService.leaveRoomDuringRace(widget.roomId);
      }

      // Stream aboneliklerini iptal et
      for (var subscription in _subscriptions) {
        subscription.cancel();
      }
      _subscriptions.clear();

      if (mounted) {
        // Ana sayfaya yönlendir
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const TabsScreen()),
          (route) => false, // Tüm geçmiş sayfaları temizle
        );
      }
    } catch (e) {
      debugPrint('Yarış esnasında odadan ayrılma hatası: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Odadan ayrılırken bir hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    debugPrint('RaceScreen dispose ediliyor...');

    // Konum takibini durdur
    _stopLocationUpdates();

    // Adım sayar aboneliğini iptal et
    _stepCountSubscription?.cancel();

    // Race timer'ı iptal et
    _raceTimerTimer?.cancel();
    _raceTimerTimer = null;

    // Stream aboneliklerini iptal et
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Yeni kod: dispose sırasında normal LeaveRaceRoom yerine normale dönüyoruz
    // böylece dispose edildiğinde ikinci kez _leaveRaceRoom çağrılmayacak
    final signalRService = ref.read(signalRServiceProvider);
    if (_isRaceActive) {
      // Eğer kullanıcı uygulama kapatma gibi bir yolla çıkış yaparsa yine de istatistikleri sıfırlanmalı
      try {
        if (signalRService.isConnected) {
          signalRService.leaveRoomDuringRace(widget.roomId);
        }
      } catch (e) {
        debugPrint('Dispose sırasında odadan ayrılma hatası: $e');
      }
    } else {
      signalRService.leaveRaceRoom(widget.roomId);
    }

    debugPrint('RaceScreen dispose edildi - tüm dinleyiciler kapatıldı');
    super.dispose();
  }
}

class ParticipantTile extends StatelessWidget {
  final RaceParticipant participant;
  final bool isMe;
  final String? profilePictureUrl; // Profil fotoğrafı URL'i ekledik

  const ParticipantTile({
    super.key,
    required this.participant,
    this.isMe = false,
    this.profilePictureUrl, // Constructor'a ekledik
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
                    backgroundImage: profilePictureUrl != null
                        ? NetworkImage(profilePictureUrl!)
                        : null,
                    child: profilePictureUrl == null
                        ? Text(
                            participant.userName[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: participant.rank <= 3
                                  ? rankColor
                                  : Colors.black54,
                            ),
                          )
                        : null,
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
                  const SizedBox(height: 8),
                  // Bilgi kartları satırı
                  Row(
                    children: [
                      // Mesafe bilgisi
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_run,
                                size: 14, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              '${participant.distance.toStringAsFixed(2)} km',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Adım bilgisi
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_walk,
                                size: 14, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              'Adım: ${participant.steps}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
