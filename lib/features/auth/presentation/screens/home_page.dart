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
    await _checkAndRequestLocationPermission();
    // Ensure activity permission is checked *after* location is handled
    if (mounted) {
      await _checkAndRequestActivityPermission();
    }
  }

  // Function to check and request location permission (directly requesting Always)
  Future<void> _checkAndRequestLocationPermission() async {
    final status = await Permission.locationAlways.status;
    print('Ana Sayfa - Konum İzin Durumu (Always): $status');

    if (!status.isGranted && !status.isLimited) {
      final requestedStatus = await Permission.locationAlways.request();
      print('Ana Sayfa - İzin İstenen Durum (Always): $requestedStatus');

      if (requestedStatus.isDenied || requestedStatus.isPermanentlyDenied) {
        if (mounted) {
          _showSettingsDialog('Konum İzni Gerekli',
              'Yarış veya kayıt sırasında mesafenizi arka planda doğru ölçebilmek için "Her Zaman İzin Ver" konum izni gereklidir.');
        }
      }
    } else {
      print('Ana Sayfa - Konum izni zaten verilmiş.');
    }
    // Do not call activity check here, call it sequentially after this function returns
  }

  // Function to check and request Activity Recognition/Motion permission
  Future<void> _checkAndRequestActivityPermission() async {
    Permission activityPermission;
    String permissionName;
    String rationale;

    if (Platform.isAndroid) {
      activityPermission = Permission.activityRecognition;
      permissionName = 'Fiziksel Aktivite İzni';
      rationale =
          'Adımlarınızı sayabilmemiz için fiziksel aktivite izni gereklidir.';
    } else if (Platform.isIOS) {
      activityPermission = Permission.sensors; // Use sensors for motion on iOS
      permissionName = 'Hareket ve Fitness İzni';
      rationale =
          'Adımlarınızı sayabilmemiz için hareket ve fitness izni gereklidir.';
    } else {
      return; // Platform not supported
    }

    final status = await activityPermission.status;
    print('Ana Sayfa - Aktivite İzin Durumu: $status');

    if (!status.isGranted) {
      // Request the permission if not granted
      final requestedStatus = await activityPermission.request();
      print('Ana Sayfa - İzin İstenen Durum (Aktivite): $requestedStatus');

      // If denied after request, show settings dialog
      if (requestedStatus.isDenied || requestedStatus.isPermanentlyDenied) {
        if (mounted) {
          _showSettingsDialog(permissionName, rationale);
        }
      }
    } else {
      print('Ana Sayfa - Aktivite izni zaten verilmiş.');
    }
  }

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
                            onPressed: () {},
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
