import 'dart:convert'; // Gerekli import
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart'; // smooth_page_indicator import edildi
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // FontAwesome import edildi

// Provider ve Model importları
import 'package:my_flutter_project/features/auth/domain/models/product.dart';
import 'package:my_flutter_project/features/auth/domain/models/user_data_model.dart'; // UserDataModel importu eklendi
import 'package:my_flutter_project/features/auth/presentation/providers/product_provider.dart';
import 'package:my_flutter_project/features/auth/presentation/providers/user_data_provider.dart'; // UserDataProvider eklendi
import './product_view_screen.dart'; // ProductViewScreen import edildi
// Add imports for NetworkErrorWidget and specific exceptions
import 'package:google_fonts/google_fonts.dart';
import '../widgets/network_error_widget.dart';
import 'package:http/http.dart' show ClientException; // Specific import
import 'dart:io' show SocketException; // Specific import

// StoreScreen ConsumerStatefulWidget olarak değiştirildi
class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => StoreScreenState();
}

class StoreScreenState extends ConsumerState<StoreScreen> {
  // Define colors based on the target design
  static const Color limeGreen =
      Color(0xFFC4FF62); // Or match the exact green from image if needed
  static const Color darkBackground = Colors.black;
  static const Color cardBackground =
      Color(0xFF1A1A1A); // Darker card background from image
  static const Color chipSelectedBackground =
      limeGreen; // Chip background from image
  static const Color chipUnselectedBackground =
      Color(0xFF2C2C2E); // Unselected chip or other dark elements
  static const Color lightTextColor = Colors.white;
  static const Color darkTextColor = Colors.black;
  static const Color greyTextColor =
      Color(0xFF8A8A8E); // Grey text color from image

  // PageController for the carousel
  final PageController _pageController = PageController(viewportFraction: 0.9);

