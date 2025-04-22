import 'dart:convert'; // Gerekli import
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart'; // smooth_page_indicator import edildi
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // FontAwesome import edildi

// Provider ve Model importları
import 'package:my_flutter_project/features/auth/domain/models/product.dart';
import 'package:my_flutter_project/features/auth/presentation/providers/product_provider.dart';
import './product_view_screen.dart'; // ProductViewScreen import edildi

// StoreScreen'i ConsumerWidget olarak değiştir
class StoreScreen extends ConsumerWidget {
  StoreScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Product>> productsAsync =
        ref.watch(productNotifierProvider);

    return Scaffold(
      backgroundColor: darkBackground,
      body: Container(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header - Updated Design
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    // Changed to Column for subtitle
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment:
                        CrossAxisAlignment.start, // Align text left
                    children: [
                      Row(
                        // Keep title and coins in a row
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Mağaza', // Updated Text
                            style: TextStyle(
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
                                const Icon(Icons.monetization_on,
                                    size: 20,
                                    color: Colors
                                        .amber), // Keep original coin icon style
                                const SizedBox(width: 4),
                                Text(
                                  '2,450', // Updated coin value from image
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: lightTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                          height: 4), // Space between title and subtitle
                      Text(
                        // Subtitle added
                        'Arda\'nın direttiği yazı burada yer alacak.', // Text from image
                        style: TextStyle(
                          fontSize: 14,
                          color: greyTextColor, // Use grey text color
                        ),
                      ),
                    ],
                  ),
                ),

                // Carousel - Updated Design
                SizedBox(
                  height: 170, // Adjust height for the slider area
                  child: PageView.builder(
                    controller: _pageController, // Use the defined controller
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
                              limeGreen
                                  .withOpacity(0.8), // Adjust opacity as needed
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

                // Carousel Indicator Dots
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

                // Special Offer Card - Updated Design
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.all(20), // Increased padding
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
                    // Use Row for image and text side-by-side
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
                            child: const Text(
                              'Bu Aya Özel',
                              style: TextStyle(
                                color: darkTextColor, // Black text
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          // Image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: Image.asset(
                              'assets/images/nike.png', // Use placeholder or actual image
                              width: 80, // Adjust size as needed
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Title
                            const Text(
                              'Nike Air Zoom Pegasus 38', // Text from image
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: lightTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Product Description
                            Text(
                              'Yeni nesil Zoom Air teknolojisi ile her adımda maksimum enerji dönüşü.', // Text from image
                              style: TextStyle(
                                fontSize: 14,
                                color: greyTextColor,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(
                                height: 16), // Pushes price to the bottom
                            // Price Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment
                                  .end, // Align price to the right
                              children: const [
                                FaIcon(
                                  FontAwesomeIcons.coins,
                                  size: 18,
                                  color: limeGreen,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '8,500', // Price from image
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: limeGreen,
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

                const SizedBox(height: 20),
                const Padding(
                  // Added Padding for alignment
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Alışveriş', // Updated Text
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: lightTextColor,
                    ),
                  ),
                ),

                // Products Grid - Expanded kaldırıldı
                productsAsync.when(
                  data: (products) {
                    // Seçili kategoriye göre ürünleri filtrele
                    final filteredProducts = 'All' == 'All'
                        ? products
                        : products.where((p) => p.category == 'All').toList();

                    // Eğer ürün yoksa veya filtre sonucu boşsa mesaj göster
                    if (filteredProducts.isEmpty) {
                      return const Center(
                        heightFactor: 3.0, // Yükseklik faktörü eklendi
                        child: Text(
                          'No products found in this category.',
                          style: TextStyle(color: lightTextColor, fontSize: 16),
                        ),
                      );
                    }

                    // GridView'ı filtreli ürünlerle oluştur - shrinkWrap eklendi
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      physics:
                          const NeverScrollableScrollPhysics(), // İçerdeki scrolling'i devre dışı bırak
                      shrinkWrap:
                          true, // GridView'ın içeriğine sığacak şekilde küçültür
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.70, // Adjust aspect ratio if needed
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount:
                          filteredProducts.length, // API'den gelen ürün sayısı
                      itemBuilder: (context, index) {
                        final Product product = filteredProducts[index];
                        // API'den gelen veriyi kullanarak product card oluştur
                        return InkWell(
                          // Wrap with InkWell for tap detection
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ProductViewScreen(product: product),
                              ),
                            );
                          },
                          child: _buildProductCard(
                            // API'den gelen ilk resmi kullan
                            imageUrl: product.firstImageUrl,
                            title: product.name,
                            price: product.price
                                .toStringAsFixed(0), // Fiyatı formatla
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                      heightFactor: 3.0, // Yükseklik faktörü eklendi
                      child: CircularProgressIndicator(
                          color: chipSelectedBackground)), // Use updated color
                  error: (error, stackTrace) => Center(
                    heightFactor: 3.0, // Yükseklik faktörü eklendi
                    child: SelectableText.rich(
                      TextSpan(
                        text: 'Error loading products:\n',
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        children: <TextSpan>[
                          TextSpan(
                              text: error.toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.normal))
                        ],
                      ),
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                  ),
                ),

                // Bottom padding for better scrolling
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
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
                  style: const TextStyle(
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: limeGreen,
                          ),
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
