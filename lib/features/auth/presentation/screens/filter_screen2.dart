import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  // Duration value map
  final Map<String, int> _durationMap = {
    'beginner': 1,
    'intermediate': 20,
    'advanced': 30,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Image.asset(
                'assets/images/runningclock.png',
                height: 200,
              ),
              const SizedBox(height: 40),
              const Text(
                "How many minutes you would like to run?",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildActivityOption(
                '1',
                'Just getting started',
                Icons.directions_walk,
                'beginner',
              ),
              const SizedBox(height: 16),
              _buildActivityOption(
                '20',
                'Regular exercise',
                Icons.favorite,
                'intermediate',
              ),
              const SizedBox(height: 16),
              _buildActivityOption(
                '30',
                'Consistent training',
                Icons.fitness_center,
                'advanced',
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC4FF62),
                        foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _selectedLevel != null
                          ? () async {
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

                                // WaitingRoom'a yönlendir ve oda bilgilerini aktar
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => WaitingRoomScreen(
                                      roomId: result['roomId'],
                                      startTime: result['startTime'] != null
                                          ? DateTime.parse(result['startTime'])
                                          : null,
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
                            }
                          : null,
                      child: const Text('Next'),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityOption(
    String title,
    String subtitle,
    IconData icon,
    String value,
  ) {
    final isSelected = _selectedLevel == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedLevel = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC4FF62) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.black : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.black : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? Colors.black : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.black,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
