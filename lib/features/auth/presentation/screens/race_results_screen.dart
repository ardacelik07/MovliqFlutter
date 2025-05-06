import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/api_config.dart';
import '../../../../core/services/storage_service.dart';
import '../providers/activity_provider.dart';
import '../providers/activity_stats_provider.dart';
import '../../domain/models/activity_stats_model.dart';
import '../../domain/models/activity_model.dart' as activity_model;
// import '../widgets/network_error_widget.dart'; // Bu import muhtemelen kullanılmıyor, kontrol edilebilir.

// Aktivite tipine göre yarış sonuçlarını çekmek için provider
final raceResultsProvider =
    FutureProvider.family<List<dynamic>, String>((ref, type) async {
  try {
    final token = await StorageService.getToken();
    if (token == null) {
      throw Exception('Token bulunamadı');
    }

    final String accessToken = token;

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

// Renk Sabitleri
const Color _darkBackgroundColor = Color(0xFF1C1C1E); // Koyu Arkaplan
const Color _cardBackgroundColor = Color(0xFF2C2C2E); // Kart Arkaplanı
const Color _primaryAccentColor =
    Color(0xFFD0FD3E); // Yeşil Vurgu Rengi (Görseldekine yakın)
const Color _secondaryTextColor = Color(0xFF8E8E93); // İkincil Metin Rengi
const Color _lightGrayColor = Color(0xFF3A3A3C); // Aktif olmayan buton rengi

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
    final activitiesAsync = ref.watch(activityProfileProvider);
    final textTheme = Theme.of(context).textTheme; // Daha kolay erişim için

    return WillPopScope(
      onWillPop: () async {
        // Ekrandan çıkılırken filtreleri sıfırlama mantığı aynı kalabilir
        // Ancak provider'ı yeniden yükleme şekli değişebilir (invalidate vs)
        // Şimdilik mevcut haliyle bırakıyorum.
        setState(() {
          _selectedType = 'indoor';
          _selectedPeriod = 'weekly';
        });
        // Provider'ı varsayılan değerlerle yeniden yükle
        ref.invalidate(activityProfileProvider);
        ref.invalidate(activityStatsProvider);
        // Geri dönmeden önce state'in güncellenmesi için kısa bir bekleme eklenebilir
        await Future.delayed(const Duration(milliseconds: 50));
        _fetchActivities(); // Yeniden fetch tetikle

        return true; // Geri gitmeye izin ver
      },
      child: Scaffold(
        backgroundColor: _darkBackgroundColor, // Koyu arkaplan rengi
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors
              .transparent, // Arkaplanı transparan yap veya _darkBackgroundColor
          foregroundColor: Colors.white, // İkon ve başlık rengi
          title: const Text(
            'Koşu Geçmişim', // Başlığı güncelle
            style: TextStyle(
              fontSize: 20, // Biraz küçültülebilir
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          centerTitle: false, // Başlığı sola al
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () async {
              // Geri butonuna basıldığında filtreleri sıfırla ve çık
              setState(() {
                _selectedType = 'indoor';
                _selectedPeriod = 'weekly';
              });
              ref.invalidate(activityProfileProvider);
              ref.invalidate(activityStatsProvider);
              await Future.delayed(const Duration(milliseconds: 50));
              _fetchActivities(); // Yeniden fetch tetikle

              Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list,
                  color: Colors.white), // Filtre ikonu
              onPressed: () {
                // TODO: Filtreleme menüsü veya dialog gösterilebilir
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Filtre özelliği eklenecek.')),
                );
              },
            ),
          ],
        ),
        body: Padding(
          // Tüm body için yatay padding
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Öğeleri genişlet
            children: [
              const SizedBox(height: 10), // AppBar altına boşluk

              // Aktivite tipi seçimi (Yeni Tasarım)
              _buildTypeSelectionRow(),

              const SizedBox(height: 20),

              // ------------ Activity Stats Section (Yeni Tasarım) ------------
              _buildStatsSection(),

              const SizedBox(height: 20),

              // Zaman periyodu seçimi (Yeni Tasarım)
              _buildPeriodSelectionRow(),

              const SizedBox(
                  height: 20), // Periyot filtreleri ile liste arasına boşluk

              // Sonuçlar başlığı (Opsiyonel)
              // const Text(
              //   'Aktiviteler',
              //   style: TextStyle(
              //     color: Colors.white,
              //     fontSize: 18,
              //     fontWeight: FontWeight.w600,
              //   ),
              // ),
              // const SizedBox(height: 10),

              // Sonuçlar listesi
              Expanded(
                child: activitiesAsync.when(
                  data: (activities) {
                    if (activities.isEmpty) {
                      return _buildEmptyState(); // Boş durum widget'ı
                    }

                    // ListView.separated ile ayraç ekle
                    return ListView.separated(
                      itemCount: activities.length,
                      padding: const EdgeInsets.only(
                          bottom: 16), // Listenin altına boşluk
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12), // Kartlar arasına boşluk
                      itemBuilder: (context, index) {
                        final activity = activities[index];
                        return _buildActivityCard(
                            activity); // Aktivite kartı widget'ı
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: _primaryAccentColor, // Yeşil renk
                    ),
                  ),
                  error: (error, stack) =>
                      _buildErrorState(error, stack), // Hata durum widget'ı
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Helper Widgets ----------

  // Aktivite Tipi Seçim Butonları (Yeni Tasarım)
  Widget _buildTypeSelectionRow() {
    return Row(
      children: [
        Expanded(
          child: _buildTypeButton(
            title: 'İç Mekan',
            icon: Icons.fitness_center, // İkon örneği
            value: 'indoor',
            isSelected: _selectedType == 'indoor',
          ),
        ),
        const SizedBox(width: 10), // Butonlar arası boşluk
        Expanded(
          child: _buildTypeButton(
            title: 'Dış Mekan',
            icon: Icons.directions_run, // İkon örneği
            value: 'outdoor',
            isSelected: _selectedType == 'outdoor',
          ),
        ),
      ],
    );
  }

  Widget _buildTypeButton({
    required String title,
    required IconData icon,
    required String value,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        if (_selectedType != value) {
          setState(() => _selectedType = value);
          _fetchActivities(); // Veriyi yeniden çek
        }
      },
      child: Container(
        height: 50, // Yükseklik
        decoration: BoxDecoration(
          color: isSelected ? _primaryAccentColor : _lightGrayColor,
          borderRadius: BorderRadius.circular(12), // Yuvarlak köşeler
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.white.withOpacity(0.8),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.black : Colors.white,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // İstatistik Bölümü (Yeni Tasarım)
  Widget _buildStatsSection() {
    // ActivityStatsParams modelini kullanarak provider'ı çağır
    final statsParams =
        ActivityStatsParams(type: _selectedType, period: _selectedPeriod);
    final statsAsync = ref.watch(activityStatsProvider(statsParams));

    return statsAsync.when(
      loading: () => const SizedBox(
        // Yüklenirken belirli bir yükseklik ayarla
        height: 90,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_primaryAccentColor),
          ),
        ),
      ),
      error: (error, stackTrace) {
        return Container(
          height: 90,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _cardBackgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'İstatistikler yüklenemedi.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                Text(
                  error.toString().length > 50
                      ? '${error.toString().substring(0, 50)}...'
                      : error.toString(),
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                // Buton çok yer kaplamasın diye kaldırılabilir veya küçültülebilir
                // ElevatedButton(
                //   onPressed: () => ref.invalidate(activityStatsProvider(statsParams)),
                //   child: Text('Tekrar Dene'),
                // )
              ],
            ),
          ),
        );
      },
      data: (stats) {
        // Seçilen tipe göre etiket ve değerleri belirle
        final bool isIndoor = _selectedType == 'indoor';

        final String totalLabel;
        final String totalValue;
        final String avgLabel;
        final String avgValue;

        if (isIndoor) {
          totalLabel = 'Toplam Adım';
          // stats.totalSteps null ise 0 göster
          totalValue = (stats.totalSteps ?? 0).toString();
          avgLabel = 'Ort. Adım/Dakika';
          // stats.avgStepsPerMinute null ise 0 göster
          avgValue = (stats.avgStepsPerMinute ?? 0).toString();
        } else {
          // Outdoor
          totalLabel = 'Toplam Mesafe';
          // stats.totalDistance null ise 0.0 göster, 1 ondalık basamak
          totalValue = '${(stats.totalDistance ?? 0.0).toStringAsFixed(1)} km';
          avgLabel = 'Ort. Mesafe/dk';
          // stats.avgDistancePerMinute null ise 0.00 göster, 2 ondalık basamak
          avgValue =
              '${(stats.avgDistancePerMinute ?? 0.0).toStringAsFixed(2)} km/dk';
        }

        // Eğer adım verileri gelseydi: (Bu yorum bloğu kaldırılabilir)
        // final String totalLabel = 'Toplam Adım';
        // final String totalValue = stats.totalSteps?.toString() ?? '-'; // Model güncellenince
        // final String avgLabel = 'Ortalama Adım/Dakika';
        // final String avgValue = stats.averageStepsPerMinute?.toStringAsFixed(0) ?? '-'; // Model güncellenince

        return Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    period: _getPeriodDisplayName(
                        _selectedPeriod), // "Bu Hafta" vb.
                    value: totalValue,
                    label: totalLabel)),
            const SizedBox(width: 10),
            Expanded(
                child: _buildStatCard(
                    period: _getPeriodDisplayName(_selectedPeriod),
                    value: avgValue,
                    label: avgLabel)),
          ],
        );
      },
    );
  }

  // Tek bir istatistik kartı
  Widget _buildStatCard(
      {required String period, required String value, required String label}) {
    return Container(
      height: 100, // Sabit yükseklik
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBackgroundColor, // Kart rengi
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Sola yasla
        mainAxisAlignment: MainAxisAlignment.center, // Ortala
        children: [
          Text(
            period, // "Bu Hafta", "Bu Ay", "Bu Yıl"
            style: const TextStyle(
              color: _secondaryTextColor, // Gri renk
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white, // Beyaz renk
              fontSize: 22, // Daha büyük font
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1), // Yüksekliği 2'den 1'e düşür
          // Etiketi FittedBox ile sar
          FittedBox(
            fit: BoxFit.scaleDown, // Metni yalnızca gerekirse küçültür
            alignment: Alignment.centerLeft, // Metni sola hizala
            child: Text(
              label,
              style: const TextStyle(
                color: _primaryAccentColor, // Yeşil renk
                fontSize: 12, // Orijinal font boyutu (FittedBox küçültebilir)
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1, // Tek satırda kalmasını sağla (opsiyonel)
              overflow:
                  TextOverflow.ellipsis, // Taşma durumunda ... (opsiyonel)
            ),
          ),
        ],
      ),
    );
  }

  // Zaman Periyodu Seçim Butonları (Yeni Tasarım)
  Widget _buildPeriodSelectionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // Ortala
      children: [
        _buildPeriodButton('Haftalık', 'weekly'),
        _buildPeriodButton('Aylık', 'monthly'),
        _buildPeriodButton('Yıllık', 'yearly'),
      ],
    );
  }

  // Tek bir periyot butonu (Güncellenmiş Stil)
  Widget _buildPeriodButton(String title, String value) {
    final isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () {
        if (_selectedPeriod != value) {
          setState(() => _selectedPeriod = value);
          _fetchActivities();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 10), // İç boşluk
        margin: const EdgeInsets.symmetric(horizontal: 5), // Dış boşluk
        decoration: BoxDecoration(
          color: isSelected ? _primaryAccentColor : _lightGrayColor,
          borderRadius: BorderRadius.circular(20), // Daha yuvarlak
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // Aktivite Kartı (Yeni Tasarım)
  Widget _buildActivityCard(ActivityModel activity) {
    // Tarih ve saat formatı
    final startTime = activity.startTime;
    final formattedDateTime =
        '${startTime.day} ${_getMonthName(startTime.month)} ${startTime.year}  ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';

    // Süre formatı
    final duration = activity.duration; // duration'ın int olduğu varsayıldı
    final formattedDuration = '$duration Dakika';

    // Rank
    final rank = activity.rank ?? 0;
    final rankText = rank > 0 ? '$rank. Sıra' : '-';

    // Ana metrik (Adım sayısı veya Mesafe)
    final steps = activity.steps; // Adım sayısını al
    final distance = activity.distancekm; // Mesafeyi al
    final bool isOutdoor = activity.roomType == 'outdoor';

    String primaryMetricText = '-'; // Varsayılan olarak tire göster
    String secondaryMetricText = ''; // İkincil metrik başlangıçta boş

    if (isOutdoor) {
      // Dış Mekan: Ana metrik Mesafe, ikincil metrik Adım
      primaryMetricText = '${(distance ?? 0.0).toStringAsFixed(2)} km';
      if (steps != null && steps > 0) {
        // Adım varsa göster
        secondaryMetricText = '$steps Adım';
      }
    } else {
      // İç Mekan: Ana metrik Adım
      if (steps != null && steps >= 0) {
        // Adım null değilse ve 0 veya daha büyükse göster
        primaryMetricText = '$steps Adım';
      }
      // İç mekan için ikincil metrik yok (veya isterseniz eklenebilir)
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Date/Time, Duration, and Calories
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formattedDateTime,
                style: const TextStyle(
                  fontSize: 12, // Biraz daha küçük
                  color: _secondaryTextColor, // Gri renk
                ),
              ),
              // Duration and Calories together
              Row(
                mainAxisSize: MainAxisSize.min, // Prevent taking full width
                children: [
                  if (activity.calories != null && activity.calories! > 0) ...[
                    Icon(Icons.local_fire_department_outlined,
                        color: Colors.orangeAccent, size: 14),
                    SizedBox(width: 4),
                    Text(
                      '${activity.calories!.toStringAsFixed(0)} kcal', // Show calories
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.orangeAccent, // Orange color for calories
                      ),
                    ),
                    SizedBox(width: 8), // Space between calories and duration
                  ],
                  Text(
                    formattedDuration,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _primaryAccentColor, // Yeşil renk
                    ),
                  ),
                ],
              )
            ],
          ),

          const SizedBox(height: 8),

          // Middle: Main Metric (Steps) and Optional Distance
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                primaryMetricText, // Hesaplanan ana metriği göster
                style: const TextStyle(
                  fontSize: 24, // Daha büyük
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (secondaryMetricText.isNotEmpty) ...[
                // İkincil metrik varsa göster (sadece outdoor için adım)
                const SizedBox(width: 8),
                Text(
                  secondaryMetricText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color:
                        _secondaryTextColor, // Outdoor mesafesi için gri renk
                  ),
                ),
              ]
            ],
          ),

          const SizedBox(height: 4),

          // Bottom: Rank
          Text(
            rankText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600, // Biraz daha kalın
              color: _primaryAccentColor, // Yeşil renk
            ),
          ),
        ],
      ),
    );
  }

  // Hata Durumu Widget'ı
  Widget _buildErrorState(Object error, StackTrace stack) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off, // Daha uygun bir ikon
              size: 60,
              color: _secondaryTextColor, // Gri renk
            ),
            const SizedBox(height: 16),
            const Text(
              'Veriler yüklenirken bir hata oluştu.',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SelectableText(
              error.toString(), // Hata mesajını seçilebilir yap
              style: const TextStyle(
                color: _secondaryTextColor,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchActivities,
              icon: const Icon(Icons.refresh, color: Colors.black),
              label: const Text('Tekrar Dene',
                  style: TextStyle(color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryAccentColor, // Yeşil buton
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
    );
  }

  // Boş Durum Widget'ı
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/movliqonlylogo.png', // Logo yolu doğru mu?
            width: 80,
            height: 80,
            color: _secondaryTextColor.withOpacity(0.5), // Rengi soluklaştır
          ),
          const SizedBox(height: 16),
          Text(
            'Bu filtre için sonuç bulunamadı',
            style: TextStyle(
              color: _secondaryTextColor, // Gri renk
              fontSize: 16,
            ),
          ),
        ],
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

  // Periyot koduna göre gösterilecek adı döndürür
  String _getPeriodDisplayName(String period) {
    switch (period) {
      case 'weekly':
        return 'Bu Hafta';
      case 'monthly':
        return 'Bu Ay';
      case 'yearly':
        return 'Bu Yıl';
      default:
        return ''; // Veya varsayılan bir değer
    }
  }
}
