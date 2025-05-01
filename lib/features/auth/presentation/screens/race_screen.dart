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

class RaceScreen extends ConsumerStatefulWidget {
  final int roomId;
  final String? myUsername;
  final Map<String, String?> profilePictureCache;

  const RaceScreen({
    super.key,
    required this.roomId,
    this.myUsername,
    required this.profilePictureCache,
  });

  @override
  ConsumerState<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends ConsumerState<RaceScreen> {
  bool _leaveConfirmationShown = false;
  bool _navigationTriggered = false; // Flag to prevent multiple navigations

  @override
  void initState() {
    super.initState();
    // Listener is moved to build method
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    // RaceNotifier state'ini dinle
    final raceState = ref.watch(raceNotifierProvider);
    final raceNotifier = ref.read(raceNotifierProvider.notifier);

    // Listen for state changes to handle navigation
    ref.listen<RaceState>(raceNotifierProvider,
        (RaceState? previous, RaceState next) {
      // Check if navigation has already been triggered
      if (_navigationTriggered) return;

      debugPrint(
          '[RaceScreen Listener] State changed: isRaceFinished=${next.isRaceFinished}, errorMessage=${next.errorMessage}');

      // Check if race finished normally
      if (next.isRaceFinished == true &&
          (previous == null || previous.isRaceFinished == false)) {
        debugPrint(
            '[RaceScreen Listener] Race finished normally. Navigating to FinishRaceScreen...');
        if (mounted) {
          _navigationTriggered = true; // Set flag before navigating
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => FinishRaceScreen(
                leaderboard:
                    next.leaderboard, // Get latest leaderboard from state
                myEmail: next.userEmail, // Get email from state
                isIndoorRace: next.isIndoorRace, // Get type from state
                profilePictureCache:
                    Map<String, String?>.from(widget.profilePictureCache),
              ),
            ),
          );
        }
      } else if (next.errorMessage != null &&
          (previous == null || previous.errorMessage != next.errorMessage)) {
        // Handle errors
        debugPrint(
            '[RaceScreen Listener] Error detected: ${next.errorMessage}. Navigating to TabsScreen...');
        if (mounted) {
          _navigationTriggered = true; // Set flag before navigating
          _showErrorMessage(context, next.errorMessage!); // Show error
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const TabsScreen()),
                (route) => false,
              );
            }
          });
        }
      }
    });

    return WillPopScope(
      onWillPop: () async {
        // Yarış aktifse veya geri sayım varsa onay iste
        if (raceState.isRaceActive || raceState.isPreRaceCountdownActive) {
          return await _showLeaveConfirmationDialog(context, raceNotifier);
        }
        return true; // Yarış aktif değilse direkt çık
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E1E1E),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              // Geri tuşu gibi davran
              if (raceState.isRaceActive ||
                  raceState.isPreRaceCountdownActive) {
                await _showLeaveConfirmationDialog(context, raceNotifier);
              } else {
                Navigator.of(context).pop(); // Yarış yoksa normal pop
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Yarış Odası',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              Text(
                raceState.isPreRaceCountdownActive
                    ? 'Başlıyor...'
                    : (raceState.isRaceActive
                        ? 'Yarış devam ediyor'
                        : 'Yarış bitti'),
                style: TextStyle(
                  fontSize: 14,
                  color: raceState.isPreRaceCountdownActive
                      ? Colors.orangeAccent
                      : (raceState.isRaceActive
                          ? Colors.greenAccent
                          : Colors.redAccent),
                ),
              ),
            ],
          ),
          actions: [
            // Bağlantı durumu göstergesi (Opsiyonel, SignalRService'den alınabilir)
            // Container(...),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Geri Sayım Overlay
              if (raceState.isPreRaceCountdownActive)
                Expanded(
                  child: Container(
                    color: Colors.black.withOpacity(0.7),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Yarış Başlıyor',
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            raceState.preRaceCountdownValue.toString(),
                            style: const TextStyle(
                                fontSize: 96,
                                color: Colors.white,
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
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      // İstatistikler
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                              icon: Icons.timer_outlined,
                              value: _formatDuration(raceState.remainingTime),
                              label: 'Kalan Süre',
                              iconColor: Colors.redAccent,
                              valueColor: raceState.remainingTime.inSeconds < 60
                                  ? Colors.redAccent
                                  : Colors.white,
                            ),
                            if (!raceState.isIndoorRace)
                              _buildStatItem(
                                icon: Icons.directions_run_outlined,
                                value: raceState.currentDistance
                                    .toStringAsFixed(2),
                                label: 'Mesafe (km)',
                                iconColor: Colors.blueAccent,
                                valueColor: Colors.white,
                              ),
                            _buildStatItem(
                              icon: Icons.directions_walk_outlined,
                              value: raceState.currentSteps.toString(),
                              label: 'Adım',
                              iconColor: Colors.greenAccent,
                              valueColor: Colors.white,
                            ),
                            // Hız göstergesi (opsiyonel)
                            // if (!raceState.isIndoorRace) ...
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),
                      // Leaderboard başlığı
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.emoji_events,
                                color: Colors.amber, size: 28),
                            const SizedBox(width: 8),
                            const Text(
                              'Yarış Sıralaması',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      // Leaderboard Listesi
                      Expanded(
                        child: raceState.leaderboard.isEmpty
                            ? Center(
                                child: raceState.isRaceActive
                                    ? const CircularProgressIndicator() // Yarış aktifse yükleniyor
                                    : const Text('Yarışmacı bulunamadı.',
                                        style: TextStyle(
                                            color:
                                                Colors.grey)) // Yarış bittiyse
                                )
                            : ListView.builder(
                                itemCount: raceState.leaderboard.length,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemBuilder: (context, index) {
                                  final participant =
                                      raceState.leaderboard[index];
                                  // Email karşılaştırması büyük/küçük harf duyarsız olmalı
                                  final bool isMe =
                                      participant.email?.toLowerCase() ==
                                          raceState.userEmail?.toLowerCase();
                                  return ParticipantTile(
                                    participant: participant,
                                    isMe: isMe,
                                    profilePictureUrl:
                                        widget.profilePictureCache[
                                            participant.userName],
                                    isIndoorRace: raceState.isIndoorRace,
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              // Hata Mesajı Göstergesi (Opsiyonel)
              if (raceState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Hata: ${raceState.errorMessage}',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI Yardımcıları ---

  // Ayrılma onayı (Notifier'ı çağıracak şekilde güncellendi)
  Future<bool> _showLeaveConfirmationDialog(
      BuildContext context, RaceNotifier raceNotifier) async {
    if (_leaveConfirmationShown)
      return false; // Zaten gösteriliyorsa tekrar gösterme
    _leaveConfirmationShown = true;

    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Kullanıcı dışarı tıklayarak kapatamasın
      builder: (context) => AlertDialog(
        title: const Text('Yarıştan Ayrıl'),
        content: const Text(
            'Yarış devam ediyor. Ayrılmak istediğinize emin misiniz?'), // Mesaj sadeleştirildi
        actions: [
          TextButton(
            onPressed: () {
              _leaveConfirmationShown =
                  false; // Dialog kapandı, tekrar gösterilebilir
              Navigator.of(context).pop(false);
            },
            child: const Text('Hayır'),
          ),
          TextButton(
            onPressed: () {
              _leaveConfirmationShown = false; // Dialog kapandı
              Navigator.of(context).pop(true); // Evet seçildi
            },
            child: const Text('Evet, Ayrıl'),
          ),
        ],
      ),
    );

    if (result == true) {
      debugPrint('Kullanıcı yarıştan ayrılmayı onayladı.');
      await raceNotifier.leaveRace(); // Notifier üzerinden ayrıl
      // Notifier state'i resetleyeceği için UI otomatik güncellenebilir
      // veya burada TabsScreen'e yönlendirme yapılabilir.
      if (context.mounted) {
        // Navigator kullanmadan önce context kontrolü
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const TabsScreen()),
          (route) => false,
        );
      }
      return true; // Geri tuşunun işlemi yapmasını engelle
    } else {
      _leaveConfirmationShown =
          false; // Kullanıcı hayır dedi veya dialog kapandı
    }

    return false; // Geri tuşunun işlemi yapmasını engelleme (dialog kapatıldı)
  }

  // Hata mesajı gösterme fonksiyonu (context alır)
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
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
    Color? valueColor,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: iconColor),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}

class ParticipantTile extends StatelessWidget {
  final RaceParticipant participant;
  final bool isMe;
  final String? profilePictureUrl;
  final bool isIndoorRace;

  const ParticipantTile({
    super.key,
    required this.participant,
    this.isMe = false,
    this.profilePictureUrl,
    required this.isIndoorRace,
  });

  @override
  Widget build(BuildContext context) {
    Color rankColor;
    Color rankTextColor = Colors.black87;
    if (participant.rank == 1) {
      rankColor = const Color(0xFFFFD700);
      rankTextColor = Colors.black;
    } else if (participant.rank == 2) {
      rankColor = const Color(0xFFC0C0C0);
      rankTextColor = Colors.black;
    } else if (participant.rank == 3) {
      rankColor = const Color(0xFFCD7F32);
      rankTextColor = Colors.white;
    } else {
      rankColor = Colors.grey.shade600;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
        border: isMe
            ? Border.all(color: Colors.lightGreenAccent, width: 2.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                UserProfileAvatar(
                  imageUrl: profilePictureUrl,
                  radius: 25,
                ),
                Positioned(
                  top: -4,
                  left: -4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: rankColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade800, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        participant.rank.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: rankTextColor,
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
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: participant.rank <= 3
                              ? rankColor
                              : Colors.lightGreenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        participant.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      if (isMe)
                        const Padding(
                          padding: EdgeInsets.only(left: 6.0),
                          child: Text(
                            '(Ben)',
                            style: TextStyle(
                              fontStyle: FontStyle.normal,
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (!isIndoorRace)
                        _buildInfoChip(
                          label:
                              '${participant.distance.toStringAsFixed(2)} km',
                          backgroundColor:
                              Colors.blue.shade900.withOpacity(0.7),
                          textColor: Colors.blue.shade100,
                        ),
                      if (!isIndoorRace) const SizedBox(width: 8),
                      _buildInfoChip(
                        label: 'Adım: ${participant.steps}',
                        backgroundColor: Colors.green.shade900.withOpacity(0.7),
                        textColor: Colors.green.shade100,
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

  Widget _buildInfoChip({
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
          color: textColor,
        ),
      ),
    );
  }
}
