import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:my_flutter_project/features/auth/domain/models/product.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart'; // Resimler için
import 'package:flutter/services.dart'; // Clipboard için
import 'package:url_launcher/url_launcher.dart'; // URL açmak için
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Riverpod importu
import 'package:my_flutter_project/features/auth/presentation/providers/product_provider.dart'; // Provider importu

// Sabit renkleri ve stilleri tanımlayalım (StoreScreen'den alınabilir veya ortak bir yerden)
const Color limeGreen = Color(0xFFC4FF62);
const Color darkBackground = Colors.black;
const Color cardBackground = Color(0xFF1A1A1A);
const Color lightTextColor = Colors.white;
const Color darkTextColor = Colors.black;
const Color greyTextColor = Color(0xFF8A8A8E);

class ProductViewScreen extends ConsumerStatefulWidget {
  final Product product;

  const ProductViewScreen({super.key, required this.product});

  @override
  ConsumerState<ProductViewScreen> createState() => _ProductViewScreenState();
}

class _ProductViewScreenState extends ConsumerState<ProductViewScreen> {
  final PageController _imagePageController = PageController();
  int _selectedSizeIndex = 2; // Başlangıçta 38 seçili olsun (index 2)
  bool _isFavorited = false; // Başlangıçta favori değil
  bool _isPurchasing = false; // Satın alma işlemi durumu

  // Örnek beden listesi
  final List<String> _sizes = ['36', '37', '38', '39', '40', '41', '42'];

