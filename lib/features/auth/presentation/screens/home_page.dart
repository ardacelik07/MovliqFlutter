import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/features/auth/presentation/screens/filter_screen.dart';
import '../providers/user_data_provider.dart';
import '../../domain/models/user_data_model.dart'; // <-- Eklendi

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

import 'package:pedometer/pedometer.dart'; // Import pedometer
import 'package:flutter/services.dart'; // Import flutter/services
import '../providers/race_coin_tracker_provider.dart';
import '../widgets/earn_coin_widget.dart'; // Popup için
import '../providers/race_provider.dart'; // For cheatKickedStateProvider
import '../widgets/cheated_race.dart'; // For CheatedRaceDialogContent
import 'help_screen.dart';
import 'profile_screen.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dart:convert'; // Import jsonEncode
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_flutter_project/features/auth/presentation/widgets/font_widget.dart';

// Change to ConsumerStatefulWidget
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

// Create State class
class _HomePageState extends ConsumerState<HomePage> {
  bool _permissionsRequested = false;
  double?
      _persistedBeforeRaceCoin; // Stores before-race coins upon race completion
  bool _isAwaitingPostRaceCoinData =
      false; // True if we are waiting for userDataProvider to update post-race

  @override
  void initState() {
    super.initState();
    _checkPermissionsStatus();

    // Check for cheat kicked status when HomePage initializes and listen for changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Ensure the widget is still in the tree
        final isKicked =
            ref.read(cheatKickedStateProvider); // Read current state
        if (isKicked) {
          _showCheatKickedDialog();
        }
      }
    });

    // Listen for subsequent changes to the cheatKickedStateProvider
    ref.listenManual(cheatKickedStateProvider, (previous, next) {
      if (next == true && mounted) {
        _showCheatKickedDialog();
      }
    });
  }

  Future<void> _checkPermissionsStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _permissionsRequested = prefs.getBool('permissionsRequested') ?? false;

    if (!_permissionsRequested) {
      await _checkAndRequestPermissionsSequentially();
      prefs.setBool('permissionsRequested', true);
    }
  }

  void _showCheatKickedDialog() {
    // Avoid showing dialog if one is already active or not mounted
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;

    showDialog(
      context: context,
      barrierDismissible: false, // User must interact with the dialog
      builder: (BuildContext dialogContext) {
        return const CheatedRaceDialogContent();
      },
    );
    // Provider is reset to false from within the CheatedRaceDialogContent's button.
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
      // For Android: Request Permission.location which handles "While using the app"
      final status = await Permission.location.status;
      print('Ana Sayfa - Android konum izin durumu: $status');

      // Define the critical permission dialog details for races

      if (!status.isGranted && !status.isLimited) {
        final requestedStatus = await Permission.location.request();
        print(
            'Ana Sayfa - Android izin istenen durum (Uygulamayı Kullanırken): $requestedStatus');

        // If permission granted here, it's "While using the app" or "Always"
      } else {
        print(
            'Ana Sayfa - Android konum izni (Uygulamayı Kullanırken veya Her Zaman) zaten verilmiş.');
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
            SnackBar(
              content: Text(
                'Paylaşımın için teşekkürler! Coinlerin hesabına eklendi!',
                style: GoogleFonts.bangers(),
              ),
            ),
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
    final userStreakAsync = ref.watch(userStreakProvider);
    final latestProductsAsync = ref.watch(latestProductProvider);
    print('userDataAsync: ${userDataAsync.value?.coins}');

    final trackingState = ref.watch(raceCoinTrackingProvider);

    // Step 1: Detect race finish and capture necessary data from raceCoinTrackingProvider
    if (trackingState != null &&
        trackingState.justFinishedRace &&
        trackingState.beforeRaceCoin != null) {
      // Only capture and set flags if we aren't already processing a race finish.
      // This prevents re-capturing if HomePage rebuilds for other reasons while waiting for coin data.
      if (!_isAwaitingPostRaceCoinData) {
        _persistedBeforeRaceCoin = trackingState.beforeRaceCoin;
        _isAwaitingPostRaceCoinData = true;
      }
      // Schedule the clearing of raceCoinTrackingProvider state for after this frame.
      // This ensures that its state (justFinishedRace) doesn't persist beyond necessary.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(raceCoinTrackingProvider.notifier).clearState();
        }
      });
    }

    // Step 2: Process captured data when userDataProvider updates
    if (_isAwaitingPostRaceCoinData && _persistedBeforeRaceCoin != null) {
      if (userDataAsync is AsyncData<UserDataModel?>) {
        final double? currentUserData = userDataAsync.value?.coins;
        print('currentUserData: $currentUserData');
        if (currentUserData != null && currentUserData != 0.000) {
          var coinsplus = currentUserData;
          print('coinsplus: $coinsplus');
          final double earnedCoin = coinsplus - _persistedBeforeRaceCoin!;
          print('persistedBeforeRaceCoin: $_persistedBeforeRaceCoin');
          print('currentUserData.coins: $currentUserData');

          print('earnedCoin: $earnedCoin');

          if (earnedCoin > 0.000) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showCoinPopup(context, earnedCoin);
              }
            });
          }
          // Reset flags now that we've processed this specific race finish event
          // (either shown popup or determined no significant earning).
          _isAwaitingPostRaceCoinData = false;
          _persistedBeforeRaceCoin = null;
        } else {
          // userData is loaded but coins are null. This might be a temporary state or an issue.
          // To prevent getting stuck, we reset the flags here as well.
          // If coin data is expected to arrive in a subsequent userData update without a full reload,
          // this might need adjustment, but typically AsyncData means the fetch cycle is complete.
          _isAwaitingPostRaceCoinData = false;
          _persistedBeforeRaceCoin = null;
        }
      } else if (userDataAsync is AsyncError) {
        // If userDataProvider has an error, reset flags to prevent getting stuck.
        _isAwaitingPostRaceCoinData = false;
        _persistedBeforeRaceCoin = null;
      }
      // If userDataAsync is AsyncLoading, we do nothing here.
      // The flags _isAwaitingPostRaceCoinData and _persistedBeforeRaceCoin remain set,
      // so this block will be re-evaluated when userDataAsync provides data or an error.
    }

    // Display loading indicator while user data is loading
    if (userDataAsync is AsyncLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFC4FF62)),
      );
    }

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
                          GestureDetector(
                            onTap: () {
                              // Set the selectedTabProvider to the index of ProfileScreen (4)
                              ref.read(selectedTabProvider.notifier).state = 4;
                              // No need to push TabsScreen again, as HomePage is already within it.
                            },
                            child: UserProfileAvatar(
                              imageUrl: userData?.profilePictureUrl,
                              radius: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Welcome Text - Simpler error/loading handling
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FontWidget(
                                text: userData?.userName ??
                                    'Kullanıcı', // Display name or default
                                styleType: TextStyleType.bodyLarge,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Icons Row
                          Row(
                            children: [
                              Image.asset(
                                'assets/icons/alev.png',
                                width: 20,
                                height: 20,
                              ),

                              const SizedBox(width: 4),
                              userStreakAsync.maybeWhen(
                                data: (streak) => FontWidget(
                                  text: streak.toString(),
                                  styleType: TextStyleType.bodyLarge,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                // Show '-' or loading indicator for non-data states
                                orElse: () => const FontWidget(
                                  text: '-',
                                  styleType: TextStyleType.bodyLarge,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),

                              const SizedBox(width: 4),

                              // Coin Icon & Count
                              Image.asset(
                                'assets/images/mCoin.png',
                                width: 25,
                                height: 25,
                              ),
                              const SizedBox(width: 4),
                              FontWidget(
                                text: userCoins?.toStringAsFixed(2) ??
                                    '0.00', // Format to 2 decimal places
                                styleType: TextStyleType.bodyLarge,
                                color: Colors.white,
                                fontSize: 14,
                              ),

                              Stack(
                                alignment: Alignment.topRight,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                                  HelpScreen()));
                                    },
                                    icon: Image.asset(
                                      'assets/icons/info.png',
                                      width: 20,
                                      height: 20,
                                    ),
                                  ),
                                  // Add badge if needed
                                ],
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
                                      child: FontWidget(
                                        text: 'NEW',
                                        styleType: TextStyleType.titleSmall,
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                // Level Number (Placeholder - varies by index)

                                // Progress Indicator (Placeholder - varies by index)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: FontWidget(
                                    text: index == 0
                                        ? '1/5'
                                        : (index == 1
                                            ? 'Daily'
                                            : 'Weekly'), // Example content variation
                                    styleType: TextStyleType.bodySmall,
                                    color: Colors.white70,
                                    fontSize: 14,
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
                          Image.asset(
                            'assets/icons/invitefriend.png',
                            width: 30,
                            height: 30,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FontWidget(
                                  text: 'Arkadaşını Davet Et',
                                  styleType: TextStyleType.titleLarge,
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                const SizedBox(height: 4),
                                FontWidget(
                                  text: 'Arkadaşını Davet Et, 150 mCoin Kazan',
                                  styleType: TextStyleType.bodyLarge,
                                  color: Colors.grey,
                                  fontSize: 12,
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
                            child: FontWidget(
                              text: 'Davet Et',
                              styleType: TextStyleType.titleSmall,
                              color: Colors.black,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 60),

                    // --- Ready to Race Text ---
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0), // Keep padding
                      child: Column(
                        children: [
                          FontWidget(
                            text: 'Harekete geçmek İçİn hazır mısın?',
                            styleType: TextStyleType.titleLarge,
                            color: Colors.white,
                            fontSize: 18,
                          ),
                          const SizedBox(height: 8),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),

                    // --- Central Action Button ---
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: AnimatedCentralButton(),
                    ),

                    /*

                    // --- Available Products Section ---
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              FontWidget(
                                text: 'Alınabİlİr Ürünler',
                                styleType: TextStyleType.titleMedium,
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              TextButton(
                                onPressed: () {
                                  // Update the provider to switch to the Store tab (index 1)
                                  ref.read(selectedTabProvider.notifier).state =
                                      1;
                                },
                                child: FontWidget(
                                  text: 'Mağaza >',
                                  styleType: TextStyleType.bodyLarge,
                                  color: Color(0xFFC4FF62),
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
                                  return Center(
                                    child: FontWidget(
                                      text: 'Gösterilecek ürün bulunamadı.',
                                      styleType: TextStyleType.bodyLarge,
                                      color: Colors.white70,
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
                                      child: FontWidget(
                                        text: 'Ürünler yüklenemedi.',
                                        styleType: TextStyleType.bodyLarge,
                                        color: Colors.redAccent,
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

                    */

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
                                        child: FontWidget(
                                          text: 'Özel yarışlar yüklenemedi: $error',
                                          styleType: TextStyleType.bodyLarge,
                                          color: Colors.redAccent,
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

  // --- YENİ: Popup gösterme fonksiyonu ---
  void _showCoinPopup(BuildContext context, double coins) {
    // Zaten bir dialog açık mı kontrol et (isteğe bağlı, çift popup engelleme)
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      showDialog(
        context: context,
        barrierDismissible: false, // Dışarı tıklayarak kapatmayı engelle
        builder: (BuildContext dialogContext) {
          return EarnCoinPopup(
            earnedCoin: coins,
            onGoHomePressed: () {
              Navigator.of(dialogContext).pop(); // Sadece popup'ı kapat
            },
          );
        },
      );
    }
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
                  FontWidget(
                    text: product.name, // Use product name
                    styleType: TextStyleType.titleSmall,
                    color: Colors.white,
                    fontSize: 14,
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
                      FontWidget(
                        text: product.price.toString(), // Use product price
                        styleType: TextStyleType.bodySmall,
                        color: Colors.white,
                        fontSize: 14,
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
