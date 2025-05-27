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
import '../widgets/user_profile_avatar.dart';
import '../providers/race_provider.dart';
import '../providers/race_state.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/services.dart';
import '../widgets/raceui.dart';
import 'package:my_flutter_project/features/auth/presentation/widgets/leave_widget.dart'; // LeaveWidget importu

class RaceScreen extends ConsumerStatefulWidget {
  final int roomId;

  const RaceScreen({
    super.key,
    required this.roomId,
  });

  @override
  ConsumerState<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends ConsumerState<RaceScreen> {
  bool _leaveConfirmationShown = false;
  bool _navigationTriggered = false; // Flag to prevent multiple navigations
  Timer? _wakelockForceTimer;
  bool _showNewRaceUI = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.toggle(enable: true);
    debugPrint('[RaceScreen initState] Wakelock TOGGLED ON');
    _startWakelockForceTimer();

    if (Platform.isIOS) {
      _warmupIOSLocationTracking();
    }
  }

  void _warmupIOSLocationTracking() {
    debugPrint(
        '[RaceScreen] iOS konum servislerini uyandırma ve arka plan takibini etkinleştirme');
    try {
      const platform = MethodChannel('com.movliq/location');
      platform.invokeMethod('enableBackgroundLocationTracking').then((_) {
        debugPrint(
            '[RaceScreen] iOS native konum takibi başarıyla etkinleştirildi.');
      }).catchError((error) {
        debugPrint(
            '[RaceScreen] iOS native konum takibi etkinleştirme hatası: $error');
      });
      Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      ).then((position) {
        debugPrint(
            '[RaceScreen] iOS konum uyandırma başarılı: ${position.latitude}, ${position.longitude}');
      }).catchError((e) {
        debugPrint('[RaceScreen] iOS konum uyandırma hatası: $e');
      });
    } catch (e) {
      debugPrint('[RaceScreen] iOS konum takibi etkinleştirme genel hata: $e');
    }
  }

  void _startWakelockForceTimer() {
    _wakelockForceTimer?.cancel();
    _wakelockForceTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      WakelockPlus.toggle(enable: true);
      debugPrint('[Wakelock Force Timer] Wakelock TOGGLED ON (Forced)');
    });
  }

  @override
  void dispose() {
    debugPrint('[RaceScreen dispose] Attempting to toggle Wakelock OFF...');
    _wakelockForceTimer?.cancel();
    WakelockPlus.toggle(enable: false);
    debugPrint('[RaceScreen dispose] Wakelock toggled OFF.');
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  // Ortalama Hız Hesaplama Fonksiyonu
  String _calculateAverageSpeed(double distanceKm, Duration elapsedTime) {
    if (elapsedTime.inSeconds == 0 || distanceKm == 0) {
      return '0.0';
    }
    double hours = elapsedTime.inSeconds / 3600.0;
    double speedKmh = distanceKm / hours;
    return speedKmh.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final raceState = ref.watch(raceNotifierProvider);
    final raceNotifier = ref.read(raceNotifierProvider.notifier);

    ref.listen<RaceState>(raceNotifierProvider,
        (RaceState? previous, RaceState next) {
      if (_navigationTriggered) return;

      debugPrint(
          '[RaceScreen Listener] State changed: isRaceFinished=${next.isRaceFinished}, errorMessage=${next.errorMessage}, showWarning=${next.showFirstCheatWarning}');

      if (next.isRaceFinished == true &&
          (previous == null || previous.isRaceFinished == false)) {
        debugPrint(
            '[RaceScreen Listener] Race finished normally. Navigating to FinishRaceScreen...');
        if (mounted) {
          _navigationTriggered = true;
          debugPrint(
              '[RaceScreen Listener] Toggling Wakelock OFF before navigating to FinishRaceScreen...');
          _wakelockForceTimer?.cancel();
          WakelockPlus.toggle(enable: false);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => FinishRaceScreen(
                leaderboard: next.leaderboard,
                myEmail: next.userEmail,
                isIndoorRace: next.isIndoorRace,
                profilePictureCache: next.profilePictureCache,
              ),
            ),
          );
          return;
        }
      }

      if (next.errorMessage != null &&
          (previous == null || previous.errorMessage != next.errorMessage)) {
        final bool isCheatKickMessage = next.errorMessage ==
            'Anormal aktivite nedeniyle yarıştan çıkarıldınız.';
        if (mounted && !isCheatKickMessage) {
          _showErrorMessage(context, next.errorMessage!);
        }
        if (!next.showFirstCheatWarning) {
          debugPrint(
              '[RaceScreen Listener] Error/Leave detected: ${next.errorMessage}. Navigating to TabsScreen...');
          if (mounted) {
            _navigationTriggered = true;
            debugPrint(
                '[RaceScreen Listener] Toggling Wakelock OFF before navigating to TabsScreen (Error/Leave)...');
            _wakelockForceTimer?.cancel();
            WakelockPlus.toggle(enable: false);
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const TabsScreen()),
              (route) => false,
            );
            return;
          }
        }
      }

      if (next.showFirstCheatWarning == true &&
          (previous == null || previous.showFirstCheatWarning == false)) {
        debugPrint(
            '[RaceScreen Listener] Showing first cheat warning dialog...');
        if (mounted) {
          _showFirstCheatWarningDialog(context, ref);
        }
      }
    });

    // Ortalama Hız Değişkeni
    String averageSpeed = '0.0';
    if (raceState.isRaceActive && raceState.raceStartTime != null) {
      final Duration elapsedTime =
          DateTime.now().difference(raceState.raceStartTime!);
      averageSpeed = _calculateAverageSpeed(
          raceState.isIndoorRace
              ? raceState.estimatedIndoorDistance
              : raceState.currentDistance,
          elapsedTime);
    }

    // Süre için progress bar değeri
    double progress = 0.0;
    if (raceState.raceDuration != null &&
        raceState.raceDuration!.inSeconds > 0) {
      progress =
          raceState.remainingTime.inSeconds / raceState.raceDuration!.inSeconds;
      if (progress < 0) progress = 0;
      if (progress > 1) progress = 1;
    }

    return WillPopScope(
      onWillPop: () async {
        if (raceState.isRaceActive || raceState.isPreRaceCountdownActive) {
          return await _showLeaveConfirmationDialog(context, raceNotifier);
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212), // Koyu arka plan
        appBar: AppBar(
          backgroundColor: Colors.transparent, // Şeffaf AppBar
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              if (raceState.isRaceActive ||
                  raceState.isPreRaceCountdownActive) {
                await _showLeaveConfirmationDialog(context, raceNotifier);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          centerTitle: true, // Başlığı ortala
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/icons/bayrak.png',
                  width: 24, height: 24), // Bayrak ikonu
              const SizedBox(width: 8),
              Text(
                raceState.isPreRaceCountdownActive
                    ? 'Başlıyor...'
                    : (raceState.isRaceActive
                        ? 'Yarış Başladı!'
                        : 'Yarış Bitti'),
                style: const TextStyle(
                    fontSize: 22, // Font boyutu büyütüldü
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(width: 8),
              /* if (raceState.isRaceActive) // Sadece yarış aktifken göster
                 IconButton(
                  padding: EdgeInsets.zero, // Olası iç padding'i kaldır
                  constraints:
                      const BoxConstraints(), // Olası boyut kısıtlamalarını kaldır
                  icon: const Icon(
                    Icons.add_road_rounded, // Değişiklik: İkonu sabit yap
                    color: Colors.white,
                    size: 24,
                  ),
                  onPressed: () {
                    setState(() {
                      _showNewRaceUI = !_showNewRaceUI; // Toggle the UI state
                    });
                    debugPrint(
                        'Road icon tapped, _showNewRaceUI is now: $_showNewRaceUI');
                  },
                ),*/
            ],
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Geri Sayım Overlay
              if (raceState.isPreRaceCountdownActive)
                Expanded(
                  child: Container(
                    color: Colors.black.withOpacity(0.8), // Daha koyu overlay
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Yarış Başlıyor',
                            style: TextStyle(
                              fontSize: 32, // Font boyutu büyütüldü
                              color: Color(0xFFC4FF62),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            raceState.preRaceCountdownValue.toString(),
                            style: const TextStyle(
                                fontSize: 120, // Font boyutu büyütüldü
                                color: Color(0xFFC4FF62),
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Ana Yarış İçeriği
              if (!raceState.isPreRaceCountdownActive)
                Expanded(
                  child: _showNewRaceUI
                      ? RaceUIWidget(
                          participants: raceState.leaderboard,
                          myEmail: raceState.userEmail,
                          profilePictureCache: raceState.profilePictureCache,
                          isIndoorRace: raceState.isIndoorRace,
                          remainingTime: raceState.remainingTime,
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              // Zamanlayıcı ve Progress Bar
                              if (raceState.isRaceActive)
                                Column(
                                  children: [
                                    Text(
                                      'Kalan süre: ${_formatDuration(raceState.remainingTime)}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18, // Font boyutu ayarlandı
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 12, // Bar kalınlığı
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        color: Colors
                                            .grey.shade800, // Arka plan rengi
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: progress,
                                          backgroundColor: Colors.transparent,
                                          valueColor: const AlwaysStoppedAnimation<
                                                  Color>(
                                              Color(
                                                  0xFFC4FF62)), // Yeşil progress
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                ),

                              // İstatistikler Kartı
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 20, horizontal: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E), // Kart rengi
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatItem(
                                      iconAsset:
                                          'assets/icons/alev.png', // Kalori ikonu
                                      value:
                                          raceState.currentCalories.toString(),
                                      label: 'kcal',
                                    ),
                                    if (!raceState.isIndoorRace)
                                      _buildStatItem(
                                        iconAsset:
                                            'assets/icons/location.png', // Mesafe/Konum ikonu
                                        value: raceState.currentDistance
                                            .toStringAsFixed(2),
                                        label: 'km',
                                      ),
                                    if (raceState.isIndoorRace)
                                      _buildStatItem(
                                        iconAsset:
                                            'assets/icons/location.png', // Tahmini KM için de aynı ikon
                                        value: raceState.estimatedIndoorDistance
                                            .toStringAsFixed(2),
                                        label: 'Tahmini km',
                                      ),
                                    _buildStatItem(
                                      iconAsset:
                                          'assets/icons/steps.png', // Adım ikonu
                                      value: raceState.currentSteps.toString(),
                                      label: 'adım',
                                    ),
                                    _buildStatItem(
                                      iconAsset:
                                          'assets/icons/speed.png', // Hız ikonu
                                      value: averageSpeed, // Ortalama hız
                                      label: 'km/sa',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 25),
                              // Canlı Sıralama Başlığı
                              Row(
                                children: [
                                  Image.asset('assets/icons/coupa.png',
                                      width: 28, height: 28), // Kupa ikonu
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Canlı Sıralama',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              // Leaderboard Listesi
                              Expanded(
                                child: raceState.leaderboard.isEmpty
                                    ? Center(
                                        child: raceState.isRaceActive
                                            ? const CircularProgressIndicator(
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                            Color>(
                                                        Color(0xFFC4FF62)))
                                            : const Text(
                                                'Yarışmacı bulunamadı.',
                                                style: TextStyle(
                                                    color: Colors.grey)))
                                    : ListView.builder(
                                        itemCount: raceState.leaderboard.length,
                                        itemBuilder: (context, index) {
                                          final participant =
                                              raceState.leaderboard[index];
                                          final bool isMe = participant.email
                                                  ?.toLowerCase() ==
                                              raceState.userEmail
                                                  ?.toLowerCase();
                                          return ParticipantTile(
                                            participant: participant,
                                            isMe: isMe,
                                            isIndoorRace:
                                                raceState.isIndoorRace,
                                            rank: participant.rank,
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                ),
              // Hata Mesajı Göstergesi
              if (raceState.errorMessage != null &&
                  !raceState.isPreRaceCountdownActive &&
                  !raceState.isRaceActive) // Sadece yarış bittiyse göster
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Hata: ${raceState.errorMessage}',
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFirstCheatWarningDialog(
      BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        contentPadding: const EdgeInsets.all(24.0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFFCC00),
              size: 80,
            ),
            const SizedBox(height: 24),
            const Text(
              'Hız Sınırı Aşıldı',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sistem olağan dışı bir hız tespit etti.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Devam etmek için hızınızı normale düşürün, aksi halde yarış iptal edilecektir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC4FF62),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
              onPressed: () {
                ref
                    .read(raceNotifierProvider.notifier)
                    .dismissFirstCheatWarning();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Yarışa devam et',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<bool> _showLeaveConfirmationDialog(
      BuildContext context, RaceNotifier raceNotifier) async {
    if (_leaveConfirmationShown) return false;
    _leaveConfirmationShown = true;

    // bool? result = await showDialog<bool>(
    //   context: context,
    //   barrierDismissible: false,
    //   builder: (context) => AlertDialog(
    //     backgroundColor: const Color(0xFF1E1E1E), // Koyu dialog arkaplanı
    //     title:
    //         const Text('Yarıştan Ayrıl', style: TextStyle(color: Colors.white)),
    //     content: const Text(
    //         'Yarış devam ediyor. Ayrılmak istediğinize emin misiniz?',
    //         style: TextStyle(color: Colors.white70)),
    //     actions: [
    //       TextButton(
    //         onPressed: () {
    //           _leaveConfirmationShown = false;
    //           Navigator.of(context).pop(false);
    //         },
    //         child:
    //             const Text('Hayır', style: TextStyle(color: Color(0xFFC4FF62))),
    //       ),
    //       TextButton(
    //         onPressed: () {
    //           _leaveConfirmationShown = false;
    //           Navigator.of(context).pop(true);
    //         },
    //         child: const Text('Evet, Ayrıl',
    //             style: TextStyle(color: Colors.redAccent)),
    //       ),
    //     ],
    //   ),
    // );

    // Yeni LeaveWidget'ı kullan
    bool? result = await showLeaveConfirmationDialog(
      context: context,
      imagePath: 'assets/images/leaveimage.png', // Belirttiğiniz resim yolu
      title: 'Yarıştan Ayrılmak İstiyor Musun?',
      message:
          'Canlı yarıştan ayrıldığında, yarış verilerin silinecek ve sıralamaya dahil edilmeyeceksin.',
      // Buton metinleri varsayılan olacak
    );

    if (result == true) {
      debugPrint('Kullanıcı yarıştan ayrılmayı onayladı.');
      await raceNotifier.leaveRace();
      return true;
    } else {
      _leaveConfirmationShown = false;
    }
    return false;
  }

  void _showErrorMessage(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildStatItem({
    required String iconAsset, // IconData yerine String asset path
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(iconAsset, width: 36, height: 36), // Asset ikonu
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20, // Font boyutu güncellendi
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12, // Font boyutu güncellendi
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class ParticipantTile extends ConsumerWidget {
  final RaceParticipant participant;
  final bool isMe;
  final bool isIndoorRace;
  final int rank; // Sıralama bilgisi eklendi

  const ParticipantTile({
    super.key,
    required this.participant,
    this.isMe = false,
    required this.isIndoorRace,
    required this.rank, // Constructor'a eklendi
  });

  String _getRankAsset(int rank) {
    if (rank == 1) return 'assets/icons/1.png';
    if (rank == 2) return 'assets/icons/2.png';
    if (rank == 3) return 'assets/icons/3.png';
    return ''; // Diğer sıralamalar için asset yoksa boş string
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileCache = ref.watch(
        raceNotifierProvider.select((state) => state.profilePictureCache));
    final String? profilePicUrl = profileCache[participant.userName];
    final String rankAsset = _getRankAsset(rank);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      padding: const EdgeInsets.symmetric(
          vertical: 12.0, horizontal: 16.0), // Padding ayarlandı
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Kart rengi güncellendi
        borderRadius: BorderRadius.circular(12),
        border: isMe
            ? Border.all(
                color: const Color(0xFFC4FF62), width: 2.0) // Vurgu rengi
            : null,
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomLeft, // İkonun pozisyonu için
            children: [
              UserProfileAvatar(
                imageUrl: profilePicUrl,
                radius: 25, // Avatar boyutu
              ),
              if (rankAsset.isNotEmpty &&
                  rank <= 3) // Sadece ilk 3 için ikonu göster
                Positioned(
                  left: -8, // İkonun pozisyonu ayarlandı
                  bottom: -8, // İkonun pozisyonu ayarlandı
                  child: Image.asset(rankAsset,
                      width: 24, height: 24), // Sıralama ikonu
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              participant.userName,
              style: const TextStyle(
                fontWeight: FontWeight.w600, // Font ağırlığı güncellendi
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isIndoorRace) // Only show distance for outdoor races
                Text(
                  '${participant.distance.toStringAsFixed(2)} km',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (!isIndoorRace)
                const SizedBox(
                    height: 4), // Add spacing only if distance is shown
              Text(
                '${participant.steps} adım',
                style: TextStyle(
                  fontSize: isIndoorRace
                      ? 16
                      : 12, // Larger font for steps if it's the only metric
                  color: Colors
                      .white, // White color for steps when it's the primary metric
                  fontWeight:
                      isIndoorRace ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
