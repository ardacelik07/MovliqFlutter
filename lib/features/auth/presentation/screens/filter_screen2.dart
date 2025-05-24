import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/features/auth/presentation/screens/filter_screen.dart';

import 'package:my_flutter_project/features/auth/presentation/screens/waitingRoom_screen.dart';
import '../providers/race_settings_provider.dart';

class FilterScreen2 extends ConsumerStatefulWidget {
  const FilterScreen2({super.key});

  @override
  ConsumerState<FilterScreen2> createState() => __FilterScreen2State();
}

class __FilterScreen2State extends ConsumerState<FilterScreen2> {
  String? _selectedLevel;
  bool _isLoading = false;

  // Duration value map - updated to match the UI in the image
  final Map<String, int> _durationMap = {
    'beginner': 1,
    'intermediate': 5,
    'preintermediate': 10,
    'advanced': 20,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => FilterScreen()),
                            );
                          }),
                      const SizedBox(width: 8),
                      const Text(
                        "Koşu Süresi",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context); // Or replace with desired action
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                "Hedef sürenizi seçin",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              _buildDurationCard(
                duration: "1",
                description: "Hızlı antrenman",
                value: 'beginner',
                isPopular: false,
              ),
              const SizedBox(height: 16),
              _buildDurationCard(
                duration: "5",
                description: "Orta seviye antrenman",
                value: 'intermediate',
                isPopular: false,
              ),
              const SizedBox(height: 16),
              _buildDurationCard(
                duration: "10",
                description: "Orta seviye antrenman",
                value: 'preintermediate',
                isPopular: true,
              ),
              const SizedBox(height: 16),
              _buildDurationCard(
                duration: "20",
                description: "Uzun antrenman",
                value: 'advanced',
                isPopular: false,
              ),
              const Spacer(),
              if (_selectedLevel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFFC4FF62)))
                        : ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC4FF62),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () async {
                              try {
                                setState(() {
                                  _isLoading = true;
                                });

                                // Seçilen süreyi provider'a kaydet
                                final duration =
                                    _durationMap[_selectedLevel!] ?? 10;
                                ref
                                    .read(raceSettingsProvider.notifier)
                                    .setDuration(duration);

                                // Tüm seçimleri al ve API'ye gönder
                                final settings = ref.read(raceSettingsProvider);
                                if (!settings.isComplete) {
                                  throw Exception(
                                      'Please complete all selections');
                                }

                                final request = settings.toRequest();
                                final result = await ref
                                    .read(raceJoinProvider(request).future);

                                // API cevabını işle
                                if (!mounted) return;

                                // Get formatted display values for the selections
                                final roomType = settings.roomType ?? 'outdoor';
                                final activityType =
                                    roomType.toLowerCase() == 'outdoor'
                                        ? 'Outdoor Koşu'
                                        : 'Indoor Koşu';

                                // WaitingRoom'a yönlendir ve oda bilgilerini aktar
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => WaitingRoomScreen(
                                      roomId: result['roomId'],
                                      startTime: result['startTime'] != null
                                          ? DateTime.parse(result['startTime'])
                                          : null,
                                      activityType: activityType,
                                      duration: duration,
                                      roomCode: '',
                                      isHost: false,
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );

                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            },
                            child: const Text(
                              'Devam',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationCard({
    required String duration,
    required String description,
    required String value,
    required bool isPopular,
  }) {
    final bool isSelected = _selectedLevel == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLevel = value;
        });
      },
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1F2922),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: const Color(0xFFC4FF62), width: 2.5)
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left side - Duration
                  Text(
                    duration,
                    style: const TextStyle(
                      color: Color(0xFFC4FF62),
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Middle - dakika & description
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "dakika",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Right side - Running icon
                  const Icon(
                    Icons.directions_run,
                    color: Color(0xFFC4FF62),
                    size: 24,
                  ),
                ],
              ),
            ),
            if (isPopular)
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC4FF62).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "Popüler",
                    style: TextStyle(
                      color: Color(0xFFC4FF62),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