  // RefreshController eklendi
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    // Sayfa yüklendiğinde verileri otomatik olarak yenile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  // Verileri yenilemek için metot
  Future<void> _refreshData() async {
    // Tüm provider'ları zorla güncelle
    await ref.read(productNotifierProvider.notifier).refreshProducts();
    // MovliqProduct provider'ı otomatik olarak yenilenecektir (autoDispose sayesinde)
    // Coin bilgisini de yenile
    await ref.read(userDataProvider.notifier).fetchCoins();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Product>> productsAsync =
        ref.watch(productNotifierProvider);
    final AsyncValue<Product> movliqProductAsync =
        ref.watch(movliqProductProvider);
    final AsyncValue<UserDataModel?> userDataAsync =
        ref.watch(userDataProvider);

    return Scaffold(
      backgroundColor: darkBackground,
      // Wrap the main content area with productsAsync.when
      body: productsAsync.when(
        data: (products) {
          // Data loaded successfully, build the normal UI
          return SafeArea(
            child: RefreshIndicator(
              key: _refreshIndicatorKey,
              color: limeGreen,
              backgroundColor: cardBackground,
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header (remains mostly the same, uses userDataAsync for coins)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Mağaza',
                                style: GoogleFonts.bangers(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: lightTextColor,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: chipUnselectedBackground,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Image.asset(
                                      'assets/images/mCoin.png',
                                      width: 25,
                                      height: 25,
                                    ),
                                    const SizedBox(width: 4),
                                    userDataAsync.when(
                                      data: (userData) => Text(
                                        userData?.coins?.toStringAsFixed(2) ??
                                            '0.00',
                                        style: GoogleFonts.bangers(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: lightTextColor,
                                        ),
                                      ),
                                      loading: () => const SizedBox(
                                        width: 25,
                                        height: 25,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: lightTextColor,
                                        ),
                                      ),
                                      error: (err, stack) {
                                        if (err is SocketException ||
                                            err is ClientException) {
                                          return const Tooltip(
                                            message: 'Bağlantı hatası',
                                            child: Icon(
                                              Icons.signal_wifi_off_rounded,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                          );
                                        } else {
                                          return const Tooltip(
                                            message: 'Coinler yüklenemedi',
                                            child: Icon(
                                              Icons.error_outline,
                                              color: Colors.red,
                                              size: 20,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),

                    // Carousel (remains the same)
                    SizedBox(
                      height: 170, // Adjust height for the slider area
                      child: PageView.builder(
                        controller:
                            _pageController, // Use the defined controller
                        padEnds: false, // Don't add padding at the ends
                        itemCount: 3, // Placeholder count for demonstration
                        itemBuilder: (context, index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                                vertical:
                                    8.0), // Add horizontal margin between cards
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20.0),
                              // Apply gradient background from image
                              gradient: LinearGradient(
                                colors: [
                                  limeGreen.withOpacity(
                                      0.8), // Adjust opacity as needed
                                  limeGreen.withOpacity(0.5),
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
                          );
                        },
                      ),
                    ),

                    // Carousel Indicator Dots (remains the same)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                        child: SmoothPageIndicator(
                          controller: _pageController,
                          count: 3, // Must match itemCount in PageView
                          effect: ExpandingDotsEffect(
                            // Style from image
                            activeDotColor: limeGreen,
                            dotColor: greyTextColor.withOpacity(0.5),
                            dotHeight: 8,
                            dotWidth: 8,
                            spacing: 6,
                          ),
                        ),
                      ),
                    ),

                    // Special Offer Card (uses movliqProductAsync, NO specific error handling here)
                    movliqProductAsync.when(
                      data: (product) {
                        // Build the card using product data
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ProductViewScreen(productId: product.id!),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            padding:
                                const EdgeInsets.all(20), // Increased padding
                            decoration: BoxDecoration(
                              color: cardBackground, // Use dark card background
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start, // Align items top
                              children: [
                                // Left Column: Chip and Image
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // "Bu Aya Özel" Chip
                                    Container(
                                      margin: const EdgeInsets.only(
                                          bottom: 8.0), // Add space below chip
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            chipSelectedBackground, // Lime green background
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Bu Aya Özel',
                                        style: GoogleFonts.bangers(
                                          color: darkTextColor, // Black text
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    // Image
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12.0),
                                      child: product.firstImageUrl.isNotEmpty
                                          ? Image.network(
                                              product.firstImageUrl,
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error,
                                                      stackTrace) =>
                                                  Icon(Icons.error_outline,
                                                      color: greyTextColor,
                                                      size: 80),
                                            )
                                          : Image.asset(
                                              'assets/images/nike.png', // Fallback
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                    width:
                                        12), // Reduced space between left and right columns

                                // Right Column: Text and Price
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Product Title
                                      Text(
                                        product.name,
                                        style: GoogleFonts.bangers(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: lightTextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Product Description
                                      Text(
                                        product.description,
                                        style: GoogleFonts.bangers(
                                          fontSize: 14,
                                          color: greyTextColor,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(
                                          height:
                                              16), // Pushes price to the bottom
                                      // Price Row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment
                                            .end, // Align price to the right
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                product.price
                                                    .toStringAsFixed(0),
                                                style: GoogleFonts.bangers(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: limeGreen,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Image.asset(
                                                'assets/images/mCoin.png',
                                                width: 25,
                                                height: 25,
                                              ),
                                            ],
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
                      },
                      loading: () => Container(
                        // Simplified loading state for special product
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        height: 150, // Approx height of the card
                        decoration: BoxDecoration(
                          color: cardBackground,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: chipSelectedBackground)),
                      ),
                      // Show minimal error here, main screen handles major errors
                      error: (error, stackTrace) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        height: 150,
                        decoration: BoxDecoration(
                          color: cardBackground,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                            child: Text('Özel ürün yüklenemedi.',
                                style: GoogleFonts.bangers(
                                    color: Colors.redAccent))),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Alışveriş',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.bangers(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: lightTextColor,
                        ),
                      ),
                    ),

                    // Products Grid (uses products from the main data block)
                    _buildProductGrid(products),

                    // Bottom padding
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: limeGreen),
        ),
        error: (error, stackTrace) {
          // ALWAYS show NetworkErrorWidget for any full-screen error
          return Center(
            child: NetworkErrorWidget(
              // Provide generic title/message for all errors
              title: 'Mağaza Yüklenemedi',
              message: 'Bir sorun oluştu, lütfen tekrar deneyin.',
              onRetry: () {
                // Invalidate all relevant providers on retry
                ref.invalidate(productNotifierProvider);
                ref.invalidate(movliqProductProvider);
                ref.invalidate(userDataProvider);
                // Trigger manual refresh if needed
                _refreshData();
              },
            ),
          );
        },
      ),
    );
  }

  // Extracted Product Grid builder
  Widget _buildProductGrid(List<Product> products) {
    final filteredProducts =
        'All' == 'All' // Replace 'All' with actual filter logic if needed
            ? products
            : products.where((p) => p.category == 'All').toList();

    if (filteredProducts.isEmpty) {
      return Center(
        heightFactor: 3.0,
        child: Text(
          'No products found in this category.',
          style: GoogleFonts.bangers(
            color: lightTextColor,
            fontSize: 16,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.70,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: filteredProducts.length,
      itemBuilder: (context, index) {
        final Product product = filteredProducts[index];
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductViewScreen(productId: product.id!),
              ),
            );
          },
          child: _buildProductCard(
            imageUrl: product.firstImageUrl,
            title: product.name,
            price: product.price.toStringAsFixed(0),
          ),
        );
      },
    );
  }

  // Consolidated product card widget
  Widget _buildProductCard({
    required String imageUrl,
    required String title,
    required String price,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBackground, // Use dark card background
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          // Keep shadow or adjust/remove as needed
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Expanded(
            child: ClipRRect(
              // Use ClipRRect for rounded corners on the image
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                color:
                    chipUnselectedBackground, // Dark background for image container
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  // Yükleme ve hata durumları için builder'lar
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                        child: CircularProgressIndicator(
                      color: limeGreen,
                      strokeWidth: 2.0,
                    ));
                  },
                  errorBuilder: (context, error, stackTrace) => Center(
                      // Use updated grey color
                      child: Icon(Icons.error_outline, color: greyTextColor)),
                ),
              ),
            ),
          ),
          // Product Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.bangers(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: lightTextColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          price,
                          style: GoogleFonts.bangers(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: limeGreen,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Image.asset(
                          'assets/images/mCoin.png',
                          width: 25,
                          height: 25,
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: greyTextColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
