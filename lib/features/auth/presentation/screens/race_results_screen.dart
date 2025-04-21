import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../core/services/storage_service.dart';
import '../providers/activity_provider.dart';

// Aktivite tipine göre yarış sonuçlarını çekmek için provider
final raceResultsProvider =
    FutureProvider.family<List<dynamic>, String>((ref, type) async {
  try {
    final token = await StorageService.getToken();
    if (token == null) {
      throw Exception('Token bulunamadı');
    }

    final Map<String, dynamic> tokenData = jsonDecode(token);
    final String accessToken = tokenData['token'];

    // Type parametresi "all" değilse direkt olarak kullan, yoksa boş bırak
    final typeParam = type != 'all' ? '?type=$type' : '';

    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/UserResults/GetUserActivities$typeParam'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<dynamic>.from(data);
    } else {
      throw Exception(
          'Yarış sonuçları getirilirken hata: ${response.statusCode}');
    }
  } catch (e) {
    debugPrint('Yarış sonuçları provider hatası: $e');
    return [];
  }
});

// Zaman periyoduna göre filtreleme yapmak için provider
final filteredResultsProvider =
    Provider.family<List<dynamic>, Map<String, String>>((ref, filters) {
  final String type = filters['type'] ?? 'all';
  final String period = filters['period'] ?? 'weekly';

  // Önce tip bazlı verileri çek
  final allResults = ref.watch(raceResultsProvider(type));

  // Yükleme veya hata durumlarına uygun veri dön
  return allResults.when(
      loading: () => [],
      error: (_, __) => [],
      data: (results) {
        // Eğer period filtresi yoksa, tüm sonuçları döndür
        if (period == 'all') return results;

        // Şu anki tarih
        final now = DateTime.now();

        // Periyoda göre filtreleme
        return results.where((race) {
          final raceDate = DateTime.parse(race['startTime']);

          if (period == 'weekly') {
            // Son bir hafta içindeki sonuçlar
            return now.difference(raceDate).inDays <= 7;
          } else if (period == 'monthly') {
            // Son bir ay içindeki sonuçlar
            return now.difference(raceDate).inDays <= 30;
          } else if (period == 'yearly') {
            // Son bir yıl içindeki sonuçlar
            return now.difference(raceDate).inDays <= 365;
          }

          return true;
        }).toList();
      });
});

class RaceResultsScreen extends ConsumerStatefulWidget {
  const RaceResultsScreen({super.key});

  @override
  ConsumerState<RaceResultsScreen> createState() => _RaceResultsScreenState();
}

class _RaceResultsScreenState extends ConsumerState<RaceResultsScreen> {
  String _selectedType = 'indoor'; // Varsayılan olarak indoor seçili
  String _selectedPeriod = 'weekly'; // Varsayılan olarak haftalık

  @override
  void initState() {
    super.initState();
    // Widget ağacı kurulumunu tamamladıktan sonra fetchActivities çağrılmalı
    Future.microtask(() {
      _fetchActivities();
    });
  }

  void _fetchActivities() {
    ref
        .read(activityProfileProvider.notifier)
        .fetchActivities(_selectedType, _selectedPeriod);
  }

