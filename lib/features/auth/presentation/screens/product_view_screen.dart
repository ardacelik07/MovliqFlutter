import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:my_flutter_project/features/auth/domain/models/product.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart'; // Resimler için
import 'package:flutter/services.dart'; // Clipboard için
import 'package:url_launcher/url_launcher.dart'; // URL açmak için
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Riverpod importu
import 'package:my_flutter_project/features/auth/presentation/providers/product_provider.dart'; // Provider importu
// import 'package:my_flutter_project/features/auth/data/models/product_model.dart'; // Product modeli için eklendi - Removed as it might be unnecessary and path is likely incorrect
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart'; // DateFormat için eklendi
import 'package:my_flutter_project/core/config/api_config.dart'; // Corrected import path
import 'package:my_flutter_project/core/services/http_interceptor.dart'; // Corrected import path
import 'package:http/http.dart'
    as http; // Standard http package for tokenless request
import 'package:google_fonts/google_fonts.dart';
import 'package:my_flutter_project/features/auth/presentation/widgets/font_widget.dart';

// Sabit renkleri ve stilleri tanımlayalım (StoreScreen'den alınabilir veya ortak bir yerden)
const Color limeGreen = Color(0xFFC4FF62);
const Color darkBackground = Colors.black;
const Color cardBackground = Color(0xFF1A1A1A);
const Color lightTextColor = Colors.white;
const Color darkTextColor = Colors.black;
const Color greyTextColor = Color(0xFF8A8A8E);

class ProductViewScreen extends ConsumerStatefulWidget {
  // Product yerine productId al
  final int productId;

  const ProductViewScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductViewScreen> createState() => _ProductViewScreenState();
}

class _ProductViewScreenState extends ConsumerState<ProductViewScreen> {
  final PageController _imagePageController = PageController();
  // int _selectedSizeIndex = 2; // Beden seçimi kaldırıldı
  bool _isFavorited = false; // Başlangıçta favori değil
  bool _isPurchasing = false; // Satın alma işlemi durumu

  // Beden listesi kaldırıldı
  // final List<String> _sizes = ['36', '37', '38', '39', '40', '41', '42'];

