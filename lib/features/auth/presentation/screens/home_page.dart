import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/features/auth/presentation/screens/filter_screen.dart';
import '../providers/user_data_provider.dart';
import '../providers/user_ranks_provider.dart'; // For streak
import '../providers/latest_product_provider.dart'; // Import LatestProductProvider
import '../providers/private_race_provider.dart'; // Import PrivateRaceProvider
import '../../domain/models/latest_product_model.dart'; // Import LatestProductModel
import '../../domain/models/private_race_model.dart'; // Import PrivateRaceModel
import 'store_screen.dart'; // Import StoreScreen
import 'package:avatar_glow/avatar_glow.dart'; // Import AvatarGlow
import 'tabs.dart'; // Correct import for the provider defined in tabs.dart
import './product_view_screen.dart'; // Assuming this screen exists
import '../widgets/user_profile_avatar.dart';
import 'package:permission_handler/permission_handler.dart'; // Import permission_handler
import 'dart:io'; // Import Platform
import '../widgets/network_error_widget.dart';
import 'package:http/http.dart' show ClientException; // Specific import
import 'dart:io' show SocketException; // Specific import
import 'package:my_flutter_project/features/auth/presentation/screens/private_races_view.dart'; // Import the new screen
import 'package:share_plus/share_plus.dart'; // Import share_plus
import 'package:my_flutter_project/core/config/api_config.dart'; // Import ApiConfig
import 'package:my_flutter_project/core/services/http_interceptor.dart'; // Import HttpInterceptor
import 'package:geolocator/geolocator.dart'; // Import Geolocator
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher
import 'package:pedometer/pedometer.dart'; // Import pedometer
import 'package:flutter/services.dart'; // Import flutter/services

import 'dart:convert'; // Import jsonEncode

// Change to ConsumerStatefulWidget
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

