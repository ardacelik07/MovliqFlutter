import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/coupon_model.dart';
import '../providers/coupon_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class CouponScreen extends ConsumerWidget {
  const CouponScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CouponModel>> couponsAsyncValue =
        ref.watch(couponProvider);

    // Hata ayıklama mesajları
    print('🎫 CouponScreen: Provider durumu: ${couponsAsyncValue}');
    if (couponsAsyncValue is AsyncData) {
      print(
          '📋 CouponScreen: Kupon sayısı: ${couponsAsyncValue.value?.length}');
    } else if (couponsAsyncValue is AsyncError) {
      print('❌ CouponScreen: Provider hatası: ${couponsAsyncValue.error}');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Kuponlarım', style: GoogleFonts.bangers()),
        backgroundColor: Colors.grey[900], // Apply dark background
        foregroundColor: Colors.white, // Make title/icon white
        iconTheme: const IconThemeData(
            color: Colors.white), // Ensure back arrow is white
        elevation: 0,
      ),
      backgroundColor: Colors.grey[900], // Apply dark background to Scaffold
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /*const Text(
              'Geçmiş Kuponlar',
              style: TextStyle(
                color: Colors.white, // Apply white text color
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),*/
            Expanded(
              child: couponsAsyncValue.when(
                data: (coupons) {
                  if (coupons.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/couponicon.png',
                            height: 64,
                            width: 64,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Henüz kuponunuz bulunmamaktadır.',
                            style: GoogleFonts.bangers(
                                color: Colors.white70), // Apply light grey text
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC4FF62),
                              foregroundColor: Colors.black,
                            ),
                            onPressed: () {
                              // Provider'ı yenile
                              ref
                                  .read(couponProvider.notifier)
                                  .refreshCoupons();
                            },
                            child: Text('Yenile', style: GoogleFonts.bangers()),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: Colors.white, // Indicator color
                    backgroundColor: Colors.grey[800], // Indicator background
                    onRefresh: () =>
                        ref.read(couponProvider.notifier).refreshCoupons(),
                    child: ListView.builder(
                      itemCount: coupons.length,
                      itemBuilder: (context, index) {
                        final CouponModel coupon = coupons[index];
                        return _CouponCard(coupon: coupon);
                      },
                    ),
                  );
                },
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color:
                            Color(0xFFC4FF62))), // Green loader to match theme
                error: (error, stackTrace) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        SelectableText.rich(
                          TextSpan(
                            text: 'API Hatası: \n',
                            style: GoogleFonts.bangers(
                                color: Colors.white,
                                fontWeight: FontWeight.bold), // White text
                            children: <TextSpan>[
                              TextSpan(
                                text: error.toString(),
                                style: GoogleFonts.bangers(
                                    color: Colors.redAccent,
                                    fontWeight:
                                        FontWeight.normal), // Brighter red
                              ),
                            ],
                          ),
                          style: GoogleFonts.bangers(
                              color: Colors
                                  .white), // Ensure base error text is white
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC4FF62),
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            // Provider'ı yenile
                            ref.read(couponProvider.notifier).refreshCoupons();
                          },
                          child:
                              Text('Tekrar Dene', style: GoogleFonts.bangers()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final CouponModel coupon;

  const _CouponCard({required this.coupon});

  @override
  Widget build(BuildContext context) {
    return Card(
      color:
          Colors.grey[850], // Apply dark card color (slightly lighter than bg)
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coupon.productName, // Using productName as per API
                    style: GoogleFonts.bangers(
                      color: Colors.white, // White text
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    coupon.acquiredCouponCode,
                    style: GoogleFonts.bangers(
                      color: Color(0xFFC4FF62),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kalan Süre: ${coupon.remainingTimeFormatted}',
                    style: GoogleFonts.bangers(
                      color: Colors.white70, // Light grey text
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.copy_outlined,
                color: Color(0xFFC4FF62), // Lime green icon
              ),
              onPressed: () {
                Clipboard.setData(
                    ClipboardData(text: coupon.acquiredCouponCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Kupon kodu kopyalandı!',
                        style: GoogleFonts.bangers()),
                    duration: Duration(seconds: 1),
                    // Optional: Dark SnackBar style
                    // backgroundColor: Colors.grey[700],
                    // behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              tooltip: 'Kodu Kopyala',
            ),
          ],
        ),
      ),
    );
  }
}
