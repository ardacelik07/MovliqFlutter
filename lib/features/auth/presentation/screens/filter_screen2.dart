import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:my_flutter_project/features/auth/presentation/screens/waitingRoom_screen.dart';
import '../providers/race_settings_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/error_display_widget.dart';
import 'package:my_flutter_project/features/auth/presentation/widgets/font_widget.dart';

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FontWidget(
                text: "Yarış Özelliklerini Belirle",
                styleType: TextStyleType.titleLarge,
                color: Colors.white,
                // Original style: GoogleFonts.bangers(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)
              ),
              const SizedBox(height: 8),
              FontWidget(
                text: "Ne kadar süre ve hangi modda koşmak istersin?",
                styleType: TextStyleType.bodyMedium,
                color: Colors.grey,
                // Original style: GoogleFonts.bangers(fontSize: 14, color: Colors.grey)
              ),
              const SizedBox(height: 32),
              _buildDurationCard(
                duration: "1",
                value: 'beginner',
                isPopular: false,
              ),
              const SizedBox(height: 16),
              _buildDurationCard(
                duration: "5",
                value: 'intermediate',
                isPopular: false,
              ),
              const SizedBox(height: 16),
              _buildDurationCard(
                duration: "10",
                value: 'preintermediate',
                isPopular: true,
              ),
              const SizedBox(height: 16),
              _buildDurationCard(
                duration: "20",
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
                                        ? 'Dış Mekan'
                                        : 'İç Mekan';

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
                                  SnackBar(
                                    content: ErrorDisplayWidget(errorObject: e),
                                  ),
                                );

                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            },
                            child: Text(
                              'Devam',
                              style: GoogleFonts.bangers(
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
          color: const Color(0xFF2A2A2A),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Left side - Duration
                  Text(
                    duration,
                    style: GoogleFonts.bangers(
                      color: Color(0xFFC4FF62),
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Middle - dakika & description

                  Text(
                    "dakİka",
                    style: GoogleFonts.bangers(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Right side - Running icon
                ],
              ),
            ),
            if (isPopular)
              Positioned(
                right: 12,
                bottom: 36,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC4FF62).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Popüler",
                    style: GoogleFonts.bangers(
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
