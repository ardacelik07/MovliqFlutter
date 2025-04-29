import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../screens/tabs.dart';
import '../../../../core/services/storage_service.dart';
import 'finish_race_screen.dart';
import '../widgets/user_profile_avatar.dart';
import '../providers/race_provider.dart';
import '../../domain/models/race_state.dart';
import '../../../../core/services/race_service_channel.dart';

class RaceScreen extends ConsumerStatefulWidget {
  final int roomId;
  final String? myUsername;
  final int? raceDuration; // Minutes
  final Map<String, String?> profilePictureCache;
  final bool isIndoorRace; // Indoor yarış tipini belirlemek için yeni parametre

  const RaceScreen({
    super.key,
    required this.roomId,
    this.myUsername,
    this.raceDuration,
    required this.profilePictureCache,
    required this.isIndoorRace,
  });

  @override
  ConsumerState<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends ConsumerState<RaceScreen> {
  @override
  void initState() {
    super.initState();
    log('RaceScreen initState for roomId: ${widget.roomId}',
        name: 'RaceScreen');
  }

  Future<bool> _checkAndRequestPermissions() async {
    List<Permission> permissionsToRequest = [];

    // Ortak İzinler
    if (Platform.isAndroid) {
      permissionsToRequest.add(Permission.activityRecognition);
      // Android 13+ için bildirim izni
      if (await _isAndroid13OrHigher()) {
        permissionsToRequest.add(Permission.notification);
      }
    } else if (Platform.isIOS) {
      permissionsToRequest.add(Permission.sensors); // iOS Motion
    }

    // Konum (Sadece Outdoor)
    if (!widget.isIndoorRace) {
      permissionsToRequest.add(Permission.locationAlways);
    }

    Map<Permission, PermissionStatus> statuses =
        await permissionsToRequest.request();

    bool allGranted = true;
    bool locationRationaleShown = false;
    bool needsSettingsRedirect = false;

    statuses.forEach((permission, status) {
      debugPrint("Permission Status [${permission.toString()}]: $status");
      if (!status.isGranted && !status.isLimited) {
        // Limited iOS'ta konum için OK olabilir
        allGranted = false;
        // Kullanıcı kalıcı olarak reddettiyse veya Always izni için
        if (status.isPermanentlyDenied ||
            (permission == Permission.locationAlways && status.isDenied)) {
          needsSettingsRedirect = true;
        }
      }
    });

    // Konum servislerini kontrol et (Sadece Outdoor)
    if (!widget.isIndoorRace) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        allGranted = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lütfen konum servislerini açın.')),
          );
          await Geolocator.openLocationSettings(); // Ayarları aç
        }
      }
    }

    if (!allGranted && mounted) {
      String message = 'Yarışı başlatmak için gerekli izinler alınamadı.';
      if (needsSettingsRedirect) {
        message += ' Lütfen uygulama ayarlarından izinleri kontrol edin.';
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('İzin Gerekli'),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => openAppSettings(),
                  child: Text('Ayarları Aç')),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Tamam')),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }

    return allGranted;
  }

  Future<bool> _isAndroid13OrHigher() async {
    if (Platform.isAndroid) {
      // Gerçek implementasyon device_info_plus gibi bir paketle yapılmalı
      // Şimdilik basit bir varsayım yapalım
      try {
        // Bu yöntem güvenilir değil, sadece örnek
        // final androidInfo = await DeviceInfoPlugin().androidInfo;
        // return androidInfo.version.sdkInt >= 33;
        return true; // Şimdilik true varsayalım
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  @override
  void dispose() {
    // Eğer SignalR dinleyicileri kaldıysa burada kapatılmalı
    // SignalRService.instance.hubConnection?.off('UpdateLeaderboard');

    // Yarış hala aktifse servisi durdurmayı dene (ÖNEMLİ)
    final currentStatus = ref.read(raceProvider).status;
    if (currentStatus == RaceStatus.running ||
        currentStatus == RaceStatus.paused) {
      print("RaceScreen dispose: Stopping race service...");
      ref.read(raceProvider.notifier).stopRace();
    }

    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final duration = Duration(seconds: totalSeconds);
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    final raceState = ref.watch(raceProvider);
    log('RaceScreen build triggered. Status: ${raceState.status}',
        name: 'RaceScreen');

    final bool canStart = raceState.status == RaceStatus.idle ||
        raceState.status == RaceStatus.stopped ||
        raceState.status == RaceStatus.error;
    final bool canStop = raceState.status == RaceStatus.running ||
        raceState.status == RaceStatus.paused;
    final bool isLoading = raceState.status == RaceStatus.starting;

    // Hata durumunu göster
    if (raceState.status == RaceStatus.error) {
      log('Displaying error state: ${raceState.errorMessage}',
          name: 'RaceScreen');
      return Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: AppBar(
          title: const Text('Yarış Hatası'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const TabsScreen()),
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Yarış sırasında bir hata oluştu: \n${raceState.errorMessage ?? "Bilinmeyen hata."}\nLütfen tekrar deneyin.',
              style: const TextStyle(color: Colors.redAccent, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Servis hala başlıyorsa veya idle ise yükleniyor göster
    if (raceState.status == RaceStatus.starting ||
        raceState.status == RaceStatus.idle) {
      log('Displaying loading state (starting or idle).', name: 'RaceScreen');
      return Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: AppBar(
          title: const Text('Yarış Başlıyor...'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false, // Geri butonu olmasın
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text('Servis başlatılıyor ve bağlantı kuruluyor...',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    // Ana yarış ekranı
    log('Displaying main race screen (running or paused).', name: 'RaceScreen');
    return Scaffold(
      backgroundColor: Colors.grey[900], // Koyu tema arkaplan
      appBar: AppBar(
        title: const Text('Yarış Odası'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => _showExitConfirmationDialog(context, raceState),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  raceState.status == RaceStatus.running
                      ? 'Devam Ediyor'
                      : 'Duraklatıldı',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Üstteki Metrikler Kartı
          _buildMetricsCard(raceState),
          const SizedBox(height: 20),

          // Yarış Sıralaması Başlığı
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  'Yarış Sıralaması',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Liderlik Tablosu Listesi
          Expanded(
            child: _buildLeaderboard(raceState.leaderboard),
          ),

          // Bitir Butonu
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('BİTİR'),
              onPressed: () =>
                  _showFinishConfirmationDialog(context, raceState),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50), // Geniş buton
                textStyle:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.0),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Çıkış Onay Dialogu
  void _showExitConfirmationDialog(BuildContext context, RaceState raceState) {
    log('Showing exit confirmation dialog.', name: 'RaceScreen');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yarıştan Çık'),
        content: const Text(
            'Yarıştan çıkmak istediğinize emin misiniz? İlerlemeniz kaydedilmeyecek.'),
        actions: <Widget>[
          TextButton(
            child: const Text('Hayır'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Evet'),
            onPressed: () {
              log('Exiting race early.', name: 'RaceScreen');
              Navigator.of(ctx).pop();
              ref.read(raceProvider.notifier).stopRace();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const TabsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  // Bitirme Onay Dialogu
  void _showFinishConfirmationDialog(
      BuildContext context, RaceState raceState) {
    log('Showing finish confirmation dialog.', name: 'RaceScreen');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yarışı Bitir'),
        content: const Text('Yarışı bitirmek istediğinize emin misiniz?'),
        actions: <Widget>[
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Bitir'),
            onPressed: () {
              Navigator.of(ctx).pop();
              _finishRace(context, raceState);
            },
          ),
        ],
      ),
    );
  }

  // Yarışı bitirme fonksiyonu
  void _finishRace(BuildContext context, RaceState raceState) {
    log('Finish race action triggered.', name: 'RaceScreen');
    final notifier = ref.read(raceProvider.notifier);
    notifier.stopRace();

    // TODO: FinishRaceScreen parametrelerini kontrol et ve güncelle
    // Navigator.of(context).pushReplacement(
    //   MaterialPageRoute(
    //     builder: (ctx) => FinishRaceScreen(
    //       // Muhtemelen bu parametreler yok veya farklı?
    //       // duration: raceState.elapsedSeconds,
    //       // distance: raceState.distanceKm,
    //       // steps: raceState.steps,
    //       // averageSpeed: ...,
    //       raceResult: raceState, // Belki tüm state'i gönderiyordur?
    //     ),
    //   ),
    // );
    // Şimdilik ana ekrana dönelim
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const TabsScreen()),
    );
  }

  // Metrikleri gösteren kart widget'ı (Güncellendi)
  Widget _buildMetricsCard(RaceState raceState) {
    final String formattedTime =
        _formatDuration(raceState.remainingSeconds ?? raceState.elapsedSeconds);
    final String timeLabel =
        raceState.remainingSeconds != null ? 'Kalan Süre' : 'Geçen Süre';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
      decoration: BoxDecoration(
          color: Colors.grey[850], // Biraz daha açık gri
          borderRadius: BorderRadius.circular(15.0),
          boxShadow: [
            BoxShadow(
                color: Colors.black26, blurRadius: 5, offset: Offset(0, 2))
          ]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start, // Hizalamayı başa al
        children: [
          _MetricItem(
              icon: Icons.timer,
              iconColor: Colors.redAccent,
              value: formattedTime,
              label: timeLabel),
          _MetricItem(
              icon: Icons.directions_run,
              iconColor: Colors.blueAccent,
              value: raceState.distanceKm.toStringAsFixed(2),
              label: 'Mesafe (km)'),
          _MetricItem(
              icon: Icons.directions_walk,
              iconColor: Colors.greenAccent,
              value: raceState.steps.toString(),
              label: 'Adım'),
          // Hız km/adım yerine km/h olmalı. Servisten gelen speedKmh kullanılacak.
          _MetricItem(
              icon: Icons.speed,
              iconColor: Colors.orangeAccent,
              value: raceState.speedKmh.toStringAsFixed(1),
              label: 'Hız (km/s)'),
        ],
      ),
    );
  }

  // Liderlik tablosunu oluşturan widget (Güncellendi)
  Widget _buildLeaderboard(List<RaceParticipant> leaderboard) {
    if (leaderboard.isEmpty) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Text('Liderlik tablosu bekleniyor...',
            style: TextStyle(color: Colors.white70)),
      ));
    }

    final sortedLeaderboard = List<RaceParticipant>.from(leaderboard)
      ..sort((a, b) => a.rank.compareTo(b.rank));

    // TODO: Kendi kullanıcısını bul ve vurgula
    // final myEmail = ref.watch(userEmailProvider); // Varsayımsal provider

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: sortedLeaderboard.length,
      itemBuilder: (context, index) {
        final participant = sortedLeaderboard[index];
        // final bool isMe = participant.email == myEmail;
        final bool isMe = false; // Şimdilik hep false

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 5),
          color: isMe ? Colors.green.withOpacity(0.3) : Colors.grey[800],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors
                    .primaries[participant.rank % Colors.primaries.length]
                    .withOpacity(0.5),
                child: Text(
                  participant.rank.toString(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                '${participant.userName}${isMe ? " (Ben)" : ""}',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${participant.distance.toStringAsFixed(2)} km',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('${participant.steps} Adım',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              )
              // trailing: UserProfileAvatar(email: participant.email) // Profil resmi?
              ),
        );
      },
    );
  }
}

// Tek bir metrik öğesini gösteren yardımcı widget (Güncellendi)
class _MetricItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _MetricItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.2),
            radius: 20,
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16, // Biraz küçültüldü
              fontWeight: FontWeight.bold,
              color: Colors.white, // Değerler beyaz
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10, // Biraz küçültüldü
              color: Colors.grey[400],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
