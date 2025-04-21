import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  String _selectedCategory = 'All';

  // Define colors based on the target design
  static const Color limeGreen = Color(0xFFC4FF62);
  static const Color darkBackground = Colors.black;
  static const Color cardBackground = Color(0xFF1C1C1E); // Slightly off-black
  static const Color chipUnselectedBackground = Color(0xFF2C2C2E);
  static const Color lightTextColor = Colors.white;
  static const Color darkTextColor = Colors.black;
  static const Color greyTextColor = Colors.grey;

  @override
  Widget build(BuildContext context) {
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
                    _buildCategoryChip('All', _selectedCategory == 'All'),
                    _buildCategoryChip(
                        'Equipment', _selectedCategory == 'Equipment'),
                    _buildCategoryChip(
                        'Clothes', _selectedCategory == 'Clothes'),
                    _buildCategoryChip(
                        'Accessories', _selectedCategory == 'Accessories'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Products Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.70, // Adjust aspect ratio if needed
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: 8, // Placeholder count
                  itemBuilder: (context, index) {
                    // Simplified logic for demonstration, use actual product data
                    if (_selectedCategory == 'All' ||
                        _selectedCategory == 'Equipment') {
                      return _buildProductCard(
                        imageUrl: 'assets/images/nike.png',
                        title: index % 2 == 0
                            ? 'Training Equipment'
                            : 'Premium Running Shoes',
                        price: index % 2 == 0 ? '800' : '1,200',
                      );
                    } else if (_selectedCategory == 'Clothes') {
                      return _buildProductCard(
                        imageUrl:
                            'assets/images/slider.png', // Different image for variety
                        title: 'Sports T-Shirt',
                        price: '950',
                      );
                    } else {
                      // Accessories
                      return _buildProductCard(
                        imageUrl:
                            'assets/images/activity.png', // Different image
                        title: 'Smart Watch Band',
                        price: '600',
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (bool selected) {
          if (selected) {
            setState(() {
              _selectedCategory = label;
            });
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
                child: Image.asset(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
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
