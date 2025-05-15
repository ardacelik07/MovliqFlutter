import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/features/auth/presentation/screens/tabs.dart'; // TabsScreen ve selectedTabProvider için
import 'package:my_flutter_project/features/auth/presentation/providers/race_provider.dart';

class CheatedRaceScreen extends ConsumerWidget {
  const CheatedRaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF2C2C2E), // Koyu arkaplan rengi
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              // Yasaklama İkonu
              const Icon(
                Icons
                    .do_not_disturb_on_total_silence_rounded, // Alternatif yasak ikonu
                color: Colors.red,
                size: 100,
              ),
              const SizedBox(height: 32),
              const Text(
                'Yarıştan Çıkarıldınız',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sistem, olağan dışı bir hızlanma veya hile olabilecek bir davranış tespit etti. Güvenli bir yarış ortamı sağlamak adına yarıştan çıkarıldınız.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Bu durumun bir hata olduğunu düşünüyorsanız bizimle iletişime geçebilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white60,
                ),
              ),
              const Spacer(flex: 3),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFFC4FF62), // Parlak yeşil buton
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  elevation: 5, // Butona gölge ekle
                ),
                onPressed: () {
                  // Ana sayfaya (HomePage) gitmek için selectedTabProvider'ı güncelle
                  ref.read(selectedTabProvider.notifier).state = 0;
                  // TabsScreen'e git ve önceki tüm sayfaları temizle
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const TabsScreen()),
                    (Route<dynamic> route) => false,
                  );
                },
                child: const Text(
                  'Tamam',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black, // Yeşil buton üzerinde siyah yazı
                  ),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class CheatedRaceDialogContent extends ConsumerWidget {
  const CheatedRaceDialogContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      backgroundColor: const Color(0xFF2C2C2E), // Koyu arkaplan rengi
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
      content: Column(
        mainAxisSize: MainAxisSize.min, // Dialog içeriğinin boyutunu ayarlar
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10), // Üstte biraz boşluk
          const Icon(
            Icons.do_not_disturb_on_total_silence_rounded,
            color: Colors.red,
            size: 90, // İkon boyutu biraz küçültüldü
          ),
          const SizedBox(height: 24),
          const Text(
            'Yarıştan Çıkarıldınız',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26, // Font boyutu ayarlandı
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sistem, olağan dışı bir hızlanma veya hile olabilecek bir davranış tespit etti. Güvenli bir yarış ortamı sağlamak adına yarıştan çıkarıldınız.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Bu durumun bir hata olduğunu düşünüyorsanız bizimle iletişime geçebilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC4FF62), // Parlak yeşil buton
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              elevation: 4,
            ),
            onPressed: () {
              Navigator.of(context).pop(); // Dialogu kapat
              // global provider'ı resetle
              ref.read(cheatKickedStateProvider.notifier).state = false;
            },
            child: const Text(
              'Tamam',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 5), // Altta biraz boşluk
        ],
      ),
    );
  }
}
