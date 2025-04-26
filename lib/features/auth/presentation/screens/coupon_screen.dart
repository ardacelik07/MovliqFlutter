import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/coupon_model.dart';
import '../providers/coupon_provider.dart';

class CouponScreen extends ConsumerWidget {
  const CouponScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CouponModel>> couponsAsyncValue =
        ref.watch(couponProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kuponlarım'),
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
            const Text(
              'Geçmiş Kuponlar',
              style: TextStyle(
                color: Colors.white, // Apply white text color
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: couponsAsyncValue.when(
                data: (coupons) {
                  if (coupons.isEmpty) {
                    return const Center(
                      child: Text(
                        'Henüz kuponunuz bulunmamaktadır.',
                        style: TextStyle(
                            color: Colors.white70), // Apply light grey text
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
                        color: Colors.white)), // White loader
                error: (error, stackTrace) => Center(
                  child: SelectableText.rich(
                    TextSpan(
                      text: 'Bir hata oluştu: \n',
                      style: const TextStyle(color: Colors.white), // White text
                      children: <TextSpan>[
                        TextSpan(
                          text: error.toString(),
                          style: const TextStyle(
                              color: Colors.redAccent), // Brighter red
                        ),
                      ],
                    ),
                    style: const TextStyle(
                        color: Colors.white), // Ensure base error text is white
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
                    style: const TextStyle(
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
                    style: const TextStyle(
                      color: Color(0xFFC4FF62),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kalan Süre: ${coupon.remainingTimeFormatted}',
                    style: const TextStyle(
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
                  const SnackBar(
                    content: Text('Kupon kodu kopyalandı!'),
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
