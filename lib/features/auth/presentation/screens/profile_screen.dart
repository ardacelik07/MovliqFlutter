import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'settings_screen.dart';
import '../../../../core/services/storage_service.dart';
import 'dart:convert';
import '../../../../features/auth/domain/models/user_data_model.dart';
import '../../../../features/auth/presentation/providers/user_data_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _profileImageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Profil fotoğrafını yükle
    _loadProfileImage();
  }

  // Profil fotoğrafını yükle
  Future<void> _loadProfileImage() async {
    try {
      // Token al
      final tokenJson = await StorageService.getToken();
      if (tokenJson == null) return;

      final Map<String, dynamic> tokenData = jsonDecode(tokenJson);
      final String token = tokenData['token'];

      // API'den kullanıcı bilgilerini al
      final response = await http.get(
        Uri.parse('http://movliq.mehmetalicakir.tr:5000/api/User/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        if (userData != null && userData['profilePictureUrl'] != null) {
          setState(() {
            _profileImageUrl = userData['profilePictureUrl'];
          });
        }
      }
    } catch (e) {
      debugPrint('Profil fotoğrafı yüklenirken hata: $e');
    }
  }

  // Profil fotoğrafı seçme ve yükleme işlemi
  Future<void> _selectAndUploadProfileImage() async {
    try {
      // Fotoğraf kaynağını seçme iletişim kutusu göster
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

      setState(() {
        _isUploading = true;
      });

      // Token al
      final tokenJson = await StorageService.getToken();
      if (tokenJson == null) {
        _showErrorMessage(
            'Oturum bilgisi bulunamadı. Lütfen tekrar giriş yapın.');
        setState(() {
          _isUploading = false;
        });
        return;
      }

      // API'ye fotoğrafı yükle
      final response = await _uploadProfileImage(image.path, tokenJson);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Profil verilerini yenile
        await ref.read(userDataProvider.notifier).fetchUserData();

        _showSuccessMessage('Profil fotoğrafı başarıyla güncellendi');

        // Başarılı olduğunda da _isUploading değişkenini false yap
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      } else {
        _showErrorMessage('Profil fotoğrafı yüklenirken bir hata oluştu');
        setState(() {
          _isUploading = false;
        });
      }
    } catch (e) {
      _showErrorMessage('Hata: $e');
      setState(() {
        _isUploading = false;
      });
    } finally {
      // Herhangi bir hata durumunda veya işlem bittiğinde _isUploading'i false yap
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  // Profil fotoğrafını API'ye yükle
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

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessMessage(String message) {
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
    // Yeni user data provider'ını dinle
    final userDataAsync = ref.watch(userDataProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            stops: [0.0, 1.0],
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 230, 231, 228),
              Color(0xFFC4FF62),
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

              // Veri başarıyla yüklendiyse, yükleme göstergesini kapat
              if (_isUploading) {
                Future.microtask(() {
                  if (mounted) {
                    setState(() {
                      _isUploading = false;
                    });
                  }
                });
              }

              // Provider'dan alınan verilerle UI'ı oluştur
              return SingleChildScrollView(
                child: Column(
                  children: [
                    // Profil Başlığı ve Fotoğraf
                    Stack(
                      children: [
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage(
                                  'assets/images/loginbackground.jpg'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Container(
                          height: 200,
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
                          child: IconButton(
                            icon:
                                const Icon(Icons.settings, color: Colors.white),
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
                        // Profil bilgileri ve fotoğraf
                        Positioned(
                          bottom: 20,
                          left: 20,
                          child: Row(
                            children: [
                              // Profil fotoğrafı
                              GestureDetector(
                                onTap: _selectAndUploadProfileImage,
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                        image:
                                            userData.profilePictureUrl != null
                                                ? DecorationImage(
                                                    image: NetworkImage(userData
                                                        .profilePictureUrl!),
                                                    fit: BoxFit.cover,
                                                  )
                                                : const DecorationImage(
                                                    image: AssetImage(
                                                        'assets/images/runningman.png'),
                                                    fit: BoxFit.cover,
                                                  ),
                                      ),
                                      child: _isUploading
                                          ? Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.black
                                                    .withOpacity(0.5),
                                              ),
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 3,
                                                ),
                                              ),
                                            )
                                          : null,
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
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
                              ),
                              const SizedBox(width: 16),
                              // İsim ve kullanıcı adı
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userData.fullName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '@${userData.userName}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // İstatistikler
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat('1', 'Leaderboard\nRank'),
                          _buildStat('1,458', 'Streak'),
                          _buildStat('32', 'Coin'),
                        ],
                      ),
                    ),

                    // Premium Kart
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade400,
                            Colors.green.shade700
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Upgrade to Premium',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildPremiumFeature(
                              'Advanced performance analytics'),
                          _buildPremiumFeature('Personalized training plans'),
                          _buildPremiumFeature('Priority support access'),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.green,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Get Started'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Rozetler
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Badges',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text('View All'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildBadge(Colors.amber, 'Marathon\nPro'),
                              _buildBadge(Colors.black87, '100km Club'),
                              _buildBadge(Colors.purple, 'Early Bird'),
                              _buildBadge(Colors.green, 'Pace Setter'),
                            ],
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
                            children: [
                              _buildFilterButton('Indoor', true),
                              const SizedBox(width: 8),
                              _buildFilterButton('Outdoor', false),
                              const SizedBox(width: 8),
                              _buildFilterButton('Record', false),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 200,
                            child: LineChart(
                              LineChartData(
                                gridData: const FlGridData(show: true),
                                titlesData: const FlTitlesData(
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: true),
                                  ),
                                ),
                                borderData: FlBorderData(show: true),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: const [
                                      FlSpot(0, 6),
                                      FlSpot(1, 7),
                                      FlSpot(2, 3),
                                      FlSpot(3, 8),
                                      FlSpot(4, 6),
                                      FlSpot(5, 9),
                                      FlSpot(6, 4),
                                    ],
                                    isCurved: true,
                                    color: Colors.green,
                                    barWidth: 3,
                                    dotData: const FlDotData(show: true),
                                  ),
                                ],
                              ),
                            ),
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
                                onPressed: () {},
                                child: const Text('See All'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildRaceItem(
                            date: 'Dec 15, 2023 - 08:30 AM',
                            distance: '21.1km',
                            duration: '1h 45m',
                            place: '1st Place',
                          ),
                          _buildRaceItem(
                            date: 'Dec 10, 2023 - 07:00 AM',
                            distance: '10km',
                            duration: '48m',
                            place: '3rd Place',
                          ),
                          _buildRaceItem(
                            date: 'Dec 3, 2023 - 09:00 AM',
                            distance: '15km',
                            duration: '1h 15m',
                            place: '2nd Place',
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

  Widget _buildPremiumFeature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(Color color, String label) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.emoji_events, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFilterButton(String text, bool isSelected) {
    return Container(
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
    );
  }

  Widget _buildRaceItem({
    required String date,
    required String distance,
    required String duration,
    required String place,
  }) {
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
                    Expanded(
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
                    Text(
                      '$distance • $duration',
                      style: TextStyle(color: Colors.grey[600]),
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
              color: Colors.amber[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events, size: 14, color: Colors.amber[700]),
                const SizedBox(width: 4),
                Text(
                  place,
                  style: TextStyle(
                    color: Colors.amber[700],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}