  @override
  Widget build(BuildContext context) {
    // activityProfileProvider'ı dinle
    final activitiesAsync = ref.watch(activityProfileProvider);

    return WillPopScope(
      onWillPop: () async {
        // Ekrandan çıkılırken tüm filtreleri sıfırla:
        // 1. _selectedType'ı 'indoor' yap
        // 2. _selectedPeriod'u 'weekly' yap
        // 3. activityProfileProvider'ı bu değerlerle yeniden yükle

        // Bu sayede profil ekranına dönüldüğünde herhangi bir filtre
        // kalıntısı olmadan temiz bir hal gösterilecek

        setState(() {
          _selectedType = 'indoor'; // Filtre varsayılan değeri
          _selectedPeriod = 'weekly'; // Filtre varsayılan değeri
        });

        // Provider'ı varsayılan değerlerle yeniden yükle
        ref
            .read(activityProfileProvider.notifier)
            .fetchActivities('indoor', 'weekly');

        return true;
      },
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF1F3C18),
          foregroundColor: Colors.black,
          title: const Text(
            'Yarış Sonuçları',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color.fromARGB(255, 255, 255, 255),
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Color.fromARGB(255, 255, 255, 255)),
            onPressed: () {
              // Filtreleri sıfırla
              setState(() {
                _selectedType = 'indoor'; // Filtre varsayılan değeri
                _selectedPeriod = 'weekly'; // Filtre varsayılan değeri
              });

              // Provider'ı varsayılan değerlerle yeniden yükle
              ref
                  .read(activityProfileProvider.notifier)
                  .fetchActivities('indoor', 'weekly');

              // Ekrandan çık
              Navigator.pop(context);
            },
          ),
        ),
        body: Column(
          children: [
            // Filtreleme bölümü - Modern tasarım
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1F3C18),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x29000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 5, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Aktivite tipi seçimi
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12, left: 4),
                    child: Text(
                      'Aktivite Tipi',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Indoor butonu
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedType = 'indoor');
                              _fetchActivities();
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: _selectedType == 'indoor'
                                    ? const Color(0xFFC4FF62)
                                    : const Color.fromARGB(255, 102, 102, 102),
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(24),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_selectedType == 'indoor')
                                    const Padding(
                                      padding: EdgeInsets.only(right: 6),
                                      child: Icon(Icons.check_circle,
                                          color: Color.fromARGB(255, 0, 0, 0),
                                          size: 18),
                                    ),
                                  Text(
                                    'Indoor',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedType == 'indoor'
                                          ? const Color.fromARGB(255, 0, 0, 0)
                                          : const Color.fromARGB(
                                              255, 255, 255, 255),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Outdoor butonu
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedType = 'outdoor');
                              _fetchActivities();
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: _selectedType == 'outdoor'
                                    ? const Color(0xFFC4FF62)
                                    : const Color.fromARGB(255, 87, 87, 87),
                                borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(24),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_selectedType == 'outdoor')
                                    const Padding(
                                      padding: EdgeInsets.only(right: 6),
                                      child: Icon(Icons.check_circle,
                                          color: Color.fromARGB(255, 0, 0, 0),
                                          size: 18),
                                    ),
                                  Text(
                                    'Outdoor',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedType == 'outdoor'
                                          ? const Color.fromARGB(255, 0, 0, 0)
                                          : const Color.fromARGB(
                                              255, 255, 255, 255),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Zaman periyodu seçimi
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12, left: 4),
                    child: Text(
                      'Zaman Periyodu',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _buildPeriodButton('Weekly', 'weekly'),
                      _buildPeriodButton('Monthly', 'monthly'),
                      _buildPeriodButton('Yearly', 'yearly'),
                    ],
                  ),
                ],
              ),
            ),

            // Sonuçlar listesi
            Expanded(
              child: activitiesAsync.when(
                data: (activities) {
                  if (activities.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/movliqonlylogo.png',
                            width: 80,
                            height: 80,
                            color: Colors.grey.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Bu filtre için sonuç bulunamadı',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: activities.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final activity = activities[index];

                      // Tarih ve saat formatı (Sadece Tarih ve Saat, alt alta değil)
                      final startTime = activity.startTime;
                      final formattedDateTime =
                          '${startTime.day} ${_getMonthName(startTime.month)} ${startTime.year}   ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';

                      // Süre formatı (e.g., "10 Dakika")
                      final duration = activity.duration;
                      final formattedDuration =
                          '$duration Dakika'; // Target format

                      // Rank ile ilgili bilgiler
                      final rank = activity.rank ?? 0; // API'den gelen sıralama
                      final rankText =
                          rank > 0 ? '$rank. Sıra' : '-'; // Show '-' if no rank

                      // Ana metrik (Conditional based on roomType)
                      final Widget mainMetricWidget;
                      if (activity.roomType == 'outdoor') {
                        final distanceKm =
                            activity.distancekm.toStringAsFixed(2);
                        final steps = activity.steps;
                        mainMetricWidget = Row(
                          crossAxisAlignment: CrossAxisAlignment
                              .baseline, // Align text baselines
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$distanceKm KM',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$steps Adım',
                              style: TextStyle(
                                fontSize: 14, // Smaller font for steps
                                color: Colors.white
                                    .withOpacity(0.7), // Dimmer color
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Indoor
                        final steps = activity.steps;
                        mainMetricWidget = Text(
                          '$steps Adım',
                          style: const TextStyle(
                            fontSize: 26, // Larger font size
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0, // No elevation
                        color: const Color(
                            0xFF2A2A2A), // Dark background from image
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              12), // Slightly less rounded
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Date/Time and Duration
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    formattedDateTime,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                  Text(
                                    formattedDuration,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(
                                          0xFFC4FF62), // Green color for duration
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              // Middle: Main Metric (Steps or KM + Steps)
                              mainMetricWidget, // Use the conditionally created widget

                              const SizedBox(height: 4),

                              // Bottom: Rank
                              Text(
                                rankText,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      Color(0xFFC4FF62), // Green color for rank
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFC4FF62),
                  ),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 60,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Üzgünüz, bir şeyler yanlış gitti.',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF212121),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _fetchActivities,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Yeniden Dene'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC4FF62),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
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

  Widget _buildPeriodButton(String title, String value) {
    final isSelected = _selectedPeriod == value;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPeriod = value);
          _fetchActivities();
        },
        child: Container(
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFC4FF62)
                : const Color.fromARGB(255, 136, 135, 135),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? const Color.fromARGB(255, 0, 0, 0)
                  : const Color.fromARGB(255, 255, 238, 238),
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  // Ay adını getiren yardımcı fonksiyon
  String _getMonthName(int month) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    return months[month - 1];
  }
}
