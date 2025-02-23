import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_page.dart';

import '../providers/user_profile_provider.dart';

class FinishScreen extends ConsumerStatefulWidget {
  const FinishScreen({super.key});

  @override
  ConsumerState<FinishScreen> createState() => _FinishScreenState();
}

class _FinishScreenState extends ConsumerState<FinishScreen> {
  String? _selectedPreference;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Provider'ı dinle
    ref.listen(userProfileProvider, (previous, next) {
      next.whenOrNull(
        loading: () {
          setState(() => _isLoading = true);
        },
        error: (error, stack) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${error.toString()}')),
          );
        },
        data: (_) {
          setState(() => _isLoading = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        },
      );
    });

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
                'assets/images/finish.jpg',
                height: 300,
              ),
              const SizedBox(height: 40),
              const Text(
                "Where do you prefer to run?",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: _buildPreferenceOption(
                      'Outdoors',
                      Icons.landscape_outlined,
                      'outdoors',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPreferenceOption(
                      'Gym',
                      Icons.fitness_center_outlined,
                      'gym',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isLoading || _selectedPreference == null
                    ? null
                    : _handleComplete,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Complete'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferenceOption(
    String title,
    IconData icon,
    String value,
  ) {
    final isSelected = _selectedPreference == value;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPreference = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.blue : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleComplete() async {
    try {
      // Önce mevcut state'i kontrol et
      final currentProfile = ref.read(userProfileProvider).value;
      if (currentProfile == null) {
        throw Exception('Profile data is missing');
      }

      // Eksik zorunlu alanları kontrol et
      if (currentProfile.name.isEmpty ||
          currentProfile.username.isEmpty ||
          currentProfile.gender.isEmpty ||
          currentProfile.height <= 0 ||
          currentProfile.weight <= 0 ||
          currentProfile.activityLevel.isEmpty) {
        throw Exception('Please complete all required fields');
      }

      // Son tercihi güncelle
      ref.read(userProfileProvider.notifier).updateProfile(
            runningPreference: _selectedPreference,
          );

      // Profili kaydet
      await ref.read(userProfileProvider.notifier).saveProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
}