  @override
  void initState() {
    super.initState();
    // Widget ilk oluşturulduğunda ürün detaylarını çek
    // Use addPostFrameCallback to ensure ref is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(productDetailProvider.notifier)
          .fetchProductDetails(widget.productId);
    });
  }

  // Kalan süreyi formatlayan yardımcı fonksiyon (product null olabilir)
  String _formatRemainingTime(DateTime? expirationDate) {
    if (expirationDate == null) {
      return 'Süresiz';
    }
    final now = DateTime.now();
    final difference = expirationDate.difference(now);
    if (difference.isNegative) {
      return 'Süre Doldu';
    }
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    final formattedString = StringBuffer();
    if (days > 0) formattedString.write('$days gün ');
    if (hours > 0) formattedString.write('$hours saat ');
    if (minutes > 0 || (days == 0 && hours == 0))
      formattedString.write('$minutes dakika');
    return formattedString.toString().trim().isEmpty
        ? 'Bir dakikadan az'
        : formattedString.toString().trim();
  }

  // Yeni Bottom Sheet (Promosyon Kodu Alındı)
  void _showAcquiredCouponBottomSheet(
      BuildContext context, AcquiredCouponResponse response) {
    // ... (Bu fonksiyon içeriği aynı kalabilir) ...
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Bu kısım detaylı olarak doldurulacak
        return Container(
          padding: const EdgeInsets.all(20), // Örnek padding
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E), // Koyu gri/siyah arka plan
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24.0),
              topRight: Radius.circular(24.0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                // Başarı mesajı
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  FontWidget(
                    text: 'Promosyon kodu alındı.',
                    styleType: TextStyleType.bodyMedium, // Or labelLarge
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    // Original: GoogleFonts.bangers(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FontWidget(
                text: response.productName ?? 'Ürün Adı Yok', // Null check
                styleType: TextStyleType.titleSmall, // Or titleMedium
                color: lightTextColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                // Original: GoogleFonts.bangers(color: lightTextColor, fontSize: 18, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 12),
              // Kod alanı (kopyalama butonu ile)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 196, 255, 98) // Lime green
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: limeGreen)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FontWidget(
                      text: response.acquiredCoupon?.code ??
                          'KOD YOK', // Null check
                      styleType: TextStyleType.titleSmall, // Or titleMedium
                      color: limeGreen,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      // Original: GoogleFonts.bangers(color: limeGreen, fontSize: 18, fontWeight: FontWeight.bold)
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, color: limeGreen, size: 20),
                      onPressed: () async {
                        if (response.acquiredCoupon?.code != null) {
                          await Clipboard.setData(ClipboardData(
                              text: response.acquiredCoupon!.code!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: FontWidget(
                                  text: 'Kod kopyalandı!',
                                  styleType: TextStyleType.bodySmall,
                                  color: lightTextColor,
                                  // Original: GoogleFonts.bangers(color: lightTextColor)
                                ),
                                backgroundColor: cardBackground),
                          );
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FontWidget(
                text: "Nasıl kullanılır?",
                styleType: TextStyleType.bodyMedium, // Or labelLarge
                color: greyTextColor,
                fontWeight: FontWeight.bold,
                // Original: GoogleFonts.bangers(color: greyTextColor, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 8),
              FontWidget(
                text: "• Promosyon kodunu kopyalayın",
                styleType: TextStyleType.bodyMedium, // Or labelLarge
                color: lightTextColor,
                fontWeight: FontWeight.bold,
                // Original: GoogleFonts.bangers(color: lightTextColor, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 4),
              FontWidget(
                text: "• Web sitesinde ilgili alana ekleyin",
                styleType: TextStyleType.bodyMedium, // Or labelLarge
                color: lightTextColor,
                fontWeight: FontWeight.bold,
                // Original: GoogleFonts.bangers(color: lightTextColor, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 24),
              // Kodu Kopyala ve Siteye Git Butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final String? code = response.acquiredCoupon?.code;
                    final String? urlString = response.productUrl;

                    // Increment product traffic (fire and forget)
                    try {
                      // Assuming widget.productId holds the current product's ID
                      final int currentProductId = widget.productId;

                      final String trafficUrl =
                          ApiConfig.incrementProductTrafficEndpoint(
                              currentProductId);
                      // Use standard http.post for tokenless request
                      final trafficIncrementResponse = await http.post(
                        Uri.parse(trafficUrl),
                        // No token, no custom headers, no body for this specific POST request
                      );

                      if (trafficIncrementResponse.statusCode == 200) {
                        print(
                            'Successfully incremented traffic for product $currentProductId');
                      } else {
                        print(
                            'Failed to increment traffic for product $currentProductId: ${trafficIncrementResponse.statusCode} ${trafficIncrementResponse.body}');
                      }
                    } catch (e) {
                      print('Error calling increment traffic API: $e');
                    }

                    if (code != null) {
                      await Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: FontWidget(
                              text: 'Kod kopyalandı!',
                              styleType: TextStyleType.bodySmall,
                              color: lightTextColor,
                              // Original: GoogleFonts.bangers(color: lightTextColor)
                            ),
                            backgroundColor: cardBackground),
                      );
                    }

                    // --- URL Açma Mantığı ---
                    if (urlString == null || urlString.isEmpty) {
                      print('Error: Product URL is null or empty.');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: FontWidget(
                              text: 'Geçerli bir ürün URL\'si bulunamadı.',
                              styleType: TextStyleType.bodySmall,
                              color: Colors.red,
                              // Original: GoogleFonts.bangers(color: Colors.red)
                            ),
                            backgroundColor: cardBackground),
                      );
                      return;
                    }
                    // ... (URL açma kodunun geri kalanı aynı)
                    Uri? uri;
                    try {
                      uri = Uri.parse(urlString);
                      print(
                          'Parsed URI: ${uri.toString()}'); // Parsed URI'yi yazdır
                    } catch (e) {
                      print('Error parsing URI: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: FontWidget(
                              text: 'URL formatı geçersiz: $e',
                              styleType: TextStyleType.bodySmall,
                              color: Colors.red,
                              // Original: GoogleFonts.bangers(color: Colors.red)
                            ),
                            backgroundColor: cardBackground),
                      );
                      return; // Parse edilemiyorsa devam etme
                    }

                    try {
                      print('Checking if URL can be launched...');
                      bool canLaunch = await canLaunchUrl(uri);
                      print(
                          'canLaunchUrl result: $canLaunch'); // canLaunchUrl sonucunu yazdır

                      if (canLaunch) {
                        print('Attempting to launch URL...');
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                        print(
                            'launchUrl call completed.'); // Bu satır yazdırılıyor mu kontrol et
                      } else {
                        print('URL cannot be launched.');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: FontWidget(
                                text:
                                    'URL açılamadı: ${uri.toString()}', // Kullanılan URL'yi gösteriyor
                                styleType: TextStyleType.bodySmall,
                                color: Colors.red,
                                // Original: GoogleFonts.bangers(color: Colors.red)
                              ),
                              backgroundColor: cardBackground),
                        );
                      }
                    } catch (e) {
                      print(
                          'Error during launchUrl: $e'); // launchUrl hatasını yazdır
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: FontWidget(
                              text: 'URL açılırken hata: $e',
                              styleType: TextStyleType.bodySmall,
                              color: Colors.red,
                              // Original: GoogleFonts.bangers(color: Colors.red)
                            ),
                            backgroundColor: cardBackground),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: limeGreen,
                    foregroundColor: darkTextColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: GoogleFonts.bangers(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FontWidget(
                        text: 'Kodu kopyala ve Siteye Git',
                        styleType: TextStyleType.labelLarge,
                        color: darkTextColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        // Original: GoogleFonts.bangers(fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Geçerlilik süresi (Formatlama gerekebilir)
              Center(
                  child: FontWidget(
                text: response.acquiredCoupon?.expirationDate != null
                    ? "Promosyon kodu ${_formatRemainingTime(DateTime.tryParse(response.acquiredCoupon!.expirationDate!))} geçerli olacak"
                    : "Promosyon kodu süresiz geçerli",
                styleType: TextStyleType.bodySmall,
                color: greyTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                // Original: GoogleFonts.bangers(color: greyTextColor, fontSize: 12, fontWeight: FontWeight.w600)
              )),
            ],
          ),
        );
      },
    );
  }

  // Bottom sheet'i gösteren metot (Product alacak şekilde güncellendi)
  void _showPremiumBottomSheet(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.5,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24.0),
                topRight: Radius.circular(24.0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(foregroundColor: greyTextColor),
                    child: FontWidget(
                      text: 'İptal et',
                      styleType: TextStyleType.bodySmall,
                      color: greyTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      // Original: GoogleFonts.bangers(fontSize: 14, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: limeGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.directions_run,
                          color: limeGreen, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FontWidget(
                        text: product.name, // Gelen product'ı kullan
                        styleType: TextStyleType.titleMedium,
                        color: limeGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        // Original: GoogleFonts.bangers(color: limeGreen, fontWeight: FontWeight.bold, fontSize: 20)
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                FontWidget(
                  text: 'TANIM',
                  styleType: TextStyleType.bodySmall,
                  color: greyTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,

                  // Original: GoogleFonts.bangers(color: greyTextColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: FontWidget(
                      text:
                          product.aboutProduct ?? '', // Gelen product'ı kullan
                      styleType: TextStyleType.bodyMedium,
                      color: lightTextColor,
                      fontSize: 15,

                      // Original: GoogleFonts.bangers(color: lightTextColor, fontSize: 15, height: 1.6)
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isPurchasing
                        ? null
                        : () async {
                            setState(() {
                              _isPurchasing = true;
                            });
                            try {
                              final response = await ref
                                  .read(productNotifierProvider.notifier)
                                  .purchaseProduct(product
                                      .id!); // Gelen product ID'sini kullan
                              Navigator.pop(context);
                              _showAcquiredCouponBottomSheet(context, response);
                            } catch (e) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: FontWidget(
                                      text: 'Promosyon kodu alınamadı',
                                      styleType: TextStyleType.bodySmall,
                                      color: Colors.red,
                                      // Original: GoogleFonts.bangers(color: Colors.red)
                                    ),
                                    backgroundColor: cardBackground),
                              );
                            } finally {
                              if (mounted) {
                                setState(() {
                                  _isPurchasing = false;
                                });
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: limeGreen,
                      foregroundColor: darkTextColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: GoogleFonts.bangers(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: _isPurchasing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: darkTextColor, strokeWidth: 3))
                        : const FontWidget(
                            text: 'Promosyon Kodu Al',
                            styleType: TextStyleType.labelLarge,
                            color: darkTextColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            // Original: GoogleFonts.bangers(fontSize: 16, fontWeight: FontWeight.bold)
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // productDetailProvider'ı izle
    final productAsyncValue = ref.watch(productDetailProvider);

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: lightTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: FontWidget(
          text: 'Ürün Detayı',
          styleType: TextStyleType.titleLarge,
          color: lightTextColor,
          fontWeight: FontWeight.bold,
          // Original: Text('Ürün Detayı', style: TextStyle(color: lightTextColor, fontWeight: FontWeight.bold)),
        ),
        centerTitle: true,

        /*
        actions: [
          // Favori butonu (product yüklendiğinde göster)
          productAsyncValue.when(
            data: (product) => IconButton(
              icon: Icon(
                _isFavorited ? Icons.favorite : Icons.favorite_border,
                color: _isFavorited ? Colors.red : lightTextColor,
              ),
              onPressed: () {
                setState(() {
                  _isFavorited = !_isFavorited;
                });
                // TODO: Favori ekleme/çıkarma işlevselliği (product.id ile)
              },
            ),
       ],
       */
      ),
      // Ana içerik AsyncValue.when ile yönetilir
      body: productAsyncValue.when(
        data: (product) {
          // Product verisi geldiğinde UI'ı oluştur
          final List<String> imageUrls =
              product.photos?.map((photo) => photo.url).toList() ?? [];
          final List<String> features = product.description
                  ?.split('\n')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList() ??
              [];
          final formattedPrice =
              NumberFormat("#,##0", "tr_TR").format(product.price);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Resim Alanı ---
                if (imageUrls.isNotEmpty)
                  Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.4,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            PageView.builder(
                              controller: _imagePageController,
                              itemCount: imageUrls.length,
                              itemBuilder: (context, index) {
                                return Image.network(
                                  imageUrls[index],
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                        child: CircularProgressIndicator(
                                            color: limeGreen));
                                  },
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Center(
                                          child: Icon(Icons.error_outline,
                                              color: greyTextColor, size: 50)),
                                );
                              },
                            ),
                            if (imageUrls.length > 1)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: SmoothPageIndicator(
                                  controller: _imagePageController,
                                  count: imageUrls.length,
                                  effect: ExpandingDotsEffect(
                                    activeDotColor: limeGreen,
                                    dotColor: greyTextColor.withOpacity(0.5),
                                    dotHeight: 8,
                                    dotWidth: 8,
                                    spacing: 6,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  )
                else // Resim yoksa placeholder göster
                  Container(
                    height: MediaQuery.of(context).size.height * 0.4,
                    color: cardBackground,
                    child: const Center(
                        child: Icon(Icons.image_not_supported,
                            color: greyTextColor, size: 60)),
                  ),
                const SizedBox(height: 16),

                // --- Ürün Bilgileri ve Diğer Bölümler ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FontWidget(
                        text: product.name,
                        styleType: TextStyleType.titleLarge,
                        color: lightTextColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        // Original: GoogleFonts.bangers(fontSize: 24, color: lightTextColor, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 8),
                      FontWidget(
                        text:
                            'Kalan kupon adeti: ${product.stock?.toString() ?? 'Bilgi Yok'}',
                        styleType: TextStyleType.bodyMedium,
                        color: limeGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        // Original: GoogleFonts.bangers(fontSize: 16, color: limeGreen, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 24),

                      // Kullanma Süresi Kartı
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: limeGreen,
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FontWidget(
                              text: 'KULLANMA SÜRESİ',
                              styleType: TextStyleType.bodySmall,
                              color: darkTextColor.withOpacity(0.7),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,

                              // Original: GoogleFonts.bangers(color: darkTextColor.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.access_time_filled,
                                    color: darkTextColor, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: FontWidget(
                                  text: _formatRemainingTime(
                                      product.expirationDate),
                                  styleType: TextStyleType.bodyMedium,
                                  color: darkTextColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  // Original: GoogleFonts.bangers(color: darkTextColor, fontSize: 16, fontWeight: FontWeight.bold)
                                ))
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Öne Çıkanlar Kartı
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: limeGreen,
                            borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FontWidget(
                              text: 'Özellikler',
                              styleType: TextStyleType.bodySmall,
                              color: darkTextColor.withOpacity(0.7),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,

                              // Original: GoogleFonts.bangers(color: darkTextColor.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)
                            ),
                            const SizedBox(height: 12),
                            if (features.isNotEmpty)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: features
                                    .map((feature) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 8.0),
                                        child: Row(children: [
                                          const Icon(Icons.check_circle,
                                              color: darkTextColor, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: FontWidget(
                                            text: feature,
                                            styleType: TextStyleType.bodyMedium,
                                            color: darkTextColor,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            // Original: GoogleFonts.bangers(color: darkTextColor, fontSize: 15, fontWeight: FontWeight.w500)
                                          ))
                                        ])))
                                    .toList(),
                              )
                            else
                              FontWidget(
                                text: 'Öne çıkan özellik bulunamadı.',
                                styleType: TextStyleType.bodyMedium,
                                color: darkTextColor.withOpacity(0.8),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                // Original: GoogleFonts.bangers(color: darkTextColor.withOpacity(0.8), fontSize: 15, fontWeight: FontWeight.w500)
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Hakkında Bölümü
                      FontWidget(
                        text: 'Hakkında',
                        styleType: TextStyleType.titleMedium,
                        color: lightTextColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        // Original: GoogleFonts.bangers(fontSize: 20, color: lightTextColor, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 12),
                      FontWidget(
                        text: product.aboutProduct ??
                            'Ürün hakkında bilgi bulunamadı.',
                        styleType: TextStyleType.bodyMedium,
                        color: greyTextColor,
                        fontSize: 15,

                        // Original: GoogleFonts.bangers(color: greyTextColor, fontSize: 15, height: 1.5)
                      ),
                      // Beden Seçimi kaldırıldı
                    ],
                  ),
                ),
                const SizedBox(height: 100), // Buton için boşluk
              ],
            ),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: limeGreen)),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
                const SizedBox(height: 16),
                FontWidget(
                  text: 'Ürün detayları yüklenemedi.',
                  styleType: TextStyleType.bodyLarge,
                  color: Colors.redAccent,
                  textAlign: TextAlign.center,
                  // Original: Text('Ürün detayları yüklenemedi.', style: TextStyle(color: Colors.redAccent, fontSize: 16), textAlign: TextAlign.center)
                ),
                const SizedBox(height: 8),
                FontWidget(
                  text: error.toString(),
                  styleType: TextStyleType.bodySmall,
                  color: greyTextColor,
                  textAlign: TextAlign.center,
                  // Original: Text(error.toString(), style: TextStyle(color: greyTextColor, fontSize: 12), textAlign: TextAlign.center)
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: Icon(Icons.refresh, color: darkTextColor),
                  label: FontWidget(
                    text: 'Tekrar Dene',
                    styleType: TextStyleType.labelMedium,
                    color: darkTextColor,
                    // Original: Text('Tekrar Dene', style: TextStyle(color: darkTextColor))
                  ),
                  onPressed: () => ref
                      .read(productDetailProvider.notifier)
                      .fetchProductDetails(widget.productId),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: limeGreen,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12)),
                ),
              ],
            ),
          ),
        ),
      ),

      // Alt Kısım: Fiyat ve Satın Al Butonu (product yüklendiğinde göster)
      bottomSheet: productAsyncValue.maybeWhen(
        data: (product) => Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          decoration: const BoxDecoration(
            color: cardBackground,
            border: Border(top: BorderSide(color: greyTextColor, width: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  _showPremiumBottomSheet(context, product);
                }, // product'ı gönder
                style: ElevatedButton.styleFrom(
                  backgroundColor: limeGreen,
                  foregroundColor: darkTextColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 64, vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: GoogleFonts.bangers(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/mCoin.png',
                      width: 30,
                      height: 30,
                    ),
                    const SizedBox(width: 8),
                    FontWidget(
                      text:
                          '${NumberFormat("#,##0", "tr_TR").format(product.price)} mCoin - Hemen Al',
                      styleType: TextStyleType.bodyMedium,
                      color: darkTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      // Original: GoogleFonts.bangers(fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        orElse: () =>
            const SizedBox.shrink(), // Yüklenirken veya hata durumunda gösterme
      ),
    );
  }
}
