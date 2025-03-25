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
    Future.microtask(() {
      ref.read(userDataProvider.notifier).fetchUserData();
      _fetchActivityData(); // Aktivite verilerini yükle
      ref.refresh(userRanksProvider); // Kullanıcı sıralamasını yükle
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
    // Kullanıcı verilerini izleyelim
    final userDataAsync = ref.watch(userDataProvider);
    // Kullanıcı sıralama provider'ını dinle
    final userRanksAsync = ref.watch(userRanksProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            stops: [0.0, 1.0],
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFC4FF62),
              Color.fromARGB(255, 72, 108, 14),
            ],
          ),
        ),
        child: SafeArea(
          child: userDataAsync.when(
            data: (userData) {
              if (userData == null) {
                // Provider yüklenmemiş, veriyi API'den çekelim
                Future.microtask(
                    () => ref.read(userDataProvider.notifier).fetchUserData());
                return const Center(child: CircularProgressIndicator());
              }

              // Veri başarıyla yüklendiyse UI'ı oluştur
              return SingleChildScrollView(
                child: Column(
                  children: [
                    // Profil Başlığı ve Fotoğraf
                    Container(
                      height: 200,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: [
                          // Arka plan resim
                          Container(
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage(
                                    'assets/images/loginbackground.jpg'),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          // Gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.3),
                                  Colors.black.withOpacity(0.5),
                                ],
                              ),
                            ),
                          ),
                          // Ayarlar butonu
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.settings,
                                    color: Colors.white),
                                padding: EdgeInsets.zero,
                                iconSize: 24,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const SettingsScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          // Profil bilgileri ve fotoğraf
                          Positioned(
                            bottom: 20,
                            left: 20,
                            right: 20,
                            child: Row(
                              children: [
                                // Profil fotoğrafı - artık kendi widget'ını kullanıyoruz
                                ProfilePictureWidget(userData: userData),
                                const SizedBox(width: 16),
                                // İsim ve kullanıcı adı (Flexible kullanarak taşmayı engelliyoruz)
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userData.fullName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '@${userData.userName}',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 16,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // İstatistikler - İzleme ile birlikte yeni fonksiyonu çağıralım
                    userRanksAsync.maybeWhen(
                      data: (userRanks) => _buildStatsContainer(userRanks),
                      orElse: () => _buildStatsContainer(null),
                    ),

                    // Rozetler
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Badges',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text('View All'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 90,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildBadge(Colors.amber, 'Marathon Pro'),
                                _buildBadge(Colors.black87, '100km Club'),
                                _buildBadge(Colors.purple, 'Early Bird'),
                                _buildBadge(Colors.green, 'Pace Setter'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Performans Grafiği
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Haftalık Performans',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Aktivite türü filtreleme
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
                                      // Geliştirilmiş Grafik - yüksekliği sabit tutuyoruz
                                      Container(
                                        height: 240,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF93C53E),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.1),
                                              spreadRadius: 1,
                                              blurRadius: 10,
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 16),
                                        child: LineChart(
                                          LineChartData(
                                            lineTouchData: LineTouchData(
                                              enabled: true,
                                              touchTooltipData:
                                                  LineTouchTooltipData(
                                                tooltipRoundedRadius: 8,
                                                getTooltipItems:
                                                    (List<LineBarSpot>
                                                        touchedSpots) {
                                                  return touchedSpots
                                                      .map((spot) {
                                                    return LineTooltipItem(
                                                      _activeType == 'indoor'
                                                          ? '${spot.y.toStringAsFixed(0)} adım\n(${stepsToKilometers(spot.y.toInt()).toStringAsFixed(2)} km)'
                                                          : '${spot.y.toStringAsFixed(2)} km',
                                                      const TextStyle(
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    );
                                                  }).toList();
                                                },
                                              ),
                                            ),
                                            gridData: FlGridData(
                                              show: true,
                                              drawVerticalLine: true,
                                              horizontalInterval:
                                                  _calculateYAxisInterval(
                                                      spots),
                                              verticalInterval: 1,
                                              getDrawingHorizontalLine:
                                                  (value) {
                                                return FlLine(
                                                  color: Colors.white
                                                      .withOpacity(0.2),
                                                  strokeWidth: 1,
                                                  dashArray: [5, 5],
                                                );
                                              },
                                              getDrawingVerticalLine: (value) {
                                                return FlLine(
                                                  color: Colors.white
                                                      .withOpacity(0.2),
                                                  strokeWidth: 1,
                                                  dashArray: [5, 5],
                                                );
                                              },
                                              checkToShowHorizontalLine:
                                                  (value) {
                                                // Sıfıra yakın değerler için yatay çizgi gösterme
                                                return value > 0.1;
                                              },
                                            ),
                                            titlesData: FlTitlesData(
                                              show: true,
                                              rightTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                    showTitles: false),
                                              ),
                                              topTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                    showTitles: false),
                                              ),
                                              bottomTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 30,
                                                  interval: 1,
                                                  getTitlesWidget:
                                                      (value, meta) {
                                                    const style = TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                    );
                                                    String text;

                                                    // Haftalık görünüm için gün isimleri göster
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
                                                        text = 'Paz';
                                                        break;
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
                                                  getTitlesWidget:
                                                      (value, meta) {
                                                    // Sıfıra yakın değerler için etiket gösterme
                                                    if (value < 0.1)
                                                      return const SizedBox
                                                          .shrink();

                                                    // Indoor modunda tam sayı göster, outdoor modunda 2 ondalık basamak
                                                    final displayValue =
                                                        _activeType == 'indoor'
                                                            ? value
                                                                .toInt()
                                                                .toString()
                                                            : value
                                                                .toStringAsFixed(
                                                                    2);

                                                    return Text(
                                                      displayValue,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                      ),
                                                      textAlign:
                                                          TextAlign.right,
                                                    );
                                                  },
                                                  reservedSize: 40,
                                                ),
                                              ),
                                            ),
                                            borderData: FlBorderData(
                                              show: true,
                                              border: Border.all(
                                                color: Colors.white
                                                    .withOpacity(0.2),
                                              ),
                                            ),
                                            minX: 0,
                                            maxX: 6,
                                            minY: 0.01,
                                            clipData: FlClipData.none(),
                                            maxY: _calculateMaxY(spots),
                                            lineBarsData: [
                                              LineChartBarData(
                                                spots: spots,
                                                isCurved: true,
                                                curveSmoothness: 0.2,
                                                preventCurveOverShooting: true,
                                                color: Colors.white,
                                                barWidth: 3,
                                                isStrokeCapRound: true,
                                                dotData: FlDotData(
                                                  show: true,
                                                  getDotPainter: (spot, percent,
                                                      barData, index) {
                                                    return FlDotCirclePainter(
                                                      radius: 5,
                                                      color: Colors.white,
                                                      strokeWidth: 2,
                                                      strokeColor: Colors.white,
                                                    );
                                                  },
                                                  checkToShowDot:
                                                      (spot, barData) {
                                                    // Sıfır değerlerine sahip noktaları gösterme
                                                    return spot.y > 0;
                                                  },
                                                ),
                                                belowBarData: BarAreaData(
                                                  show: true,
                                                  color: Colors.white
                                                      .withOpacity(0.2),
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.white
                                                          .withOpacity(0.3),
                                                      Colors.white
                                                          .withOpacity(0.1),
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

                                      // Grafik altı istatistik özeti - scrollview ile taşma engelleniyor
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 0, vertical: 16),
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceEvenly,
                                            children: [
                                              _buildStatCard(
                                                  _activeType == 'indoor'
                                                      ? 'Toplam Adım'
                                                      : 'Toplam Mesafe',
                                                  _activeType == 'indoor'
                                                      ? '${summary['totalSteps']?.toStringAsFixed(0)}'
                                                      : '${summary['totalDistance']?.toStringAsFixed(2)} km'),
                                              const SizedBox(width: 4),
                                              _buildStatCard(
                                                  _activeType == 'indoor'
                                                      ? 'Tahmini Mesafe'
                                                      : 'Toplam Adım',
                                                  _activeType == 'indoor'
                                                      ? '${summary['stepsInKm']?.toStringAsFixed(2)} km'
                                                      : '${summary['totalSteps']?.toStringAsFixed(0)}'),
                                              const SizedBox(width: 4),
                                              _buildStatCard('Toplam Kalori',
                                                  '${summary['totalCalories']?.toStringAsFixed(0)} kcal'),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                                loading: () => const Center(
                                  child: SizedBox(
                                    height: 240,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFFC4FF62),
                                      ),
                                    ),
                                  ),
                                ),
                                error: (error, stackTrace) => SizedBox(
                                  height: 240,
                                  child: Center(
                                    child: Text(
                                      'Veriler yüklenirken hata oluştu: $error',
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Recent Races Section
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Recent Races',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RaceResultsScreen(),
                                    ),
                                  );
                                },
                                child: const Text('See All'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Son 3 yarış sonucunu listele
                          Consumer(
                            builder: (context, ref, child) {
                              final racesAsync = ref.watch(recentRacesProvider);

                              return racesAsync.when(
                                data: (races) {
                                  if (races.isEmpty) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text(
                                          'Henüz yarış kaydınız bulunmuyor.',
                                          style:
                                              TextStyle(color: Colors.white70),
                                        ),
                                      ),
                                    );
                                  }

                                  return Column(
                                    children: races.map((race) {
                                      // Yarış tarihini formatlama
                                      final startTime =
                                          DateTime.parse(race['startTime']);
                                      final formattedDate =
                                          '${startTime.day} ${_getMonthName(startTime.month)}, ${startTime.year} - ${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';

                                      // Süreyi formatlama (API'de duration)
                                      final duration = race['duration'] ?? 0;
                                      final hours = duration ~/ 60;
                                      final minutes = duration % 60;
                                      final formattedDuration = hours > 0
                                          ? '${hours}h ${minutes}m'
                                          : '${minutes}m';

                                      // Mesafeyi formatlama
                                      final distance =
                                          race['distancekm'] ?? 0.0;
                                      final distanceStr =
                                          distance.toStringAsFixed(2);

                                      // Yeri (rank) gösterme
                                      final rank = race['rank'];
                                      String rankText = rank != null
                                          ? '${rank}. Sıra'
                                          : 'Sıralama yok';

                                      if (rank == 1) rankText = '1. Sıra';
                                      if (rank == 2) rankText = '2. Sıra';
                                      if (rank == 3) rankText = '3. Sıra';

                                      return _buildRaceItem(
                                        date: formattedDate,
                                        distance: '${distanceStr}km',
                                        duration: formattedDuration,
                                        place: rankText,
                                        type: race['roomType'] == 'indoor'
                                            ? 'Indoor'
                                            : 'Outdoor',
                                      );
                                    }).toList(),
                                  );
                                },
                                loading: () => const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                error: (error, _) => Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'Veriler yüklenirken hata: $error',
                                      style: const TextStyle(color: Colors.red),
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Hata: $error',
                      style: const TextStyle(color: Colors.red)),
                  ElevatedButton(
                    onPressed: () =>
                        ref.read(userDataProvider.notifier).fetchUserData(),
                    child: const Text('Yeniden Dene'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBadge(Color color, String label) {
    // Label'ı tek satır olarak göster, çok uzunsa kırp
    final displayLabel = label.replaceAll('\n', ' ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // İkon container'ı yüksekliğini azalt
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 5,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.emoji_events, color: Colors.white, size: 25),
        ),
        const SizedBox(height: 4),
        // Sabit yükseklik ve genişlik olan Container içindeki text
        SizedBox(
          width: 60,
          height: 30,
          child: Center(
            child: Text(
              displayLabel,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(String text, bool isSelected) {
    return GestureDetector(
      onTap: () => _updateActiveType(text.toLowerCase()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRaceItem({
    required String date,
    required String distance,
    required String duration,
    required String place,
    required String type,
  }) {
    // Dereceye göre renk belirle
    Color rankColor;
    if (place.contains('1.')) {
      rankColor = Colors.amber[700]!;
    } else if (place.contains('2.')) {
      rankColor = Colors.blueGrey[700]!;
    } else if (place.contains('3.')) {
      rankColor = Colors.brown[700]!;
    } else {
      rankColor = Colors.grey[600]!;
    }

    // Türe göre renk belirle
    Color typeColor =
        type.toLowerCase() == 'indoor' ? Colors.blue[600]! : Colors.green[600]!;
    IconData typeIcon = type.toLowerCase() == 'indoor'
        ? Icons.home_outlined
        : Icons.terrain_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/images/Movliq_beyaz.png',
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          // Orta kısım (tarih ve mesafe)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    // Tarih için Flexible widget kullanarak taşmayı engelliyoruz
                    Flexible(
                      child: Text(
                        date,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.straighten, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    // Mesafe ve süre için daha kompakt gösterim
                    Flexible(
                      child: Text(
                        '$distance • $duration',
                        style: TextStyle(color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Yarış türü etiketi
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            typeIcon,
                            size: 12,
                            color: typeColor,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            type,
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Sağ kısım (derece ve ok)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: place.contains('Sıralama yok')
                  ? Colors.grey[200]
                  : rankColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                    place.contains('Sıralama yok')
                        ? Icons.help_outline
                        : Icons.emoji_events,
                    size: 14,
                    color: rankColor),
                const SizedBox(width: 4),
                Text(
                  place,
                  style: TextStyle(
                    color: rankColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Sağ ok ikonu
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    // Her etiket için uygun ikon seç
    IconData iconData;
    Color iconBackgroundColor;

    if (label.contains('Adım') || label.contains('Mesafe')) {
      iconData = Icons.directions_run;
      iconBackgroundColor = const Color(0xFF4CAF50);
    } else if (label.contains('Hız')) {
      iconData = Icons.speed;
      iconBackgroundColor = const Color(0xFF2196F3);
    } else if (label.contains('Kalori')) {
      iconData = Icons.local_fire_department;
      iconBackgroundColor = const Color(0xFFFF9800);
    } else {
      iconData = Icons.analytics;
      iconBackgroundColor = const Color(0xFF9C27B0);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      // Sabit genişlik yerine ekranın genişliğine göre ayarlayalım
      width: (MediaQuery.of(context).size.width - 40) / 3.2,
      height: 75,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF93C53E).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // İkon arka plan ile birlikte ekleniyor
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconData,
                  color: Colors.white,
                  size: 12,
                ),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label.replaceAll('\n', ' '),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
              icon: Icons.local_fire_department_outlined,
              value: streakCount.toString(),
              label: 'Günlük Seri',
              iconColor: Colors.deepOrange,
            );
          },
          loading: () => const Center(
            child: SizedBox(
              width: 80,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      )),
                  SizedBox(height: 8),
                  Text(
                    'Yükleniyor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          error: (_, __) => _buildStatIcon(
            icon: Icons.local_fire_department_outlined,
            value: '0',
            label: 'Günlük Seri',
            iconColor: Colors.deepOrange,
          ),
        );
      },
    );
  }

  // Yeni icon stat widget'ı
  Widget _buildStatIcon({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
  }) {
    return Container(
      width: MediaQuery.of(context).size.width / 4 - 20,
      child: Column(
        children: [
          // İkon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          // Değer
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Etiket
          Text(
            label,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 12,
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

  // İstatistikler için daha kompakt ve responsive container
  Widget _buildStatsContainer(UserRanksModel? userRanks) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFC4FF62), // Movliq yeşili
            Color(0xFF9BDC28), // Daha koyu yeşil
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // İç mekan sıralaması
          _buildStatIcon(
            icon: Icons.home_outlined,
            value: userRanks != null ? userRanks.indoorRank.toString() : "-",
            label: 'İç',
            iconColor: Colors.blue,
          ),
          // Dış mekan sıralaması
          _buildStatIcon(
            icon: Icons.terrain_outlined,
            value: userRanks != null ? userRanks.outdoorRank.toString() : "-",
            label: 'Dış',
            iconColor: Colors.green,
          ),
          _buildStreakStatIcon(),
          _buildStatIcon(
            icon: Icons.monetization_on_outlined,
            value: '32',
            label: 'Coin',
            iconColor: Colors.amber,
          ),
        ],
      ),
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
        final data = jsonDecode(response.body);

        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();

        final userData = ref.read(userDataProvider).value;
        if (userData != null) {
          final updatedUserData = UserDataModel(
              id: userData.id,
              name: userData.name,
              surname: userData.surname,
              userName: userData.userName,
              email: userData.email,
              phoneNumber: userData.phoneNumber,
              address: userData.address,
              age: userData.age,
              height: userData.height,
              weight: userData.weight,
              gender: userData.gender,
              profilePicturePath:
                  data['profilePictureUrl'] ?? userData.profilePicturePath,
              runprefer: userData.runprefer,
              active: userData.active,
              isActive: userData.isActive,
              distancekm: userData.distancekm,
              steps: userData.steps,
              rank: userData.rank,
              generalRank: userData.generalRank,
              birthday: userData.birthday,
              createdAt: userData.createdAt);

          ref.read(userDataProvider.notifier).updateUserData(updatedUserData);
        }

        _showSuccessMessage(context, 'Profil fotoğrafı başarıyla güncellendi');

        setState(() {
          _imageKey = UniqueKey();
        });
      } else {
        _showErrorMessage(
            context, 'Profil fotoğrafı yüklenirken bir hata oluştu');
        _localImageFile = null;
      }
    } catch (e) {
      _showErrorMessage(context, 'Hata: $e');
      _localImageFile = null;
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

        final UserDataModel currentUserData = userDataAsync.maybeWhen(
          data: (userData) => userData ?? widget.userData,
          orElse: () => widget.userData,
        );

        final profileUrl = currentUserData.profilePictureUrl;

        final imageProvider = _localImageFile != null
            ? FileImage(_localImageFile!) as ImageProvider
            : (profileUrl != null && profileUrl.isNotEmpty
                ? NetworkImage(
                    "$profileUrl?nocache=${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().toString()}")
                : const AssetImage('assets/images/runningman.png')
                    as ImageProvider);

        return GestureDetector(
          onTap: () => _selectAndUploadProfileImage(context, ref),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                key: _imageKey,
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                ),
                child: _isUploading
                    ? Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.5),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                      )
                    : ClipOval(
                        child: Image(
                          key: ValueKey(profileUrl),
                          image: imageProvider,
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Profil resmi yüklenirken hata: $error');
                            return Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 50,
                              ),
                            );
                          },
                        ),
                      ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC4FF62),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.black,
                    size: 16,
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
