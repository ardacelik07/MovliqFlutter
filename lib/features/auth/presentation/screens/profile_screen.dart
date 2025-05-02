import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'settings_screen.dart';
import '../../../../core/services/storage_service.dart';
import 'dart:convert';
import '../../../../features/auth/domain/models/user_data_model.dart';
import '../../../../features/auth/presentation/providers/user_data_provider.dart';
import '../providers/activity_provider.dart';
import 'package:flutter/painting.dart';
import '../../../../core/config/api_config.dart';
import 'race_results_screen.dart';
import 'package:lottie/lottie.dart';
import '../providers/user_ranks_provider.dart';
import '../../domain/models/user_ranks_model.dart';
import 'coupon_screen.dart';
import '../widgets/network_error_widget.dart';
import 'package:http/http.dart' show ClientException;
import 'dart:io' show SocketException;
import 'update_user_info_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _activeType = 'indoor'; // Varsayılan olarak indoor seçili

  @override
  void initState() {
    super.initState();
    // Profil verisini yükleme işlemi başlatılıyor
    // TabsScreen now handles the initial fetchUserData call.
    Future.microtask(() {
      // ref.read(userDataProvider.notifier).fetchUserData(); // Removed redundant call
      _fetchActivityData(); // Aktivite verilerini yükle
      ref.refresh(userRanksProvider); // Kullanıcı sıralamasını yükle
      ref.refresh(userStreakProvider); // Kullanıcı streak bilgisini yükle
    });
  }

  void _fetchActivityData() {
    // Aktivite verilerini yükleyen provider'ı çağır
    ref
        .read(activityProfileProvider.notifier)
        .fetchActivities(_activeType, 'weekly');
  }

  void _updateActiveType(String type) {
    setState(() {
      _activeType = type;
    });
    _fetchActivityData();
  }

  // Aktivite tipine göre grafik verilerini oluşturacak fonksiyon
  List<FlSpot> _getSpots(List<ActivityModel>? activities) {
    // Veri yoksa boş liste döndür
    if (activities == null || activities.isEmpty) {
      return [
        const FlSpot(0, 0),
        const FlSpot(1, 0),
        const FlSpot(2, 0),
        const FlSpot(3, 0),
        const FlSpot(4, 0),
        const FlSpot(5, 0),
        const FlSpot(6, 0),
      ];
    }

    try {
      // Haftanın günlerine göre verileri gruplandır
      Map<int, double> dailyData = {};

      // Önce tüm günleri 0 değeriyle doldur
      for (int i = 0; i < 7; i++) {
        dailyData[i] = 0.0;
      }

      // Aktiviteleri günlere göre topla
      for (var activity in activities) {
        // Aktivitenin başlangıç zamanından haftanın gününü hesapla (0=Pazartesi, 6=Pazar)
        final DateTime activityDate = activity.startTime;
        final int weekday = activityDate.weekday - 1; // 0-6 aralığına dönüştür

        // Y değeri: Indoor için steps, diğerleri için distancekm
        double value = _activeType == 'indoor'
            ? activity.steps.toDouble()
            : activity.distancekm;

        // Aynı gün içindeki değerleri topla
        dailyData[weekday] = (dailyData[weekday] ?? 0) + value;
      }

      // Günlük verileri FlSpot listesine dönüştür
      List<FlSpot> spots = [];

      // Sol tarafta üst üste binmeyi engellemek için günleri sıralı olarak ekle
      for (int i = 0; i < 7; i++) {
        final double yValue = dailyData[i] ?? 0.0;
        spots.add(FlSpot(i.toDouble(), yValue));
      }

      return spots;
    } catch (e) {
      debugPrint('Aktivite verisi işlenirken hata: $e');
      // Hata durumunda varsayılan veri döndür
      return [
        const FlSpot(0, 0),
        const FlSpot(1, 0),
        const FlSpot(2, 0),
        const FlSpot(3, 0),
        const FlSpot(4, 0),
        const FlSpot(5, 0),
        const FlSpot(6, 0),
      ];
    }
  }

  // Adımları kilometreye dönüştüren fonksiyon
  double stepsToKilometers(int steps) {
    // Ortalama adım uzunluğu (metre cinsinden)
    // Standart değerler: Erkekler için ~0.76m, Kadınlar için ~0.67m
    const double averageStepLength = 0.7; // 70 cm

    // Toplam mesafe (metre cinsinden)
    final double distanceInMeters = steps * averageStepLength;

    // Metreyi kilometreye çevir
    return distanceInMeters / 1000;
  }

  // Aktivite özeti için değerleri hesapla
  Map<String, double> _calculateSummary(List<ActivityModel>? activities) {
    if (activities == null || activities.isEmpty) {
      return {
        'totalDistance': 0.0,
        'totalSteps': 0.0,
        'totalCalories': 0.0,
        'averageSpeed': 0.0,
        'stepsInKm': 0.0,
      };
    }

    double totalDistance = 0.0;
    double totalSteps = 0.0;
    double totalCalories = 0.0;
    double totalSpeed = 0.0;
    int speedCount = 0;

    for (var activity in activities) {
      totalDistance += activity.distancekm;
      totalSteps += activity.steps.toDouble();

      if (activity.calories != null) {
        totalCalories += activity.calories!.toDouble();
      }

      if (activity.avarageSpeed != null) {
        totalSpeed += activity.avarageSpeed!.toDouble();
        speedCount++;
      }
    }

    double averageSpeed = speedCount > 0 ? totalSpeed / speedCount : 0.0;

    // Adımları km'ye çevir
    double stepsInKm = stepsToKilometers(totalSteps.toInt());

    return {
      'totalDistance': totalDistance,
      'totalSteps': totalSteps,
      'totalCalories': totalCalories,
      'averageSpeed': averageSpeed,
      'stepsInKm': stepsInKm,
    };
  }

  // Grafiğin maksimum Y değerini hesaplayan yardımcı fonksiyon
  double _calculateMaxY(List<FlSpot> spots) {
    if (spots.isEmpty) return _activeType == 'indoor' ? 1000 : 5;

    double maxValue = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);

    if (_activeType == 'indoor') {
      // Adım sayısı için üst sınır
      return (maxValue * 1.2).clamp(500.0, 5000.0);
    } else {
      // Mesafe için üst sınır
      return (maxValue * 1.2).clamp(1.0, 30.0);
    }
  }

  // Y eksenindeki interval değerini hesaplayan yardımcı fonksiyon
  double _calculateYAxisInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return _activeType == 'indoor' ? 250 : 1;

    double maxValue = spots.map((e) => e.y).reduce((a, b) => a > b ? a : b);

    if (_activeType == 'indoor') {
      // Indoor için sabit interval (250 adım)
      return 250;
    } else {
      // Outdoor ve Record için dinamik interval
      if (maxValue <= 1) {
        return 0.2; // Çok düşük değerler için 0.2 km aralıklarla göster
      } else if (maxValue <= 5) {
        return 0.5; // 1-5 km arası için 0.5 km aralıklarla göster
      } else if (maxValue <= 10) {
        return 1.0; // 5-10 km arası için 1 km aralıklarla göster
      } else if (maxValue <= 20) {
        return 2.0; // 10-20 km arası için 2 km aralıklarla göster
      } else {
        return 5.0; // 20+ km için 5 km aralıklarla göster
      }
    }
  }

  // Son yarış sonuçlarını çekmek için provider
  final recentRacesProvider = FutureProvider<List<dynamic>>((ref) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        throw Exception('Token bulunamadı');
      }

      final Map<String, dynamic> tokenData = jsonDecode(token);
      final String accessToken = tokenData['token'];

      final response = await http.get(
        Uri.parse(ApiConfig.lastThreeActivitiesEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data is List ? data : [];
      } else {
        throw Exception(
            'Yarış sonuçları getirilirken hata: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Yarış sonuçları provider hatası: $e');
      return [];
    }
  });

  @override
  Widget build(BuildContext context) {
    final userDataAsync = ref.watch(userDataProvider);
    final userRanksAsync = ref.watch(userRanksProvider);

    return Scaffold(
      backgroundColor: const Color.fromARGB(
          255, 0, 0, 0), // Dark background color from image
      body: SafeArea(
        child: userDataAsync.when(
          data: (userData) {
            if (userData == null) {
              // Provider yüklenmemiş, veriyi API'den çekelim
              Future.microtask(
                  () => ref.read(userDataProvider.notifier).fetchUserData());
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF93C53E)));
            }

            // Veri başarıyla yüklendiyse UI'ı oluştur
            return SingleChildScrollView(
              child: Column(
                children: [
                  // Profil Başlığı ve Fotoğraf (Updated Layout)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Stack(
                      children: [
                        // Ortalanmış İçerik (Fotoğraf ve Kullanıcı Bilgisi)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Profil fotoğrafı (Larger)
                              ProfilePictureWidget(
                                  userData:
                                      userData), // Use existing widget, size adjusted within
                              const SizedBox(height: 12), // Boşluk
                              // Kullanıcı adı
                              Text(
                                userData.fullName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22, // Increased font size
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4), // Boşluk
                              // Kullanıcı tag'i
                              Text(
                                '@${userData.userName}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 16, // Increased font size
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Sağ üst köşede coupon butonu (Positioned ile)
                        Positioned(
                          top: 64,
                          right: 16,
                          child: IconButton(
                            icon: const Icon(
                                Icons.discount_outlined, // Using outlined icon
                                color: Color(
                                    0xFF93C53E)), // Green color from image
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CouponScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 128,
                          right: 16,
                          child: IconButton(
                            icon: const Icon(
                                Icons.person_outline, // Using outlined icon
                                color: Color(
                                    0xFF93C53E)), // Green color from image
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const UpdateUserInfoScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 16,
                          child: IconButton(
                            icon: const Icon(
                                Icons.settings_outlined, // Using outlined icon
                                color: Color(
                                    0xFF93C53E)), // Green color from image
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SettingsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  //update user info button

                  // İstatistikler (Updated Style)
                  userRanksAsync.maybeWhen(
                    data: (userRanks) => _buildStatsContainer(userRanks),
                    orElse: () => _buildStatsContainer(null),
                  ),

                  // Performans Grafiği (Updated Section Layout)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          // Title aligned left
                          'Haftalık Performans',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18, // Slightly larger
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Aktivite türü filtreleme (Updated Button Style)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterButton(
                                  'Indoor', _activeType == 'indoor'),
                              const SizedBox(width: 8),
                              _buildFilterButton(
                                  'Outdoor', _activeType == 'outdoor'),
                              const SizedBox(width: 8),
                              _buildFilterButton(
                                  'Record', _activeType == 'record'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Aktivite verilerini gözlemliyoruz
                        Consumer(
                          builder: (context, ref, child) {
                            final activitiesAsync =
                                ref.watch(activityProfileProvider);

                            return activitiesAsync.when(
                              data: (activities) {
                                final spots = _getSpots(activities);
                                final summary = _calculateSummary(activities);

                                return Column(
                                  children: [
                                    // Geliştirilmiş Grafik (Updated Container Style)
                                    Container(
                                      height: 200,
                                      decoration: BoxDecoration(
                                        color: const Color.fromRGBO(30, 30, 30,
                                            1), // Updated background color
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.only(
                                          top: 16,
                                          bottom: 8,
                                          right: 12,
                                          left: 8), // Adjusted padding
                                      child: LineChart(
                                        LineChartData(
                                          lineTouchData: LineTouchData(
                                            enabled: true,
                                            touchTooltipData:
                                                LineTouchTooltipData(
                                              tooltipRoundedRadius: 100,
                                              getTooltipItems:
                                                  (List<LineBarSpot>
                                                      touchedSpots) {
                                                return touchedSpots.map((spot) {
                                                  return LineTooltipItem(
                                                    _activeType == 'indoor'
                                                        ? '${spot.y.toStringAsFixed(0)} Adım' // Simpler tooltip text
                                                        : '${spot.y.toStringAsFixed(1)} km', // Simpler tooltip text
                                                    const TextStyle(
                                                      color: Colors
                                                          .black, // Black text on green tooltip
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  );
                                                }).toList();
                                              },
                                            ),
                                          ),
                                          gridData: FlGridData(
                                            show: true,
                                            drawVerticalLine:
                                                false, // Hide vertical grid lines
                                            horizontalInterval:
                                                _calculateYAxisInterval(spots),
                                            // verticalInterval: 1, // Removed
                                            getDrawingHorizontalLine: (value) {
                                              return FlLine(
                                                color: Colors.white.withOpacity(
                                                    0.1), // Dimmer grid lines
                                                strokeWidth: 1,
                                              );
                                            },
                                            // getDrawingVerticalLine: (value) { ... } // Removed
                                            checkToShowHorizontalLine: (value) {
                                              // Show line only if it's not the bottom axis
                                              return value != 0;
                                            },
                                          ),
                                          titlesData: FlTitlesData(
                                            show: true,
                                            rightTitles: const AxisTitles(
                                              // Hide right titles
                                              sideTitles:
                                                  SideTitles(showTitles: false),
                                            ),
                                            topTitles: const AxisTitles(
                                              // Hide top titles
                                              sideTitles:
                                                  SideTitles(showTitles: false),
                                            ),
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 30,
                                                interval: 1,
                                                getTitlesWidget: (value, meta) {
                                                  final style = TextStyle(
                                                    // Dimmer axis labels
                                                    color: Colors.white
                                                        .withOpacity(0.6),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  );
                                                  String text;
                                                  switch (value.toInt()) {
                                                    case 0:
                                                      text = 'Pzt';
                                                      break;
                                                    case 1:
                                                      text = 'Sal';
                                                      break;
                                                    case 2:
                                                      text = 'Çar';
                                                      break;
                                                    case 3:
                                                      text = 'Per';
                                                      break;
                                                    case 4:
                                                      text = 'Cum';
                                                      break;
                                                    case 5:
                                                      text = 'Cmt';
                                                      break;
                                                    case 6:
                                                      text = 'Pa';
                                                      break; // Shortened Sunday
                                                    default:
                                                      text = '';
                                                  }
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 8.0),
                                                    child: Text(text,
                                                        style: style),
                                                  );
                                                },
                                              ),
                                            ),
                                            leftTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                interval:
                                                    _calculateYAxisInterval(
                                                        spots),
                                                getTitlesWidget: (value, meta) {
                                                  if (value == 0 ||
                                                      value >= meta.max) {
                                                    // Hide 0 and max value label
                                                    return const SizedBox
                                                        .shrink();
                                                  }
                                                  final displayValue = _activeType ==
                                                          'indoor'
                                                      ? value.toInt().toString()
                                                      : value.toStringAsFixed(
                                                          value.truncateToDouble() ==
                                                                  value
                                                              ? 0
                                                              : 1); // Show .0 if whole number for km

                                                  return Padding(
                                                    padding: const EdgeInsets
                                                        .only(
                                                        right:
                                                            4.0), // Reduced padding
                                                    child: Text(
                                                      displayValue,
                                                      style: TextStyle(
                                                        // Dimmer axis labels
                                                        color: Colors.white
                                                            .withOpacity(0.6),
                                                        fontSize: 12,
                                                      ),
                                                      textAlign:
                                                          TextAlign.right,
                                                    ),
                                                  );
                                                },
                                                reservedSize:
                                                    30, // Adjusted reserved size
                                              ),
                                            ),
                                          ),
                                          borderData: FlBorderData(
                                            show: false, // Hide border
                                          ),
                                          minX: 0,
                                          maxX: 6,
                                          minY: 0, // Start Y axis from 0
                                          // clipData: FlClipData.none(), // Removed
                                          maxY: _calculateMaxY(spots),
                                          lineBarsData: [
                                            LineChartBarData(
                                              spots: spots,
                                              isCurved: true,
                                              curveSmoothness:
                                                  0.35, // Slightly more curved
                                              preventCurveOverShooting: true,
                                              color: const Color(
                                                  0xFF93C53E), // Green line color
                                              barWidth: 4, // Thicker line
                                              isStrokeCapRound: true,
                                              dotData: FlDotData(
                                                  show: true,
                                                  getDotPainter: (spot, percent,
                                                      barData, index) {
                                                    // Only show dot for the max value
                                                    final isMax = spot.y ==
                                                        spots
                                                            .map((e) => e.y)
                                                            .reduce(math.max);
                                                    return FlDotCirclePainter(
                                                      radius: isMax
                                                          ? 5
                                                          : 0, // Show only max dot
                                                      color: const Color(
                                                          0xFF93C53E),
                                                      strokeWidth: 2,
                                                      strokeColor: const Color(
                                                          0xFF1E1E1E), // Match background
                                                    );
                                                  },
                                                  checkToShowDot:
                                                      (spot, barData) {
                                                    return spot.y >
                                                        0; // Don't show dots for 0 values visually (handled by radius above)
                                                  }),
                                              belowBarData: BarAreaData(
                                                // Gradient below line
                                                show: true,
                                                gradient: LinearGradient(
                                                  colors: [
                                                    const Color(0xFF93C53E)
                                                        .withOpacity(0.3),
                                                    const Color(0xFF93C53E)
                                                        .withOpacity(0.0),
                                                  ],
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Re-add the summary stats section below the chart
                                    const SizedBox(height: 20),
                                    _buildSummaryStats(summary),
                                  ],
                                );
                              },
                              loading: () => const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF93C53E),
                                ),
                              ),
                              error: (error, stackTrace) {
                                // ALWAYS show NetworkErrorWidget for activity data errors
                                return Center(
                                  child: NetworkErrorWidget(
                                    title: 'Aktivite Verisi Yüklenemedi',
                                    message:
                                        'Grafik verileri alınamadı, tekrar deneyin.',
                                    onRetry: () {
                                      // Retry fetching activity data
                                      ref.invalidate(activityProfileProvider);
                                      _fetchActivityData(); // Call the fetch function again
                                    },
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Recent Races Section (Updated Style)
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 16, right: 16, bottom: 16), // Adjusted padding
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start, // Align title left
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Son Yarışlar',
                              style: TextStyle(
                                fontSize: 18, // Match performance title size
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                // Aktif tipi Indoor'a sıfırla
                                setState(() {
                                  _activeType = 'indoor';
                                });
                                // Provider'ı doğrudan sıfırla - Indoor, Weekly olarak ayarla
                                ref
                                    .read(activityProfileProvider.notifier)
                                    .fetchActivities('indoor', 'weekly');
                                // Race Results ekranına geç
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const RaceResultsScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF93C53E),
                                padding:
                                    EdgeInsets.zero, // Remove default padding
                                visualDensity:
                                    VisualDensity.compact, // Make it tighter
                              ),
                              child: const Text(
                                'Tümünü Gör', // Changed text slightly
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12), // Adjusted spacing

                        // Son yarışlar için liste
                        Consumer(
                          builder: (context, ref, child) {
                            final racesAsync = ref.watch(recentRacesProvider);

                            return racesAsync.when(
                              data: (races) {
                                if (races.isEmpty) {
                                  return Container(
                                    // Consistent styling for empty state
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 30),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'Henüz yarış kaydınız bulunmuyor.',
                                      style: TextStyle(
                                          color: Colors.white54, fontSize: 14),
                                    ),
                                  );
                                }

                                // Display the 3 most recent races
                                return Column(
                                  children: races.take(3).map((race) {
                                    final startTime =
                                        DateTime.parse(race['startTime']);
                                    // Format date as: 28 Mar, 2025 - 20:51
                                    final formattedDate =
                                        '${startTime.day} ${_getMonthName(startTime.month)}, ${startTime.year} - ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
                                    final distanceStr = race['distancekm']
                                        ?.toStringAsFixed(
                                            2); // Keep 2 decimal places for KM
                                    final stepsStr =
                                        race['steps']?.toString() ??
                                            '0'; // Handle null steps
                                    final isIndoor =
                                        race['roomType'] == 'indoor';
                                    final rank = race['rank'];
                                    String rankText = '-';
                                    if (rank != null && rank > 0) {
                                      rankText = '$rank. Sıra';
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(
                                          bottom: 10), // Spacing between items
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                            0xFF2A2A2A), // Darker item background
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          // Icon
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF93C53E)
                                                  .withOpacity(
                                                      0.15), // Subtle green background
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              isIndoor
                                                  ? Icons
                                                      .directions_run // Running icon for indoor
                                                  : Icons
                                                      .terrain_outlined, // Mountain icon for outdoor
                                              color: const Color(0xFF93C53E),
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Middle section (Type, Date)
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isIndoor
                                                      ? 'İç Mekan'
                                                      : 'Dış Mekan',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  formattedDate, // Use the new format
                                                  style: TextStyle(
                                                    fontSize:
                                                        12, // Smaller date font
                                                    color: Colors.white
                                                        .withOpacity(
                                                            0.6), // Dimmer date
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Right section (Rank, Distance/Steps, Calories)
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                rankText, // Display rank text
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.8),
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              // --- YENİ: Kalori, Mesafe, Adım Row'u ---
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  // Kalori (varsa göster)
                                                  if (race['calories'] !=
                                                          null &&
                                                      race['calories'] > 0) ...[
                                                    Icon(
                                                        Icons
                                                            .local_fire_department_outlined,
                                                        color:
                                                            Colors.orangeAccent,
                                                        size: 14),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${race['calories']} kcal',
                                                      style: const TextStyle(
                                                          color: Colors
                                                              .orangeAccent,
                                                          fontSize: 12.0),
                                                    ),
                                                    const SizedBox(
                                                        width:
                                                            8), // Kalori ve diğerleri arasına boşluk
                                                  ],
                                                  // Mesafe (Dış Mekan ise)
                                                  if (!isIndoor)
                                                    Icon(
                                                        Icons
                                                            .directions_run_outlined,
                                                        color:
                                                            Colors.blueAccent,
                                                        size: 14),
                                                  if (!isIndoor)
                                                    const SizedBox(width: 4),
                                                  if (!isIndoor)
                                                    Text(
                                                      '$distanceStr km',
                                                      style: const TextStyle(
                                                          color:
                                                              Colors.blueAccent,
                                                          fontSize: 12.0),
                                                    ),
                                                  if (!isIndoor)
                                                    const SizedBox(
                                                        width:
                                                            8), // Mesafe ve adım arasına boşluk

                                                  // Adım Sayısı
                                                  Icon(
                                                      Icons
                                                          .directions_walk_outlined,
                                                      color: Colors.greenAccent,
                                                      size: 14),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '$stepsStr Adım',
                                                    style: const TextStyle(
                                                        color:
                                                            Colors.greenAccent,
                                                        fontSize: 12.0),
                                                  ),
                                                ],
                                              ),
                                              // --- YENİ: Kalori, Mesafe, Adım Row'u Sonu ---
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                              loading: () => const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 30.0),
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF93C53E),
                                    ),
                                  ),
                                ),
                              ),
                              error: (error, _) => Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 30.0),
                                  child: Text(
                                    'Yarışlar yüklenemedi.', // Simpler error message
                                    style: const TextStyle(
                                        color: Colors.redAccent),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFF93C53E))),
          error: (error, stackTrace) {
            // ALWAYS show NetworkErrorWidget for any full-screen error
            return Center(
              child: NetworkErrorWidget(
                // Provide generic title/message for all errors
                title: 'Profil Yüklenemedi',
                message: 'Profil bilgileri alınamadı, lütfen tekrar deneyin.',
                onRetry: () {
                  ref.invalidate(
                      userDataProvider); // Invalidate to force refetch
                  ref.invalidate(userRanksProvider);
                  ref.invalidate(activityProfileProvider);
                  ref.invalidate(userStreakProvider);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterButton(String typeKey, bool isSelected) {
    String buttonText;
    switch (typeKey.toLowerCase()) {
      case 'indoor':
        buttonText = 'İç Mekan';
        break;
      case 'outdoor':
        buttonText = 'Dış Mekan';
        break;
      case 'record':
        buttonText = 'Kayıt'; // Assuming 'Record' maps to 'Kayıt'
        break;
      default:
        buttonText = typeKey;
    }

    return GestureDetector(
      onTap: () => _updateActiveType(typeKey.toLowerCase()),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 8), // Adjusted padding
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF93C53E)
              : const Color(0xFF3A3A3A), // Updated colors
          borderRadius: BorderRadius.circular(20), // More rounded corners
        ),
        child: Text(
          buttonText,
          style: TextStyle(
            color: isSelected
                ? Colors.black
                : Colors.white, // Black text on selected
            fontSize: 14, // Slightly larger text
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.w500, // Adjust weight
          ),
        ),
      ),
    );
  }

  // Ay isimlerini döndüren yardımcı fonksiyon
  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  // Streak için özel stat widget - API'den veriyi alır
  Widget _buildStreakStatIcon() {
    return Consumer(
      builder: (context, ref, child) {
        final streakAsync = ref.watch(userStreakProvider);

        return streakAsync.when(
          data: (streakCount) {
            return _buildStatIcon(
              icon: Icons.local_fire_department_outlined, // Use outlined icon
              value: streakCount.toString(),
              label: 'Günlük Seri',
              iconColor:
                  const Color(0xFFFFA000), // Orange/Yellow color for fire
              backgroundColor: const Color(0xFFFFA000)
                  .withOpacity(0.15), // Match icon color opacity
            );
          },
          loading: () => Expanded(
            // Consistent loading placeholder
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                    width: 36,
                    height: 36, // Match icon container size
                    child: Padding(
                      padding: EdgeInsets.all(8.0), // Padding inside circle
                      child: CircularProgressIndicator(
                          color: Colors.white54, strokeWidth: 2),
                    )),
                const SizedBox(height: 8),
                const Text('',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors
                            .transparent)), // Placeholder for value alignment
                const SizedBox(height: 4),
                Text('Günlük Seri',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          error: (_, __) => _buildStatIcon(
            // Consistent error placeholder
            icon: Icons.local_fire_department_outlined,
            value: '-', // Indicate error/no data
            label: 'Günlük Seri',
            iconColor: Colors.grey.shade600, // Grey out on error
            backgroundColor: Colors.grey.withOpacity(0.15),
          ),
        );
      },
    );
  }

  // Yeni icon stat widget'ı (Updated Style)
  Widget _buildStatIcon({
    IconData? icon,
    Widget? iconWidget,
    required String value,
    required String label,
    required Color iconColor,
    Color? backgroundColor, // Optional background color override
  }) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8), // Reduced padding
            decoration: BoxDecoration(
              color: backgroundColor ??
                  Colors.white.withOpacity(0.1), // Use provided bg or default
              shape: BoxShape.circle,
            ),
            child: iconWidget ??
                Icon(
                  icon,
                  color: iconColor,
                  size: 20, // Reduced icon size
                ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18, // Slightly smaller value text
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12, // Standard label size
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // İstatistikler için daha kompakt ve responsive container (Updated Style)
  Widget _buildStatsContainer(UserRanksModel? userRanks) {
    final userCoinsAsync = ref.watch(userDataProvider).value?.coins;
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 10), // Adjusted margin
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 12), // Adjusted padding
      decoration: BoxDecoration(
        color:
            const Color.fromRGBO(30, 30, 30, 1), // Darker container background
        borderRadius: BorderRadius.circular(16), // Slightly less rounded
      ),
      child: IntrinsicHeight(
        // Ensure icons/text align vertically if labels wrap
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatIcon(
              icon: Icons.home_outlined, // Use outlined icon
              value: userRanks?.indoorRank.toString() ?? "-",
              label: 'İç', // Label from image
              iconColor: const Color(0xFF93C53E), // Green icon
              backgroundColor:
                  const Color(0xFF93C53E).withOpacity(0.15), // Green background
            ),
            _buildStatIcon(
              icon: Icons
                  .terrain_outlined, // Use outlined icon (closer to mountain)
              value: userRanks?.outdoorRank.toString() ?? "-",
              label: 'Dış', // Label from image
              iconColor: const Color(0xFF93C53E), // Green icon
              backgroundColor:
                  const Color(0xFF93C53E).withOpacity(0.15), // Green background
            ),
            _buildStreakStatIcon(), // Uses its own styling logic
            _buildStatIcon(
              iconWidget: Image.asset(
                'assets/images/mCoin.png',
                width: 24,
                height: 24,
              ),
              value: userCoinsAsync?.toStringAsFixed(2) ??
                  '0.00', // Format to 2 decimal places
              label: 'Movliq Coin', // Label from image
              iconColor: Colors.amber, // Gold color for coin
              backgroundColor:
                  const Color(0xFFFFD700).withOpacity(0.15), // Gold background
            ),
          ],
        ),
      ),
    );
  }

  // Widget for the summary stats section below the chart
  Widget _buildSummaryStats(Map<String, double> summary) {
    final totalSteps = summary['totalSteps']?.toInt() ?? 0;
    final estimatedKm = summary['stepsInKm'] ?? 0.0;
    final totalDistanceKm =
        summary['totalDistance'] ?? 0.0; // Get total distance
    final totalCalories = summary['totalCalories']?.toInt() ?? 0;

    // Determine the value and label for the middle stat based on activeType
    final String middleValue;
    final String middleLabel;
    final IconData middleIcon;

    if (_activeType == 'indoor') {
      middleValue = '${estimatedKm.toStringAsFixed(2)} km';
      middleLabel = 'Tahmini Mesafe';
      middleIcon = Icons.timeline; // Or Icons.straighten
    } else {
      // Outdoor or Record
      middleValue = '${totalDistanceKm.toStringAsFixed(2)} km';
      middleLabel = 'Toplam Mesafe';
      middleIcon = Icons.route_outlined; // Route icon for outdoor distance
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16.0, vertical: 10.0), // Add vertical padding
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSummaryStatItem(
            icon: Icons.directions_run,
            value: totalSteps.toString(),
            label: 'Toplam Adım',
            iconColor: const Color(0xFF93C53E),
          ),
          _buildSummaryStatItem(
            icon: middleIcon, // Use dynamic icon
            value: middleValue, // Use dynamic value
            label: middleLabel, // Use dynamic label
            iconColor: const Color(0xFF93C53E),
          ),
          _buildSummaryStatItem(
            icon: Icons.local_fire_department_outlined,
            value: '$totalCalories kcal',
            label: 'Toplam Kalori',
            iconColor: const Color(0xFFFFA000), // Orange for calories
          ),
        ],
      ),
    );
  }

  // Helper for individual stat items in the summary section
  Widget _buildSummaryStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class ProfilePictureWidget extends StatefulWidget {
  final UserDataModel userData;

  const ProfilePictureWidget({
    super.key,
    required this.userData,
  });

  @override
  State<ProfilePictureWidget> createState() => _ProfilePictureWidgetState();
}

