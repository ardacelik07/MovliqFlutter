import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:my_flutter_project/features/auth/domain/models/product.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart'; // Resimler için

// Sabit renkleri ve stilleri tanımlayalım (StoreScreen'den alınabilir veya ortak bir yerden)
const Color limeGreen = Color(0xFFC4FF62);
const Color darkBackground = Colors.black;
const Color cardBackground = Color(0xFF1A1A1A);
const Color lightTextColor = Colors.white;
const Color darkTextColor = Colors.black;
const Color greyTextColor = Color(0xFF8A8A8E);

class ProductViewScreen extends StatefulWidget {
  final Product product;

  const ProductViewScreen({super.key, required this.product});

  @override
  State<ProductViewScreen> createState() => _ProductViewScreenState();
}

class _ProductViewScreenState extends State<ProductViewScreen> {
  final PageController _imagePageController = PageController();
  int _selectedSizeIndex = 2; // Başlangıçta 38 seçili olsun (index 2)
  bool _isFavorited = false; // Başlangıçta favori değil

  // Örnek beden listesi
  final List<String> _sizes = ['36', '37', '38', '39', '40', '41', '42'];

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
                // TODO: Satın alma işlevi eklenecek
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
