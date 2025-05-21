import 'package:flutter/material.dart';
import '../../../auth/presentation/screens/tabs.dart'; // Ana sayfaya yönlendirme için
import 'guide_page_one.dart'; // Örnek yönlendirme sayfası
import 'guide_page_two.dart'; // Yeni eklenen ikinci sayfa
import 'guide_page_three.dart';
import 'guide_page_four.dart'; // Yeni eklenen dördüncü sayfa
import 'guide_page_five.dart';

// Diğer yönlendirme sayfalarını buraya import edin
// import 'guide_page_three.dart';

class GuidingMainScreen extends StatefulWidget {
  const GuidingMainScreen({super.key});

  @override
  State<GuidingMainScreen> createState() => _GuidingMainScreenState();
}

class _GuidingMainScreenState extends State<GuidingMainScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Yönlendirme sayfalarınızın listesi
  // Şimdilik sadece GuidePageOne'ı ekliyorum, siz daha sonra diğerlerini eklersiniz.
  final List<Widget> _guidePages = [
    const GuidePageOne(),
    const GuidePageTwo(), // İkinci sayfayı ekledik
    const GuidePageThree(),
    const GuidePageFour(), 
    const GuidePageFive()
    // Dördüncü sayfayı ekledik
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const TabsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ekranın üst kısmındaki boşluğu almak için (status bar)
    final double paddingTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: _guidePages,
          ),
          // Sayfa İlerleme Noktaları (Üstte)
          Positioned(
            top: paddingTop + 20, // Status bar + biraz boşluk
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(_guidePages.length, (int index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 10,
                  width: (index == _currentPage) ? 24 : 10, // Aktif nokta biraz daha geniş
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: (index == _currentPage)
                        ? Colors.black // Aktif sayfa rengi
                        : Colors.grey[400], // Pasif sayfa rengi biraz daha açık
                  ),
                );
              }),
            ),
          ),
          // X butonu (isteğe bağlı, yönlendirmeyi atlamak için)
          if (_currentPage != _guidePages.length - 1) // Sadece son sayfada değilse göster
            Positioned(
              top: paddingTop + 10, // Status bar + biraz boşluk (noktaların hemen üstünde olabilir)
              right: 10.0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black, size: 30),
                onPressed: _navigateToHome, // Ana sayfaya atla
              ),
            ),
          // Alt Buton (İleri/Başla)
          Positioned(
            bottom: 30.0, // Butonu biraz yukarı aldım
            left: 24.0,
            right: 24.0,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18), // Buton yüksekliğini biraz artırdım
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // Daha yuvarlak kenarlar
                ),
                elevation: 5,
              ),
              onPressed: () {
                if (_currentPage == _guidePages.length - 1) {
                  _navigateToHome();
                } else {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                }
              },
              child: Text(
                _currentPage == _guidePages.length - 1 ? 'Hadi Başlayalım!' : 'Sonraki', // Buton metni güncellendi
                style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 