class _ProfilePictureWidgetState extends State<ProfilePictureWidget> {
  bool _isUploading = false;
  File? _localImageFile;
  Key _imageKey = UniqueKey();

  Future<void> _selectAndUploadProfileImage(
      BuildContext context, WidgetRef ref) async {
    try {
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Profil Fotoğrafı'),
          content: const Text('Fotoğraf kaynağını seçin'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: const Text('Galeri'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: const Text('Kamera'),
            ),
          ],
        ),
      );

      if (source == null) return;

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      _localImageFile = File(image.path);

      setState(() {
        _isUploading = true;
        _imageKey = UniqueKey();
      });

      final tokenJson = await StorageService.getToken();
      if (tokenJson == null) {
        _showErrorMessage(
            context, 'Oturum bilgisi bulunamadı. Lütfen tekrar giriş yapın.');
        setState(() {
          _isUploading = false;
          _localImageFile = null;
        });
        return;
      }

      final response = await _uploadProfileImage(image.path, tokenJson);

      if (response.statusCode == 200) {
        // Başarılı yanıt alındı, verileri yeniden fetch et
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();

        // Kullanıcı verisini ve coinleri yeniden çek

        ref.read(userDataProvider.notifier).fetchUserData();
        ref.read(userDataProvider.notifier).fetchCoins();

        _showSuccessMessage(context, 'Profil fotoğrafı başarıyla güncellendi');

        // Yeni veriyi yansıtmak için UI'ı yeniden çizmek için state'i güncelle
        setState(() {
          _imageKey = UniqueKey(); // Ensure image rebuilds with new data
          _localImageFile = null; // Clear local file reference
        });
      } else {
        _showErrorMessage(
            context, 'Profil fotoğrafı yüklenirken bir hata oluştu');
        _localImageFile = null; // Hata durumunda yerel dosyayı temizle
      }
    } catch (e) {
      _showErrorMessage(context, 'Hata: $e');
      _localImageFile = null; // Hata durumunda yerel dosyayı temizle
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<http.Response> _uploadProfileImage(
      String imagePath, String tokenJson) async {
    final Map<String, dynamic> tokenData = jsonDecode(tokenJson);
    final String token = tokenData['token'];

    var request = http.MultipartRequest(
      'POST',
      Uri.parse(
          'http://movliq.mehmetalicakir.tr:5000/api/User/upload-profile-picture'),
    );

    request.headers.addAll({
      'Authorization': 'Bearer $token',
    });

    request.files.add(
      await http.MultipartFile.fromPath('profilePicture', imagePath),
    );

    var streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
  }

  void _showErrorMessage(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessMessage(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final userDataAsync = ref.watch(userDataProvider);

        // Get the latest user data, falling back to initial widget data if needed
        final UserDataModel currentUserData = userDataAsync.maybeWhen(
          data: (userData) => userData ?? widget.userData,
          orElse: () => widget.userData,
        );

        final profileUrl = currentUserData.profilePictureUrl;

        // Determine the image provider
        final ImageProvider imageProvider = _localImageFile != null
            ? FileImage(_localImageFile!) // Show local file if selected
            : (profileUrl != null && profileUrl.isNotEmpty
                ? NetworkImage(profileUrl) // Use NetworkImage directly
                : const AssetImage(
                    'assets/images/runningman.png')); // Fallback asset

        const double imageSize = 100; // Increased size
        const double cameraIconSize = 30; // Size of the camera icon circle
        const double cameraIconPositionOffset = -5; // Offset for camera icon

        return GestureDetector(
          onTap: _isUploading
              ? null
              : () => _selectAndUploadProfileImage(
                  context, ref), // Disable tap during upload
          child: Stack(
            clipBehavior: Clip.none, // Allow camera icon to overflow
            alignment: Alignment.center,
            children: [
              Container(
                // Apply border directly to the container for consistent look
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF93C53E)
                        .withOpacity(0.5), // Subtle green border
                    width: 2,
                  ),
                  // Optional: Add a background color for the circle before image loads
                  // color: Colors.grey.shade800,
                ),
                child: CircleAvatar(
                  // Use CircleAvatar for easy clipping
                  radius: imageSize / 2,
                  backgroundColor: Colors.transparent, // Transparent background
                  key: _imageKey, // Use the key here for potential rebuilds
                  backgroundImage: imageProvider,
                  onBackgroundImageError: (exception, stackTrace) {
                    // Handle background image error if needed, though errorBuilder is primary
                    debugPrint("BackgroundImage Error: $exception");
                  },
                  child: _isUploading
                      ? Container(
                          // Loading overlay
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.6),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            ),
                          ),
                        )
                      : null, // No child when not uploading
                  // Fallback for when backgroundImage fails (e.g., invalid URL, network issue)
                  // Note: This might not be reached if AssetImage is the fallback in imageProvider
                  // Consider using a custom Image widget inside if more control is needed.
                  // Example using Image.network with errorBuilder (more robust):
                  /*
                     child: ClipOval(
                       child: Image(
                         image: imageProvider,
                         key: _imageKey, // Key for Image widget if used directly
                         width: imageSize,
                         height: imageSize,
                         fit: BoxFit.cover,
                         gaplessPlayback: true, // Prevents flicker on image update
                         errorBuilder: (context, error, stackTrace) {
                           debugPrint('Profile image load error: $error');
                           return Container( // Fallback placeholder
                             width: imageSize,
                             height: imageSize,
                             decoration: BoxDecoration(
                               shape: BoxShape.circle,
                               color: Colors.grey.shade700, // Darker placeholder
                             ),
                             child: Icon(
                               Icons.person_outline, // Outlined icon
                               color: Colors.white70,
                               size: imageSize * 0.6, // Adjust icon size relative to circle
                             ),
                           );
                         },
                         loadingBuilder: (context, child, loadingProgress) {
                           if (loadingProgress == null) return child; // Image loaded
                           return Container( // Placeholder during loading
                             width: imageSize,
                             height: imageSize,
                             decoration: BoxDecoration(
                               shape: BoxShape.circle,
                               color: Colors.grey.shade800,
                             ),
                             child: Center(
                               child: CircularProgressIndicator(
                                 value: loadingProgress.expectedTotalBytes != null
                                     ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                     : null,
                                 color: const Color(0xFF93C53E),
                                 strokeWidth: 2,
                               ),
                             ),
                           );
                         },
                       ),
                     ),
                     */
                ),
              ),
              // Camera Icon (Styled as per image)
              if (!_isUploading) // Only show camera icon when not uploading
                Positioned(
                  right: cameraIconPositionOffset,
                  bottom: cameraIconPositionOffset,
                  child: Container(
                    width: cameraIconSize,
                    height: cameraIconSize,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC4FF62), // Bright green from image
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(
                            0xFF1E1E1E), // Match screen background color
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded, // Rounded camera icon
                      color: Colors.black,
                      size: 16, // Adjust icon size within circle
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
