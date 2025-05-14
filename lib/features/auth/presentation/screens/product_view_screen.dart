import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:my_flutter_project/features/auth/domain/models/product.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart'; // Resimler için
import 'package:flutter/services.dart'; // Clipboard için
import 'package:url_launcher/url_launcher.dart'; // URL açmak için
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Riverpod importu
import 'package:my_flutter_project/features/auth/presentation/providers/product_provider.dart'; // Provider importu
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart'; // DateFormat için eklendi

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
              const Row(
                // Başarı mesajı
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('Promosyon kodu alındı.',
                      style: TextStyle(
                          color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Text(response.productName ?? 'Ürün Adı Yok', // Null check
                  style: const TextStyle(
                      color: lightTextColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
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
                    Text(
                        response.acquiredCoupon?.code ??
                            'KOD YOK', // Null check
                        style: const TextStyle(
                            color: limeGreen,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.copy, color: limeGreen, size: 20),
                      onPressed: () async {
                        if (response.acquiredCoupon?.code != null) {
                          await Clipboard.setData(ClipboardData(
                              text: response.acquiredCoupon!.code!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Kod kopyalandı!',
                                    style: TextStyle(color: lightTextColor)),
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
              const Text("Nasıl kullanılır?",
                  style: TextStyle(
                      color: greyTextColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("• Promosyon kodunu kopyalayın",
                  style: TextStyle(color: lightTextColor)),
              const SizedBox(height: 4),
              const Text("• Web sitesinde ilgili alana ekleyin",
                  style: TextStyle(color: lightTextColor)),
              const SizedBox(height: 24),
              // Kodu Kopyala ve Siteye Git Butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final String? code = response.acquiredCoupon?.code;
                    final String? urlString = response.productUrl;

                    if (code != null) {
                      await Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Kod kopyalandı!',
                                style: TextStyle(color: lightTextColor)),
                            backgroundColor: cardBackground),
                      );
                    }

                    // --- URL Açma Mantığı ---
                    if (urlString == null || urlString.isEmpty) {
                      print('Error: Product URL is null or empty.');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Geçerli bir ürün URL\'si bulunamadı.',
                                style: TextStyle(color: Colors.red)),
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
                            content: Text('URL formatı geçersiz: $e',
                                style: TextStyle(color: Colors.red)),
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
                              content: Text(
                                  'URL açılamadı: ${uri.toString()}', // Kullanılan URL'yi gösteriyor
                                  style: TextStyle(color: Colors.red)),
                              backgroundColor: cardBackground),
                        );
                      }
                    } catch (e) {
                      print(
                          'Error during launchUrl: $e'); // launchUrl hatasını yazdır
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('URL açılırken hata: $e',
                                style: TextStyle(color: Colors.red)),
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
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Kodu kopyala ve Siteye Git'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Geçerlilik süresi (Formatlama gerekebilir)
              Center(
                  child: Text(
                      response.acquiredCoupon?.expirationDate != null
                          ? "Promosyon kodu ${_formatRemainingTime(DateTime.tryParse(response.acquiredCoupon!.expirationDate!))} geçerli olacak"
                          : "Promosyon kodu süresi belirtilmemiş.",
                      style: TextStyle(color: greyTextColor, fontSize: 12))),
              const SizedBox(height: 10),
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
                    child:
                        const Text('İptal et', style: TextStyle(fontSize: 14)),
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
                      child: Text(
                        product.name, // Gelen product'ı kullan
                        style: TextStyle(
                          color: limeGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const Text(
                  'TANIM',
                  style: TextStyle(
                    color: greyTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Text(
                      product.aboutProduct ?? '', // Gelen product'ı kullan
                      style: TextStyle(
                        color: lightTextColor,
                        fontSize: 15,
                        height: 1.6,
                      ),
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
                                    content: Text(
                                        'Promosyon kodu alınamadı: ${e.toString()}',
                                        style: TextStyle(color: Colors.red)),
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
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    child: _isPurchasing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: darkTextColor, strokeWidth: 3))
                        : const Text('Promosyon Kodu Al'),
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
        title: const Text(
          'Ürün Detayı',
          style: TextStyle(color: lightTextColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
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
            loading: () => const SizedBox.shrink(), // Yüklenirken gösterme
            error: (_, __) =>
                const SizedBox.shrink(), // Hata durumunda gösterme
          ),
        ],
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
                      Text(product.name,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: lightTextColor)),
                      const SizedBox(height: 8),
                      Text(
                          'Kalan kupon adeti: ${product.stock?.toString() ?? 'Bilgi Yok'}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: limeGreen)),
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
                            Text('KULLANMA SÜRESİ',
                                style: TextStyle(
                                    color: darkTextColor.withOpacity(0.7),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.access_time_filled,
                                    color: darkTextColor, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        _formatRemainingTime(
                                            product.expirationDate),
                                        style: const TextStyle(
                                            color: darkTextColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold))),
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
                            Text('Özellikler',
                                style: TextStyle(
                                    color: darkTextColor.withOpacity(0.7),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    letterSpacing: 0.5)),
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
                                              child: Text(feature,
                                                  style: const TextStyle(
                                                      color: darkTextColor,
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w500)))
                                        ])))
                                    .toList(),
                              )
                            else
                              Text('Öne çıkan özellik bulunamadı.',
                                  style: TextStyle(
                                      color: darkTextColor.withOpacity(0.8))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Hakkında Bölümü
                      const Text('Hakkında',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: lightTextColor)),
                      const SizedBox(height: 12),
                      Text(
                          product.aboutProduct ??
                              'Ürün hakkında bilgi bulunamadı.',
                          style: const TextStyle(
                              fontSize: 15, color: greyTextColor, height: 1.5)),
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
            child: Text(
              'Ürün detayları yüklenemedi.\nHata: ${error.toString()}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 16),
              textAlign: TextAlign.center,
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
            children: [
              Expanded(
                // ⬅️ Makes the button take all available width
                child: ElevatedButton(
                  onPressed: () {
                    _showPremiumBottomSheet(context, product);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: limeGreen,
                    foregroundColor: darkTextColor,
                    padding: const EdgeInsets.symmetric(
                        vertical: 16), // no horizontal needed
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment
                        .center, // ⬅️ Center contents inside full-width button
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Image.asset(
                        'assets/images/mCoin.png',
                        width: 28,
                        height: 28,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${NumberFormat("#,##0", "tr_TR").format(product.price)} mCoin - Hemen Al',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: darkTextColor,
                        ),
                      ),
                    ],
                  ),
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

// --- API Yanıt Modelleri (product_provider.dart içine taşındı, buradan silinebilir) ---
/*
class AcquiredCouponResponse {
    final AcquiredCoupon acquiredCoupon;
    final String productName;
    final String productUrl1;
    final int productId;

    AcquiredCouponResponse({
      required this.acquiredCoupon,
      required this.productName,
      required this.productUrl1,
      required this.productId,
    });
}

class AcquiredCoupon {
    final int id;
    final String code;
    final bool isactive;
    final String expirationDate;
    final int maxUses;
    final int usesCount;
    final String createdAt;

    AcquiredCoupon({
      required this.id,
      required this.code,
      required this.isactive,
      required this.expirationDate,
      required this.maxUses,
      required this.usesCount,
      required this.createdAt,
    });
}
*/
// --- Model Sonu ---
