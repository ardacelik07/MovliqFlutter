import 'dart:convert'; // Gerekli import
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider ve Model importları
import 'package:my_flutter_project/features/auth/domain/models/product.dart';
import 'package:my_flutter_project/features/auth/presentation/providers/product_provider.dart';

// StoreScreen'i ConsumerWidget olarak değiştir
class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  // State'i dışarı taşıyalım, çünkü ConsumerWidget stateful değil
  static final StateProvider<String> _selectedCategoryProvider =
      StateProvider((ref) => 'All');

  // Define colors based on the target design
  static const Color limeGreen = Color(0xFFC4FF62);
  static const Color darkBackground = Colors.black;
  static const Color cardBackground = Color(0xFF1C1C1E); // Slightly off-black
  static const Color chipUnselectedBackground = Color(0xFF2C2C2E);
  static const Color lightTextColor = Colors.white;
  static const Color darkTextColor = Colors.black;
  static const Color greyTextColor = Colors.grey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Seçili kategoriyi ve ürün verisini izle
    final String selectedCategory = ref.watch(_selectedCategoryProvider);
    final AsyncValue<List<Product>> productsAsync =
        ref.watch(productNotifierProvider);

    return Scaffold(
      backgroundColor: darkBackground, // Set background to black
      body: Container(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Store',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: lightTextColor, // Changed to white
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: chipUnselectedBackground, // Darker background
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.monetization_on,
                              size: 20, color: Colors.amber), // Gold icon
                          const SizedBox(width: 4),
                          Text(
                            '2,500', // TODO: Replace with actual user coin data
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: lightTextColor, // Changed to white
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Categories
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Kategori chip'lerini ref kullanarak güncelle
                    _buildCategoryChip('All', selectedCategory == 'All', ref),
                    _buildCategoryChip(
                        'Equipment', selectedCategory == 'Equipment', ref),
                    _buildCategoryChip(
                        'Clothes', selectedCategory == 'Clothes', ref),
                    _buildCategoryChip(
                        'Accessories', selectedCategory == 'Accessories', ref),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Products Grid
              Expanded(
                // AsyncValue durumunu ele al
                child: productsAsync.when(
                  data: (products) {
                    // Seçili kategoriye göre ürünleri filtrele
                    final filteredProducts = selectedCategory == 'All'
                        ? products
                        : products
                            .where((p) => p.category == selectedCategory)
                            .toList();

                    // Eğer ürün yoksa veya filtre sonucu boşsa mesaj göster
                    if (filteredProducts.isEmpty) {
                      return const Center(
                        child: Text(
                          'No products found in this category.',
                          style: TextStyle(color: lightTextColor, fontSize: 16),
                        ),
                      );
                    }

                    // GridView'ı filtreli ürünlerle oluştur
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
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
                        return _buildProductCard(
                          // API'den gelen ilk resmi kullan
                          imageUrl: product.firstImageUrl,
                          title: product.name,
                          price: product.price
                              .toStringAsFixed(0), // Fiyatı formatla
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                      child: CircularProgressIndicator(color: limeGreen)),
                  error: (error, stackTrace) => Center(
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ref parametresi eklendi
  Widget _buildCategoryChip(String label, bool isSelected, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          if (selected) {
            // StateProvider'ı güncelle
            ref.read(_selectedCategoryProvider.notifier).state = label;
          }
        },
        backgroundColor: chipUnselectedBackground,
        selectedColor: limeGreen,
        labelStyle: TextStyle(
          color: isSelected ? darkTextColor : lightTextColor,
          fontWeight: FontWeight.bold, // Always bold for better visibility
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // Make it more oval/rounded
          side: BorderSide.none, // Remove default border
        ),
        showCheckmark: false, // Hide default checkmark
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  errorBuilder: (context, error, stackTrace) => const Center(
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
                    fontSize: 14, // Slightly smaller font
                    color: lightTextColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8), // Increased spacing
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.monetization_on,
                          size: 16,
                          color: Colors.amber, // Keep gold color
                        ),
                        const SizedBox(width: 4),
                        Text(
                          price,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: lightTextColor,
                          ),
                        ),
                      ],
                    ),
                    // Updated Buy Button
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implement buy logic
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: limeGreen,
                          foregroundColor: darkTextColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4), // Adjust padding
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8), // Match chip radius
                          ),
                          minimumSize:
                              const Size(0, 30), // Smaller button height
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          )),
                      child: const Text('Buy'),
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