// Create State class
class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    // Request permissions when the home page initializes
    _checkAndRequestPermissionsSequentially();
  }

  // Request permissions sequentially
  Future<void> _checkAndRequestPermissionsSequentially() async {
    // Önce bildirim iznini iste (en kritik olmayan)
    await _checkAndRequestNotificationPermission();

    // Sonra konum iznini iste
    await _checkAndRequestLocationPermission();

    // En son aktivite iznini iste
    if (mounted) {
      await _checkAndRequestActivityPermission();
    }
  }

  // Bildirim izni kontrolü ve istek işlemi
  Future<void> _checkAndRequestNotificationPermission() async {
    print('Ana Sayfa - Bildirim izni kontrolü başlatılıyor...');

    // iOS ve Android için farklı stratejiler
    if (Platform.isIOS) {
      // iOS için native Swift üzerinden bildirim izni alma
      final bool hasPermission = await _requestIOSNotificationPermission();
      print('Ana Sayfa - iOS bildirim izni: $hasPermission');

      // İzin almak için yeterli, kullanıcı iOS sisteminin kendi dialog kutusunu görecek
    } else {
      // Android için permission_handler kullanımı
      final notificationStatus = await Permission.notification.status;

      if (notificationStatus.isDenied ||
          notificationStatus.isPermanentlyDenied) {
        print(
            'Ana Sayfa - Android bildirim izni reddedilmiş, istek yapılıyor...');
        // Android için izin iste
        final notificationRequest = await Permission.notification.request();

        // Kullanıcıya bilgi ver (opsiyonel)
        if (notificationRequest.isPermanentlyDenied) {
          if (mounted) {
            // Eğer kullanıcı kalıcı olarak reddettiyse
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Bildirim İzni Gerekli'),
                content: const Text(
                    'Bildirim izni olmadan size etkinlikleriniz hakkında haber veremeyiz. Lütfen ayarlardan izin verin.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Kapat'),
                  ),
                  TextButton(
                    onPressed: () {
                      openAppSettings();
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('Ayarlara Git'),
                  ),
                ],
              ),
            );
          }
        }
      } else {
        print('Ana Sayfa - Android bildirim izni zaten var');
      }
    }
  }

  // iOS için native bildirim izni alma
  Future<bool> _requestIOSNotificationPermission() async {
    // Platform mesaj kanalı oluştur - AppDelegate.swift'de tanımlanan kanal ile aynı adı kullan
    const platform = MethodChannel('com.movliq/notifications');

    try {
      // iOS tarafında uygulanan methodu çağır
      final bool result =
          await platform.invokeMethod('requestNotificationPermission');
      return result;
    } catch (e) {
      print('Ana Sayfa - iOS bildirim izni alma hatası: $e');
      return false;
    }
  }

  // iOS için bildirim izin durumu kontrolü (isteğe bağlı kullanılabilir)
  Future<String> _checkIOSNotificationPermission() async {
    const platform = MethodChannel('com.movliq/notifications');

    try {
      final String status =
          await platform.invokeMethod('checkNotificationPermission');
      return status;
    } catch (e) {
      print('Ana Sayfa - iOS bildirim izni kontrolü hatası: $e');
      return 'error';
    }
  }

  // Function to check and request location permission (directly requesting Always)
  Future<void> _checkAndRequestLocationPermission() async {
    print('Ana Sayfa - Konum izni kontrolü başlatılıyor...');

    // First check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen konum servislerini açın'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Show system location settings
      await Geolocator.openLocationSettings();
      return;
    }

    // Use different approaches based on platform
    if (Platform.isIOS) {
      // For iOS: Use Geolocator directly which works better
      LocationPermission permission = await Geolocator.checkPermission();
      print('Ana Sayfa - iOS konum izni durumu: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('Ana Sayfa - iOS konum izni istendikten sonra: $permission');
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {}
      } else {
        print('Ana Sayfa - iOS konum izni alındı: $permission');
      }
    } else {
      // For Android: Request Permission.location first to show the standard system dialog.
      final status = await Permission.location.status;
      print('Ana Sayfa - Android konum izin durumu (Genel): $status');

      // Define the critical permission dialog details for races
      const String criticalDialogTitle = 'Her Zaman Konum İzni Gerekli';
      const String criticalDialogContent =
          'Yarışlara kesintisiz katılabilmek ve aktivite verilerinizi doğru bir şekilde kaydedebilmek için Movliq\'in konumunuza \'Her Zaman\' erişmesi gerekmektedir. Lütfen uygulama ayarlarından konum iznini \'Her zaman izin ver\' olarak güncelleyiniz.';

      if (!status.isGranted && !status.isLimited) {
        final requestedStatus = await Permission.location.request();
        print(
            'Ana Sayfa - Android izin istenen durum (Genel): $requestedStatus');

        if (requestedStatus.isPermanentlyDenied) {
          if (mounted) {
            _showSettingsDialog(criticalDialogTitle, criticalDialogContent);
          }
        } else if (requestedStatus.isDenied) {
          print(
              'Ana Sayfa - Android konum izni (Genel) reddedildi ancak kalıcı değil.');
          if (mounted) {
            _showSettingsDialog(criticalDialogTitle, criticalDialogContent);
          }
        }
        // If permission granted here, proceed to check for 'Always'
      }

      // After the initial request (or if already granted), check current general status again
      // to decide if we should proceed to request 'Always'.
      final currentGeneralLocationStatus = await Permission.location.status;
      if (currentGeneralLocationStatus.isGranted ||
          currentGeneralLocationStatus.isLimited) {
        print(
            'Ana Sayfa - Android konum izni (Genel) verilmiş veya kısıtlı. Şimdi "Always" kontrol ediliyor.');

        final alwaysStatus = await Permission.locationAlways.status;
        print(
            'Ana Sayfa - Android "Always" konum izin durumu kontrol ediliyor: $alwaysStatus');

        if (!alwaysStatus.isGranted) {
          print(
              'Ana Sayfa - "Genel/Kullanımda" izni var, ancak "Always" izni yok. "Always" izni isteniyor.');
          // Requesting locationAlways typically opens settings directly on modern Android.
          final requestedAlwaysStatus =
              await Permission.locationAlways.request();
          print(
              'Ana Sayfa - Android "Always" izin talep sonucu: $requestedAlwaysStatus');

          // After the request, check the status again.
          // If still not granted (denied or permanently denied), show the dialog.
          final finalAlwaysStatus = await Permission.locationAlways.status;
          if (!finalAlwaysStatus.isGranted) {
            if (mounted) {
              _showSettingsDialog(criticalDialogTitle, criticalDialogContent);
            }
          } else {
            print('Ana Sayfa - Android "Always" konum izni şimdi verildi.');
          }
        } else {
          print('Ana Sayfa - Android "Always" konum izni zaten verilmiş.');
        }
      } else {
        // This means general location was not granted even after an attempt (if made).
        // The dialogs for denied/permanentlyDenied for the initial request should have been shown.
        print(
            'Ana Sayfa - Genel konum izni hala verilmemiş, bu nedenle "Always" istenemiyor/kontrol edilemiyor.');
      }
    }
  }

  // Function to check and request Activity Recognition/Motion permission
  Future<void> _checkAndRequestActivityPermission() async {
    if (Platform.isAndroid) {
      // Android işlemi aynı kalıyor
      final status = await Permission.activityRecognition.status;
      print('Ana Sayfa - Android aktivite izin durumu: $status');

      if (!status.isGranted) {
        final requestedStatus = await Permission.activityRecognition.request();
        print(
            'Ana Sayfa - Android aktivite izin istenen durum: $requestedStatus');

        if (requestedStatus.isDenied || requestedStatus.isPermanentlyDenied) {
          if (mounted) {
            _showSettingsDialog('Aktivite İzni Gerekli',
                'Adımlarınızı sayabilmek için aktivite izni gereklidir.');
          }
        }
      } else {
        print('Ana Sayfa - Android aktivite izni zaten verilmiş.');
      }
    } else if (Platform.isIOS) {
      // iOS için: Health Kit izinlerini kontrol et
      // Önce normal sensör iznini iste
      final sensorStatus = await Permission.sensors.request();
      print('Ana Sayfa - iOS sensör izin durumu: $sensorStatus');

      // Health Kit izinlerinin verilip verilmediğini kontrol etmek için
      try {
        // Pedometer stream'ini 3 saniyeliğine dinle, veri gelirse izin verilmiş demektir
        bool healthKitPermissionVerified = false;

        final subscription = Pedometer.stepCountStream.listen((step) {
          print(
              'HomePage - Adım algılandı: ${step.steps}, Health Kit izinleri verilmiş');
          healthKitPermissionVerified = true;
        }, onError: (error) {
          print('HomePage - Adım algılama hatası: $error');
        });

        // Kısa bir süre bekle
        await Future.delayed(const Duration(seconds: 3));
        subscription.cancel();

        // Eğer Health Kit verisi alınamadıysa dialog göster
        if (!healthKitPermissionVerified && mounted) {
          print(
              'Ana Sayfa - Health Kit izinleri verilmemiş, kullanıcıyı yönlendiriyoruz');
        } else {
          print(
              'Ana Sayfa - Health Kit izinleri verilmiş veya başarıyla algılandı');
        }
      } catch (e) {
        print('Ana Sayfa - Health Kit izin kontrolü sırasında hata: $e');
        if (mounted) {}
      }
    }
  }

  // Health Kit izni için özel dialog (iOS)

  // Dialog to show if permission is denied (Consolidated for Settings)
  void _showSettingsDialog(String title, String content) {
    if (!mounted) return; // Check again before showing dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text('$content Lütfen uygulama ayarlarından bu izni verin.'),
        actions: [
          TextButton(
            child: const Text('Ayarları Aç'),
            onPressed: () {
              openAppSettings(); // Open app settings
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _shareAppLink() async {
    const String playStoreLink =
        "https://play.google.com/store/apps/details?id=com.example.my_flutter_project"; // TODO: Kendi Play Store ID'nizi girin
    const String appStoreLink =
        "https://apps.apple.com/app/idYOUR_APP_ID"; // TODO: Kendi App Store ID'nizi girin
    const String fallbackLink = "https://movliq.com/indir";

    String shareMessage;
    if (Platform.isAndroid) {
      shareMessage = "Hey! Movliq uygulamasını denemelisin: $playStoreLink";
    } else if (Platform.isIOS) {
      shareMessage = "Hey! Movliq uygulamasını denemelisin: $appStoreLink";
    } else {
      shareMessage = "Hey! Movliq uygulamasını denemelisin: $fallbackLink";
    }

    try {
      await Share.share(shareMessage, subject: 'Movliq Uygulamasını Deneyin!');

      bool apiCallSuccessful = await _callYourOneTimeShareRewardApi();

      if (apiCallSuccessful) {
        print(
            'Tek kullanımlık paylaşım ödülü APIsi başarıyla çağrıldı ve coin verildi.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Paylaşımın için teşekkürler! Coinlerin hesabına eklendi!')),
          );
          ref.invalidate(
              userDataProvider); // Coin miktarını UI'da yenilemek için
          ref.read(userDataProvider.notifier).fetchCoins();
        }
      } else {
        return;
      }
    } catch (e) {
      print('Paylaşım diyalogu sırasında hata oluştu: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paylaşım başlatılamadı.')),
        );
      }
    }
  }

  Future<bool> _callYourOneTimeShareRewardApi() async {
    try {
      // HttpInterceptor, Authorization başlığını otomatik olarak ekleyecektir.
      final response = await HttpInterceptor.post(
        Uri.parse(
            '${ApiConfig.baseUrl}/User/claim-initial-bonus'), // ApiConfig baseUrl varsayılıyor
        // Eğer API'niz bir body beklemiyorsa, body parametresini vermeyebilirsiniz
        // veya boş bir JSON objesi gönderebilirsiniz: body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        print('Claim initial bonus API call successful: ${response.body}');
        // API'den dönen yanıta göre ek kontroller yapabilirsiniz (örn: response.body parse edilebilir)
        return true; // Başarılı
      } else {
        return false; // Başarısız
      }
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userDataAsync = ref.watch(userDataProvider);
    final userStreakAsync =
        ref.watch(userStreakProvider); // Watch streak provider
    final latestProductsAsync =
        ref.watch(latestProductProvider); // Watch latest products

    return Scaffold(
      backgroundColor: Colors.black, // Set background to black
      body: userDataAsync.when(
        data: (userData) {
          // userData might still be null initially while fetching after login
          // We might need coins even if userData is slightly delayed, handle nulls gracefully
          final userCoins = userData?.coins;

          // If userData is definitively null after fetch attempt (e.g., error state previously cleared),
          // show a loading or error state. For simplicity, we'll proceed if it was fetched, even if null.
          // A more robust solution might involve checking the provider's state flags if available.

          return Container(
            // Keep the gradient if needed, or just use black
            decoration: const BoxDecoration(
              color: Colors.black, // Use black background
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                // Make the content scrollable
                child: Column(
                  children: [
                    // --- New Top Bar ---
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      child: Row(
                        children: [
                          // Profile picture - Simpler error/loading handling
                          UserProfileAvatar(
                            imageUrl: userData?.profilePictureUrl,
                            radius: 24,
                          ),
                          const SizedBox(width: 12),
                          // Welcome Text - Simpler error/loading handling
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hoşgeldiniz',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[400],
                                ),
                              ),
                              Text(
                                userData?.userName ??
                                    'Kullanıcı', // Display name or default
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Icons Row
                          Row(
                            children: [
                              // Notification Icon (Placeholder)
                              Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  Icon(Icons.notifications_outlined,
                                      color: Colors.white, size: 26),
                                  // Add badge if needed
                                ],
                              ),
                              const SizedBox(width: 12),
                              // Coin Icon & Count
                              Image.asset(
                                'assets/images/mCoin.png',
                                width: 25,
                                height: 25,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                userCoins?.toStringAsFixed(2) ??
                                    '0.00', // Format to 2 decimal places
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                              const SizedBox(width: 12),
                              // Streak Icon & Count - Simpler error/loading
                              const Icon(Icons.local_fire_department,
                                  color: Colors.deepOrangeAccent, size: 22),
                              const SizedBox(width: 4),
                              userStreakAsync.maybeWhen(
                                data: (streak) => Text(
                                  streak.toString(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                                // Show '-' or loading indicator for non-data states
                                orElse: () => const Text(
                                  '-',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // --- Level Card (Now a PageView Slider) ---
                    SizedBox(
                      height: 170, // Adjust height for the slider area
                      child: PageView.builder(
                        controller: PageController(
                            viewportFraction:
                                0.9), // Shows parts of adjacent pages
                        padEnds: false, // Don't add padding at the ends
                        itemCount: 3, // Placeholder count for demonstration
                        itemBuilder: (context, index) {
                          // Define the image path based on the index
                          final imagePaths = [
                            'assets/images/slidebar1.jpeg',
                            'assets/images/slidebar2.jpeg',
                            'assets/images/slidebar3.jpeg',
                          ];
                          // Use modulo in case itemCount changes later, although currently it's 3
                          final imagePath =
                              imagePaths[index % imagePaths.length];

                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical:
                                    8.0), // Add horizontal margin between cards
                            padding: const EdgeInsets.all(20.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20.0),
                              image: DecorationImage(
                                image: AssetImage(imagePath),
                                fit: BoxFit
                                    .cover, // Make image cover the container
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // NEW Tag (Only for the first item in this example)
                                if (index == 0)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Text(
                                        'NEW',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                // Level Number (Placeholder - varies by index)

                                // Progress Indicator (Placeholder - varies by index)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Text(
                                    index == 0
                                        ? '1/5'
                                        : (index == 1
                                            ? 'Daily'
                                            : 'Weekly'), // Example content variation
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- Invite Friend Card ---
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16.0),
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.group_add_outlined,
                              color: Color(0xFFC4FF62), size: 30),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Arkadaşını Davet Et',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Her arkadaşın için 500 mPara',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _shareAppLink,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFFC4FF62),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                            ),
                            child: const Text('Davet Et'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- Ready to Race Text ---
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0), // Keep padding
                      child: Column(
                        children: [
                          const Text(
                            'Yarışa hazır mısın?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Kardiyoyu eğlenceli hale getirin! Canlı bir yarışa katılmak ve benzersiz ödüller kazanmak için hemen tıklayın!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),

                    // --- Central Action Button ---
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: AnimatedCentralButton(),
                    ),

                    // --- Available Products Section ---
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Alınabilir Ürünler',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                              TextButton(
                                onPressed: () {
                                  // Update the provider to switch to the Store tab (index 1)
                                  ref.read(selectedTabProvider.notifier).state =
                                      1;
                                },
                                child: const Text(
                                  'Mağaza >',
                                  style: TextStyle(color: Color(0xFFC4FF62)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            // height: 200, // REMOVE fixed height constraint
                            // Keep the specific error handling for products here
                            child: latestProductsAsync.when(
                              data: (products) {
                                if (products.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      'Gösterilecek ürün bulunamadı.',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                  );
                                }
                                // Wrap the ListView.builder with SizedBox when there's data
                                return SizedBox(
                                  height:
                                      200, // Restore height constraint for the list
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: products.length,
                                    itemBuilder: (context, index) {
                                      final LatestProductModel product =
                                          products[index];
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 12.0),
                                        child: _ProductCard(product: product),
                                      );
                                    },
                                  ),
                                );
                              },
                              loading: () => const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white)),
                              error: (error, stackTrace) {
                                // Check for network errors IN THIS SECTION
                                if (error is SocketException ||
                                    error is ClientException) {
                                  return Center(
                                    child: NetworkErrorWidget(
                                      onRetry: () {
                                        ref.invalidate(
                                            latestProductProvider); // Retry fetch
                                      },
                                    ),
                                  );
                                } else {
                                  // Display other errors for products
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: SelectableText(
                                        'Ürünler yüklenemedi: $error',
                                        style: const TextStyle(
                                            color: Colors.redAccent),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // --- Special Races Section (Horizontal Scroll) ---
                    /*Padding(
                      padding: const EdgeInsets.only(
                          left: 16.0,
                          top: 16.0,
                          bottom: 16.0,
                          right: 0), // Adjust padding
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(
                                right: 16.0), // Add padding for title if needed
                            child: Text(
                              'Özel Yarışlar',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height:
                                150, // Define height for the horizontal list items
                            child: Consumer(
                              // Use Consumer to watch the provider here
                              builder: (context, ref, child) {
                                final specialRacesAsync =
                                    ref.watch(privateRaceProvider);
                                return specialRacesAsync.when(
                                  data: (races) {
                                    if (races.isEmpty) {
                                      return const Center(
                                        child: Text(
                                          'Aktif özel yarış bulunamadı.',
                                          style:
                                              TextStyle(color: Colors.white70),
                                        ),
                                      );
                                    }
                                    return ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: races
                                          .length, // Use fetched data length
                                      itemBuilder: (context, index) {
                                        final PrivateRaceModel race =
                                            races[index];

                                        return InkWell(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    PrivateRacesView(
                                                  // Pass the fetched race data
                                                  race: race,
                                                ),
                                              ),
                                            );
                                          },
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          child: Container(
                                            width: MediaQuery.of(context)
                                                    .size
                                                    .width *
                                                0.7,
                                            margin: const EdgeInsets.only(
                                                right: 12.0),
                                            padding: const EdgeInsets.all(16.0),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(12.0),
                                              image: DecorationImage(
                                                image: NetworkImage(
                                                    race.imagePath ?? ''),
                                                fit: BoxFit.cover,
                                                colorFilter: ColorFilter.mode(
                                                  Colors.black.withOpacity(0.5),
                                                  BlendMode.darken,
                                                ),
                                                // Add errorBuilder for NetworkImage
                                                onError:
                                                    (exception, stackTrace) {
                                                  print(
                                                      "Error loading race image: ${race.imagePath}, Error: $exception");
                                                  // Optionally show a placeholder
                                                },
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    race.specialRaceRoomName ??
                                                        'Özel Yarış',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                // Participant count is not in the current API response
                                                // You might want to fetch this separately or adjust the model/API
                                                // Row(
                                                //   mainAxisSize: MainAxisSize.min,
                                                //   children: [
                                                //     Icon(Icons.group_outlined, color: Colors.white70, size: 18),
                                                //     SizedBox(width: 6),
                                                //     Text(
                                                //       '? K', // Placeholder or fetch participant count
                                                //       style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                                                //     ),
                                                //   ],
                                                // ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  loading: () => const Center(
                                      child: CircularProgressIndicator(
                                          color: Colors.white)),
                                  error: (error, stackTrace) {
                                    print(
                                        'Error loading special races: $error\n$stackTrace');
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: SelectableText(
                                          'Özel yarışlar yüklenemedi: $error',
                                          style: const TextStyle(
                                              color: Colors.redAccent),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),*/
                    const SizedBox(height: 20), // Add some bottom padding
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFFC4FF62))),
        error: (error, stackTrace) {
          // ALWAYS show NetworkErrorWidget for any full-screen error
          return Center(
            child: NetworkErrorWidget(
              // Provide generic title/message for all errors
              title: 'Ana Sayfa Yüklenemedi',
              message: 'Bir sorun oluştu, lütfen tekrar deneyin.',
              onRetry: () {
                // Invalidate all relevant providers on retry
                ref.invalidate(userDataProvider);
                ref.invalidate(userStreakProvider);
                ref.invalidate(latestProductProvider);
              },
            ),
          );
        },
      ),
    );
  }
}

// Extracted Animated Central Button Widget BUTON ANIMASYONU
class AnimatedCentralButton extends ConsumerStatefulWidget {
  const AnimatedCentralButton({super.key});

  @override
  ConsumerState<AnimatedCentralButton> createState() =>
      _AnimatedCentralButtonState();
}

class _AnimatedCentralButtonState extends ConsumerState<AnimatedCentralButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        // Navigate on tap up
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FilterScreen(),
          ),
        );
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AvatarGlow(
          glowColor: Color(0xFFC4FF62),
          glowRadiusFactor: 0.3,
          duration: Duration(milliseconds: 2000),
          repeat: true,
          startDelay: Duration(milliseconds: 100),
          child: Material(
            elevation: 8.0,
            shape: CircleBorder(),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFC4FF62), // Movliq green
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 80,
                  height: 80,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Separate Product Card Widget
class _ProductCard extends StatelessWidget {
  final LatestProductModel product;

  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    // Wrap the card with InkWell for tap feedback and navigation
    return InkWell(
      onTap: () {
        print("📦 Tapped product: ${product.name} (ID: ${product.id})");
        // Navigate to ProductViewScreen, passing only the product ID
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductViewScreen(productId: product.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16.0), // Match card border radius
      child: Container(
        width: 150, // Adjust width
        // Removed margin from Container, InkWell handles interaction area
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16.0)),
                child: Image.network(
                  product.mainImageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (BuildContext context, Widget child,
                      ImageChunkEvent? loadingProgress) {
                    if (loadingProgress == null) return child; // Image loaded
                    return Container(
                      color: Colors.grey[800], // Placeholder background
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.white54,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (BuildContext context, Object exception,
                      StackTrace? stackTrace) {
                    print(
                        "❌ Error loading image: ${product.mainImageUrl}, Error: $exception");
                    return Container(
                      color: Colors.grey[800],
                      child: const Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: Colors.redAccent)),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name, // Use product name
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/mCoin.png',
                        width: 16,
                        height: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        product.price.toString(), // Use product price
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
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

// --- Available Products Section ---