  // Yeni Bottom Sheet (Promosyon Kodu Alındı)
  void _showAcquiredCouponBottomSheet(
      BuildContext context, AcquiredCouponResponse response) {
    // TODO: İkinci görseldeki UI'ı burada oluştur.
    // - Başarı mesajı
    // - Ürün adı (response.productName)
    // - Promosyon kodu (response.acquiredCoupon.code) ve kopyalama butonu
    // - Nasıl kullanılır bölümü
    // - "Kodu kopyala ve Siteye Git" butonu (Clipboard.setData ve launchUrl(response.productUrl1))
    // - Geçerlilik süresi (response.acquiredCoupon.expirationDate formatlanabilir)
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
              Text(response.productName!,
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
                    color: limeGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: limeGreen)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(response.acquiredCoupon!.code!,
                        style: const TextStyle(
                            color: limeGreen,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.copy, color: limeGreen, size: 20),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(
                            text: response.acquiredCoupon!.code!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Kod kopyalandı!',
                                  style: TextStyle(color: lightTextColor)),
                              backgroundColor: cardBackground),
                        );
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
                    await Clipboard.setData(
                        ClipboardData(text: response.acquiredCoupon!.code!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Kod kopyalandı!',
                              style: TextStyle(color: lightTextColor)),
                          backgroundColor: cardBackground),
                    );
                    // URL'yi açma (güvenlik kontrolü ile)
                    final Uri uri = Uri.parse(response.productUrl!);
                    try {
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'URL açılamadı: ${response.productUrl}',
                                  style: TextStyle(color: Colors.red)),
                              backgroundColor: cardBackground),
                        );
                      }
                    } catch (e) {
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
                  child: Text("Promosyon kodu 48 saat geçerli olacak",
                      style: TextStyle(
                          color: greyTextColor, fontSize: 12))), // Örnek metin
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // Bottom sheet'i gösteren metot
  void _showPremiumBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors
          .transparent, // Arka planı şeffaf yapıp Container ile yöneteceğiz
      builder: (context) {
        // Bottom sheet içeriğinin yüksekliğini ayarlamak için FractionallySizedBox kullanabiliriz
        return FractionallySizedBox(
          heightFactor:
              0.5, // Ekran yüksekliğinin %50'si kadar olsun (ayarlanabilir)
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20.0, vertical: 24.0), // Padding artırıldı
            decoration: const BoxDecoration(
              color: Color(0xFF1C1C1E), // Koyu gri/siyah arka plan
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24.0),
                topRight: Radius.circular(24.0),
              ),
            ),
            child: Column(
              // Wrap yerine Column kullandık daha iyi kontrol için
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // İptal Butonu (Sağ üste alalım)
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          greyTextColor, // Daha az dikkat çekici renk
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                    child:
                        const Text('İptal et', style: TextStyle(fontSize: 14)),
                  ),
                ),
                // const SizedBox(height: 5), // Üstteki boşluk azaltıldı
                // Başlık ve İkon
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center, // Dikeyde ortala
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10), // Biraz büyüttük
                      decoration: BoxDecoration(
                        color: limeGreen.withOpacity(0.2),
                        borderRadius:
                            BorderRadius.circular(10), // Daha yuvarlak
                      ),
                      child: const Icon(Icons.directions_run, // İkonu ayarladık
                          color: limeGreen,
                          size: 28), // İkon büyüdü
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Movliq Premium\'da %10 indirim fırsatı',
                        style: TextStyle(
                          color: limeGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 20, // Başlık büyüdü
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28), // Boşluk artırıldı
                // Tanım Başlığı
                const Text(
                  'TANIM',
                  style: TextStyle(
                    color: greyTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13, // Biraz büyüdü
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12), // Boşluk artırıldı
                // Tanım Metni
                const Expanded(
                  // Kalan alanı doldurması için Expanded
                  child: SingleChildScrollView(
                    // Uzun metinler için kaydırma
                    child: Text(
                      'Lorem Ipsum, dizgi ve baskı endüstrisinde kullanılan mıgır metinlerdir. Lorem Ipsum, adı bilinmeyen bir matbaacının bir hurufat numune kitabı oluşturmak üzere bir yazı ............',
                      style: TextStyle(
                        color: lightTextColor,
                        fontSize: 15, // Biraz büyüdü
                        height: 1.6, // Satır aralığı artırıldı
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24), // Boşluk ayarlandı
                // Promosyon Kodu Al Butonu
                SizedBox(
                  width:
                      double.infinity, // Butonun tam genişlikte olmasını sağlar
                  child: ElevatedButton(
                    onPressed: _isPurchasing
                        ? null
                        : () async {
                            // Yüklenme durumunda butonu devre dışı bırak
                            setState(() {
                              _isPurchasing = true;
                            });
                            try {
                              // API isteği
                              final response = await ref
                                  .read(productNotifierProvider.notifier)
                                  .purchaseProduct(
                                      widget.product.id!); // Gerçek API çağrısı

                              Navigator.pop(
                                  context); // Mevcut bottom sheet'i kapat
                              _showAcquiredCouponBottomSheet(context,
                                  response); // Yeni bottom sheet'i göster
                            } catch (e) {
                              Navigator.pop(context); // Hata durumunda da kapat
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Promosyon kodu alınamadı: ${e.toString()}',
                                        style: TextStyle(color: Colors.red)),
                                    backgroundColor:
                                        cardBackground), // Hata mesajı
                              );
                            } finally {
                              // Widget hala ağaçtaysa setState çağır (butonun tekrar aktifleşmesi için)
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                // const SizedBox(height: 10), // Alttaki boşluk kaldırıldı, padding yeterli
                const SizedBox(
                    height: 16), // Butonun altına biraz boşluk ekleyelim
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Product modelinde image_urls gibi bir liste olduğunu varsayalım
    final List<String> imageUrls =
        widget.product.photos?.map((photo) => photo.url).toList() ??
            []; // Null check ve fallback

    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: cardBackground, // Koyu arka plan
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
          IconButton(
            icon: Icon(
              _isFavorited ? Icons.favorite : Icons.favorite_border,
              color: _isFavorited ? Colors.red : lightTextColor,
            ),
            onPressed: () {
              // Favori durumunu değiştir (şimdilik sadece UI)
              setState(() {
                _isFavorited = !_isFavorited;
              });
              // TODO: Favori ekleme/çıkarma işlevselliği eklenecek
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resim Alanı (PageView)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4, // Ekranın %40'ı
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  PageView.builder(
                    controller: _imagePageController,
                    itemCount: imageUrls.length,
                    itemBuilder: (context, index) {
                      return Image.network(
                        imageUrls[index],
                        fit: BoxFit.cover, // Resmi kapla
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                              child:
                                  CircularProgressIndicator(color: limeGreen));
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                                child: Icon(Icons.error_outline,
                                    color: greyTextColor, size: 50)),
                      );
                    },
                  ),
                  // Resim noktaları (eğer birden fazla resim varsa)
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

            // Ürün Bilgileri ve Beden Seçimi Alanı
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  Text(
                    widget.product.name, // Dinamik başlık
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: lightTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Açıklama
                  Text(
                    widget.product.description ??
                        'Ürün açıklaması bulunamadı.', // Dinamik açıklama
                    style: const TextStyle(
                      fontSize: 15,
                      color: greyTextColor,
                      height: 1.4, // Satır yüksekliği
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Beden Seçimi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Beden',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: lightTextColor,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // TODO: Beden Tablosu gösterme işlevi
                        },
                        child: const Text(
                          'Beden Tablosu',
                          style: TextStyle(color: limeGreen, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Beden Numaraları (Yatay Kaydırılabilir Liste)
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _sizes.length,
                      itemBuilder: (context, index) {
                        final bool isSelected = index == _selectedSizeIndex;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedSizeIndex = index;
                            });
                          },
                          child: Container(
                            width: 50, // Sabit genişlik
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: isSelected ? limeGreen : cardBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? limeGreen
                                    : greyTextColor.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _sizes[index],
                                style: TextStyle(
                                  color: isSelected
                                      ? darkTextColor
                                      : lightTextColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60), // Buton için altta boşluk
          ],
        ),
      ),

      // Alt Kısım: Fiyat ve Satın Al Butonu
      bottomSheet: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: const BoxDecoration(
          color: cardBackground, // Koyu arka plan
          // Üst kenara hafif bir çizgi eklenebilir
          border: Border(top: BorderSide(color: greyTextColor, width: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Fiyat
            Row(
              children: [
                const FaIcon(
                  FontAwesomeIcons.coins,
                  color: limeGreen,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.product.price.toStringAsFixed(0), // Dinamik fiyat
                  style: const TextStyle(
                    color: limeGreen,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            // Satın Al Butonu
            ElevatedButton(
              onPressed: () {
                // Bottom sheet'i göster
                _showPremiumBottomSheet(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: limeGreen,
                foregroundColor: darkTextColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text('Hemen Al'),
            ),
          ],
        ),
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
