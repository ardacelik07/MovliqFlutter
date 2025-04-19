import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/features/auth/presentation/screens/filter_screen.dart';
import '../providers/user_data_provider.dart';
import '../providers/user_ranks_provider.dart'; // For streak
import 'store_screen.dart'; // Import StoreScreen
import 'package:avatar_glow/avatar_glow.dart'; // Import AvatarGlow
import 'tabs.dart'; // Correct import for the provider defined in tabs.dart

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(userDataProvider);
    final userStreakAsync =
        ref.watch(userStreakProvider); // Watch streak provider

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
                      // Profile picture
                      userDataAsync.when(
                        data: (userData) => CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey[800],
                          backgroundImage:
                              userData?.profilePictureUrl != null &&
                                      userData!.profilePictureUrl!.isNotEmpty
                                  ? NetworkImage(userData.profilePictureUrl!)
                                  : null, // Handle null/empty URL
                          child: (userData?.profilePictureUrl == null ||
                                  userData!.profilePictureUrl!.isEmpty)
                              ? const Icon(Icons.person,
                                  size: 24, color: Colors.white70)
                              : null,
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
                        error: (_, __) => const CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey,
                          child: Icon(Icons.error_outline,
                              color: Colors.red, size: 24),
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
                              userData?.name ?? 'Kullanıcı', // Display name
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
                          const Text(
                            '2,450', // Placeholder Coin Count
                            style: TextStyle(
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
                      // Build the card for the current index
                      // You can vary the content based on the index
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical:
                                8.0), // Add horizontal margin between cards
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20.0),
                          gradient: LinearGradient(
                            // Example: Vary gradient based on index
                            colors: index == 0
                                ? [
                                    Colors.pinkAccent.shade100,
                                    Colors.blueAccent.shade100
                                  ]
                                : index == 1
                                    ? [
                                        Colors.orangeAccent.shade100,
                                        Colors.redAccent.shade100
                                      ]
                                    : [
                                        Colors.greenAccent.shade100,
                                        Colors.tealAccent.shade100
                                      ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
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
                            Align(
                              alignment: Alignment.center,
                              child: Text(
                                index == 0
                                    ? '20'
                                    : (index == 1
                                        ? '🔥'
                                        : '🏆'), // Example content variation
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 80,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
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
                              ref.read(selectedTabProvider.notifier).state = 1;
                            },
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Mağaza',
                                    style: TextStyle(color: Color(0xFFC4FF62))),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios,
                                    size: 14, color: Color(0xFFC4FF62)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200, // Adjust height for product cards
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: 4, // Placeholder count
                          itemBuilder: (context, index) {
                            // Placeholder Product Card
                            return Container(
                              width: 150, // Adjust width
                              margin: const EdgeInsets.only(right: 12.0),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(16.0)),
                                      child: Image.asset(
                                        'assets/images/nike.png', // Placeholder image
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          index % 2 == 0
                                              ? 'Premium Nike'
                                              : 'Sports T-shirt', // Placeholder title
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.monetization_on,
                                                color: Colors.amber, size: 16),
                                            SizedBox(width: 4),
                                            Text(
                                              index % 2 == 0
                                                  ? '2500'
                                                  : '1800', // Placeholder price
                                              style: TextStyle(
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
                            );
                          },
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

                            return Container(
                              width: MediaQuery.of(context).size.width *
                                  0.7, // Adjust card width
                              margin: const EdgeInsets.only(
                                  right: 12.0), // Margin between cards
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      titles[index],
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.group_outlined,
                                      color: Colors.grey[400], size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    participants[index],
                                    style: TextStyle(
                                        color: Colors.grey[400], fontSize: 14),
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

// --- Available Products Section ---
