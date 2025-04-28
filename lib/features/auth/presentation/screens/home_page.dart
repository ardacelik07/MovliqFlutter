import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/features/auth/presentation/screens/filter_screen.dart';
import '../providers/user_data_provider.dart';
import '../providers/user_ranks_provider.dart'; // For streak
import '../providers/latest_product_provider.dart'; // Import LatestProductProvider
import '../../domain/models/latest_product_model.dart'; // Import LatestProductModel// For caching images
import 'store_screen.dart'; // Import StoreScreen
import 'package:avatar_glow/avatar_glow.dart'; // Import AvatarGlow
import 'tabs.dart'; // Correct import for the provider defined in tabs.dart
import './product_view_screen.dart'; // Assuming this screen exists
import '../widgets/user_profile_avatar.dart';
import 'package:permission_handler/permission_handler.dart'; // Import permission_handler
import 'dart:io'; // Import Platform

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
    final userCoinsAsync = userDataAsync.value?.coins;

    return Scaffold(
      backgroundColor: Colors.black, // Set background to black
      body: Container(
        // Keep the gradient if needed, or just use black
        decoration: const BoxDecoration(
          color: Colors.black, // Use black background
          // gradient: LinearGradient(
          //   begin: Alignment.topCenter,
          //   stops: [0.0, 0.95],
          //   end: Alignment.bottomCenter,
          //   colors: [
          //     Color(0xFFC4FF62),
          //     Color.fromARGB(255, 0, 0, 0),
          //   ],
          // ),
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
                      // Profile picture - Updated to use UserProfileAvatar
                      userDataAsync.when(
                        data: (userData) => UserProfileAvatar(
                          imageUrl: userData?.profilePictureUrl,
                          radius: 24,
                        ),
                        loading: () => const CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey,
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white)),
                        ),
                        error: (_, __) => const UserProfileAvatar(
                          // Show default avatar on error as well
                          imageUrl: null,
                          radius: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Welcome Text
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
                          userDataAsync.when(
                            data: (userData) => Text(
                              userData?.userName ?? 'Kullanıcı', // Display name
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            loading: () => const Text(
                              'Yükleniyor...',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.white70),
                            ),
                            error: (_, __) => const Text(
                              'Kullanıcı',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
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
                              // Add a badge if there are notifications
                              // Positioned(
                              //   right: 0,
                              //   top: 0,
                              //   child: Container(
                              //     padding: EdgeInsets.all(2),
                              //     decoration: BoxDecoration(
                              //       color: Colors.red,
                              //       shape: BoxShape.circle,
                              //     ),
                              //     constraints: BoxConstraints(
                              //       minWidth: 8,
                              //       minHeight: 8,
                              //     ),
                              //   ),
                              // ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          // Coin Icon & Count (Placeholder)
                          const Icon(Icons.monetization_on,
                              color: Colors.amber, size: 22),
                          const SizedBox(width: 4),
                          Text(
                            userCoinsAsync.toString(), // Placeholder Coin Count
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14),
                          ),
                          const SizedBox(width: 12),
                          // Streak Icon & Count
                          const Icon(Icons.local_fire_department,
                              color: Colors.deepOrangeAccent, size: 22),
                          const SizedBox(width: 4),
                          userStreakAsync.when(
                            data: (streak) => Text(
                              streak.toString(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                            loading: () => const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white)),
                            error: (_, __) => const Text(
                              '0', // Default on error
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
                        viewportFraction: 0.9), // Shows parts of adjacent pages
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
                      final imagePath = imagePaths[index % imagePaths.length];

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
                            fit: BoxFit.cover, // Make image cover the container
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
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
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
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
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
                              ref.read(selectedTabProvider.notifier).state = 1;
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
                        height: 200, // Adjust height for product cards
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
                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: products.length,
                              itemBuilder: (context, index) {
                                final LatestProductModel product =
                                    products[index];
                                // Wrap _ProductCard with Padding to add space between cards
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      right:
                                          12.0), // Add space to the right of each card
                                  child: _ProductCard(product: product),
                                );
                              },
                            );
                          },
                          loading: () => const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white)),
                          error: (error, stackTrace) => Center(
                            child: Text(
                              'Ürünler yüklenemedi: ${error.toString()}',
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- Special Races Section (Horizontal Scroll) ---
                Padding(
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
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 4, // Placeholder count
                          itemBuilder: (context, index) {
                            // Placeholder Race Card Data
                            final titles = [
                              'Nike Community Run',
                              'Adidas Global Race',
                              'Puma Night Run',
                              'Community Challenge'
                            ];
                            final participants = ['2.5K', '5K', '1.8K', '3.2K'];
                            // Define image paths for the special races
                            final raceImagePaths = [
                              'assets/images/slidebar5.jpeg',
                              'assets/images/slidebar1.jpeg',
                              'assets/images/slidebar3.jpeg',
                              'assets/images/slidebar2.jpeg',
                              // 'assets/images/slidebar5.jpeg', // Add if itemCount increases
                            ];
                            final imagePath = raceImagePaths[index %
                                raceImagePaths.length]; // Use modulo for safety

                            return Container(
                              width: MediaQuery.of(context).size.width *
                                  0.7, // Adjust card width
                              margin: const EdgeInsets.only(
                                  right: 12.0), // Margin between cards
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                // Remove solid color
                                // color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(12.0),
                                // Add background image
                                image: DecorationImage(
                                  image: AssetImage(imagePath),
                                  fit: BoxFit.cover,
                                  // Add a slight darken overlay for text contrast
                                  colorFilter: ColorFilter.mode(
                                    Colors.black.withOpacity(0.5),
                                    BlendMode.darken,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment
                                    .center, // Vertically center items
                                children: [
                                  // Title (takes available space)
                                  Expanded(
                                    child: Text(
                                      titles[
                                          index % titles.length], // Use modulo
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight
                                              .bold, // Keep title bold
                                          fontSize:
                                              16), // Adjust size if needed
                                      maxLines: 2, // Allow wrapping
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(
                                      width:
                                          12), // Space before participant count
                                  // Participants count
                                  Row(
                                    mainAxisSize:
                                        MainAxisSize.min, // Keep row compact
                                    children: [
                                      Icon(Icons.group_outlined,
                                          color: Colors.white70, size: 18),
                                      SizedBox(width: 6),
                                      Text(
                                        participants[index %
                                            participants.length], // Use modulo
                                        style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20), // Add some bottom padding
              ],
            ),
          ),
        ),
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
                      const Icon(Icons.monetization_on,
                          color: Colors.amber, size: 16),
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
