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

  // Yeni: Kalan süreyi formatlayan yardımcı fonksiyon
  String _formatRemainingTime(DateTime? expirationDate) {
    if (expirationDate == null) {
      return 'Süresiz'; // Return 'Süresiz' if no expiration date
    }

    final now = DateTime.now();
    final difference = expirationDate.difference(now);

    if (difference.isNegative) {
      return 'Süre Doldu'; // Return 'Süre Doldu' if expired
    }

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    final formattedString = StringBuffer();
    if (days > 0) {
      formattedString.write('$days gün ');
    }
    if (hours > 0) {
      formattedString.write('$hours saat ');
    }
    if (minutes > 0 || (days == 0 && hours == 0)) {
      // Show minutes if < 1 hour remaining
      formattedString.write('$minutes dakika');
    }

    return formattedString.toString().trim();
  }

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

                    // --- Detaylı Loglama ile URL Açma ---
                    final String? urlString = response.productUrl;
                    if (urlString == null || urlString.isEmpty) {
                      print('Error: Product URL is null or empty.');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Geçerli bir ürün URL\'si bulunamadı.',
                                style: TextStyle(color: Colors.red)),
                            backgroundColor: cardBackground),
                      );
                      return; // URL yoksa devam etme
                    }

                    print('Raw URL string: $urlString');
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
                    Expanded(
                      child: Text(
                        widget.product.name,
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
                Expanded(
                  // Kalan alanı doldurması için Expanded
                  child: SingleChildScrollView(
                    // Uzun metinler için kaydırma
                    child: Text(
                      widget.product.aboutProduct ?? '',
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

    // Özellikleri ayıklama (description'dan)
    final List<String> features = widget.product.description
            ?.split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];

    // Fiyat formatlama
    final formattedPrice =
        NumberFormat("#,##0", "tr_TR").format(widget.product.price);

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
            // Resim Alanı (PageView) ve Altındaki Metin
            Stack(
              alignment: Alignment.bottomLeft, // Metni sola yaslamak için
              children: [
                SizedBox(
                  height:
                      MediaQuery.of(context).size.height * 0.4, // Ekranın %40'ı
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
                // Yeni: Kaç kişinin aldığı bilgisi
              ],
            ),
            const SizedBox(height: 16), // Resim altı boşluk

            // Ürün Bilgileri ve Yeni Bölümler Alanı
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık (Mevcut)
                  Text(
                    widget.product.name, // Dinamik başlık
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: lightTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kalan kupon adeti: ${widget.product.stock.toString()}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: limeGreen,
                    ),
                  ),
                  // Açıklama (Mevcut - ama yeni tasarımda kullanılmıyor, istersen kaldırabilirsin)
                  /*const SizedBox(height: 8),
                  Text(
                    widget.product.description ??
                        'Ürün açıklaması bulunamadı.', // Dinamik açıklama
                    style: const TextStyle(
                      fontSize: 15,
                      color: greyTextColor,
                      height: 1.4, // Satır yüksekliği
                    ),
                  ),*/
                  const SizedBox(height: 24),

                  // Yeni: Kullanma Süresi Kartı
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: limeGreen, // Açık Yeşil Arka Plan
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KULLANMA SÜRESİ',
                          style: TextStyle(
                            color: darkTextColor.withOpacity(0.7),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.access_time_filled,
                                color: darkTextColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              // Metnin taşmasını engelle
                              child: Text(
                                // TODO: product modelinde expirationDate alanı varsa onu kullan
                                _formatRemainingTime(widget.product
                                    .expirationDate), // widget.product.expirationDate
                                style: const TextStyle(
                                  color: darkTextColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Yeni: Öne Çıkanlar Kartı
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: limeGreen, // Açık Yeşil Arka Plan
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Özellikler',
                          style: TextStyle(
                            color: darkTextColor.withOpacity(0.7),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Özellikleri listeleyen Column
                        if (features.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: features
                                .map((feature) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check_circle,
                                              color: darkTextColor, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              feature,
                                              style: const TextStyle(
                                                color: darkTextColor,
                                                fontSize:
                                                    15, // Biraz daha küçük
                                                fontWeight: FontWeight
                                                    .w500, // Normalden biraz kalın
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          )
                        else
                          Text(
                            // Eğer özellik yoksa
                            'Öne çıkan özellik bulunamadı.',
                            style: TextStyle(
                                color: darkTextColor.withOpacity(0.8)),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Yeni: Hakkında Bölümü
                  const Text(
                    'Hakkında',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: lightTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.product.aboutProduct ??
                        'Ürün hakkında bilgi bulunamadı.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: greyTextColor,
                      height: 1.5, // Satır aralığı biraz artırıldı
                    ),
                    // maxLines: 5, // İstersen başlangıçta sınırlı satır gösterebilirsin
                    // overflow: TextOverflow.ellipsis,
                  ),
                  // TODO: "Daha Fazlasını Gör" butonu eklenebilir
                  // TextButton(onPressed: (){}, child: Text('Daha Fazlasını Gör >', style: TextStyle(color: limeGreen)))

                  // Beden Seçimi (Yorum satırına alındı)
                  /*
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
                  */
                ],
              ),
            ),
            const SizedBox(
                height:
                    100), // Buton için altta daha fazla boşluk (bottomSheet yüksekliği kadar)
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Fiyat

            // Satın Al Butonu (Metin Güncellendi)
            ElevatedButton(
              onPressed: () {
                // Bottom sheet'i göster
                _showPremiumBottomSheet(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: limeGreen,
                foregroundColor: darkTextColor,
                padding: const EdgeInsets.symmetric(
                    horizontal: 64, vertical: 15), // Reduced horizontal padding
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min, // Fit content
                children: [
                  FaIcon(
                    FontAwesomeIcons.coins,
                    color: darkTextColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text('$formattedPrice mCoin - Hemen Al'),
                ],
              ),
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
