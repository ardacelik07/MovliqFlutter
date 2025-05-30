import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/features/auth/presentation/screens/filter_screen2.dart';
import '../providers/race_settings_provider.dart';
import 'verification_screen.dart';
// import 'package:my_flutter_project/features/auth/presentation/screens/private_races_view.dart'; // Commented out or remove
import 'package:my_flutter_project/features/auth/presentation/screens/create_or_join_room_screen.dart'; // Added import
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/permission_widget.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class FilterScreen extends ConsumerStatefulWidget {
  const FilterScreen({super.key});

  @override
  ConsumerState<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends ConsumerState<FilterScreen>
    with WidgetsBindingObserver {
  String? _selectedPreference;
  bool _isOurPermissionDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() => _ensurePermissionUi());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _ensurePermissionUi();
    }
  }

  Future<void> _ensurePermissionUi() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final bool permissionsAlreadyRequestedOnHome =
        prefs.getBool('permissionsRequested') ?? false;

    final statusLocation = await Permission.location.status;
    final PermissionStatus statusActivity;
    if (Platform.isIOS) {
      statusActivity = await Permission.sensors.status;
    } else {
      statusActivity = await Permission.activityRecognition.status;
    }

    bool allPermissionsGranted =
        statusLocation.isGranted && statusActivity.isGranted;

    if (allPermissionsGranted) {
      if (_isOurPermissionDialogShown) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        _isOurPermissionDialogShown = false;
      }
    } else {
      if (!permissionsAlreadyRequestedOnHome || !_isOurPermissionDialogShown) {
        if (!_isOurPermissionDialogShown && mounted) {
          _isOurPermissionDialogShown = true;
          await showDialog(
            context: context,
            builder: (BuildContext dialogContext) => const PermissionWidget(),
            barrierDismissible: false,
          );
          _isOurPermissionDialogShown = false;
          if (mounted) {
            await _ensurePermissionUi();
          }
        }
      } else if (permissionsAlreadyRequestedOnHome && !allPermissionsGranted) {
        if (!_isOurPermissionDialogShown && mounted) {
          _isOurPermissionDialogShown = true;
          await showDialog(
            context: context,
            builder: (BuildContext dialogContext) => const PermissionWidget(),
            barrierDismissible: false,
          );
          _isOurPermissionDialogShown = false;
          if (mounted) {
            await _ensurePermissionUi();
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardHeight = screenWidth * 0.40;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Text(
                  "Koşu Türünü Seç",
                  style: GoogleFonts.bangers(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                _buildOptionCard(
                  titleLines: ["İç Mekan", "Koşusu"],
                  description: "Spor salonu ve kapalı alanlarda koşu",
                  imagePath: "assets/images/manOnRunningInside.png",
                  value: "indoor",
                  isSelected: _selectedPreference == "indoor",
                  cardHeight: cardHeight,
                  onTap: () => setState(() => _selectedPreference = "indoor"),
                ),
                const SizedBox(height: 24),
                _buildOptionCard(
                  titleLines: ["Dış Mekan", "Koşusu"],
                  description: "Park ve açık alanlarda koşu",
                  imagePath: "assets/images/womanRunOutside.png",
                  value: "outdoor",
                  isSelected: _selectedPreference == "outdoor",
                  cardHeight: cardHeight,
                  onTap: () => setState(() => _selectedPreference = "outdoor"),
                ),
                const SizedBox(height: 24),
                _buildOptionCard(
                  titleLines: ["Özel Yarış"],
                  description: "Arkadaşlarınla yarış veya yeni odalar keşfet",
                  imagePath: "assets/images/registerpicture.png",
                  value: "private",
                  isSelected: _selectedPreference == "private",
                  cardHeight: cardHeight,
                  onTap: () => setState(() => _selectedPreference = "private"),
                ),
                const SizedBox(height: 30),
                if (_selectedPreference != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC4FF62),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          ref
                              .read(raceSettingsProvider.notifier)
                              .setRoomType(_selectedPreference!);

                          if (_selectedPreference == 'indoor') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const VerificationScreen(),
                              ),
                            );
                          } else if (_selectedPreference == 'outdoor') {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const FilterScreen2()),
                            );
                          } else if (_selectedPreference == 'private') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const CreateOrJoinRoomScreen(),
                              ),
                            );
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
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required List<String> titleLines,
    required String description,
    required String imagePath,
    required String value,
    required bool isSelected,
    required double cardHeight,
    required VoidCallback onTap,
  }) {
    const Color cardBackgroundColor = Color(0xFF2A2A2A);
    const Color highlightColor = Color(0xFFC4FF62);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: cardHeight,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cardBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          border:
              isSelected ? Border.all(color: highlightColor, width: 2.5) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 15,
              color: highlightColor,
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: 10.0, top: 10.0, bottom: 10.0, right: 30.0),
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.sports_kabaddi,
                              color: Colors.white54, size: 50);
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: titleLines
                          .map((line) => Text(
                                line,
                                textAlign: TextAlign.right,
                                style: GoogleFonts.bangers(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  Positioned(
                    bottom: 15,
                    right: 20,
                    child: Text(
                      description,
                      style: GoogleFonts.bangers(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
