import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:cached_network_image/cached_network_image.dart'; // For network images
import 'package:my_flutter_project/features/auth/domain/models/private_race_model.dart';
import 'dart:convert'; // Import for jsonDecode
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:http/http.dart' as http; // Import http
import 'package:my_flutter_project/core/config/api_config.dart'; // Import ApiConfig
import 'package:my_flutter_project/core/services/storage_service.dart'; // Import StorageService
import 'package:my_flutter_project/features/auth/presentation/screens/waitingRoom_screen.dart'; // Import WaitingRoomScreen

// Remove the old placeholder data model
/*
class RaceDetails { ... }
*/

// Convert to ConsumerStatefulWidget
class PrivateRacesView extends ConsumerStatefulWidget {
  final PrivateRaceModel race;

  const PrivateRacesView({
    super.key,
    required this.race,
  });

  @override
  ConsumerState<PrivateRacesView> createState() => _PrivateRacesViewState();
}

class _PrivateRacesViewState extends ConsumerState<PrivateRacesView> {
  bool _isLoading = false; // Loading state for the button

  Future<void> _joinPrivateRace() async {
    if (_isLoading) return; // Prevent multiple clicks

    setState(() {
      _isLoading = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final tokenData = await StorageService.getToken();
      if (tokenData == null) {
        throw Exception('Authentication token not found.');
      }
      final token = jsonDecode(tokenData)['token'];

      final headers = {
        ...ApiConfig.headers,
        'Authorization': 'Bearer $token',
      };

      // Construct request body from race data
      // Ensure null safety for required fields
      final roomType = widget.race.type;
      final duration = widget.race.duration;
      final privateName = widget.race.specialRaceRoomName;

      if (roomType == null || duration == null || privateName == null) {
        throw Exception('Missing required race details for joining.');
      }

      final body = jsonEncode({
        'roomType': roomType,
        'duration': duration,
        'privateName': privateName,
      });

      final response = await http.post(
        Uri.parse(ApiConfig.matchPrivateRoomEndpoint),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        // Successfully matched/joined the room

        // Navigate to WaitingRoomScreen using the existing race ID
        if (widget.race.id == null) {
          throw Exception('Race ID is null, cannot navigate to waiting room.');
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WaitingRoomScreen(
                roomId: widget.race.id!, // Use the ID of the special race
                startTime: widget.race.startTime,
                activityType: widget.race.type,
                duration: widget.race.duration,
                roomCode: widget.race.specialRaceRoomName ??
                    '', // Added roomCode using race name
                isHost: false, // Assuming user is not a host in this context
              ),
            ),
          );
        }
      } else {
        // Handle API error
        throw Exception(
            'Odaya katılırken hata oluştu: ${response.reasonPhrase}');
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Yarışa katılırken bir hata oluştu: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access widget.race inside build method
    final race = widget.race;

    // Log the received race data

    // Use the passed race data directly
    final DateFormat dateFormat = DateFormat('d MMMM yyyy — HH:mm', 'tr_TR');

    // Placeholder values for data not yet in API response
    const int placeholderParticipantCount = 0; // Or fetch later
    // const int placeholderPrizePool = 0; // Remove placeholder
    // const List<Map<String, dynamic>> placeholderAwards = []; // Remove placeholder
    final List<String> placeholderParticipantImages = [
      'assets/images/movliqonlylogo.png',
      'assets/images/movliqonlylogo.png',
      'assets/images/movliqonlylogo.png',
      'assets/images/movliqonlylogo.png',
    ];
    const int placeholderParticipationBonus = 0; // Or fetch later
    // Calculate remaining time if needed
    final Duration timeRemaining =
        (race.startTime?.isAfter(DateTime.now()) ?? false)
            ? race.startTime!.difference(DateTime.now())
            : Duration.zero;

    // --- Process giftPollList string ---
    List<String> awardsList = [];
    if (race.giftPollList != null && race.giftPollList!.isNotEmpty) {
      // Split the comma-separated string and trim whitespace
      awardsList = race.giftPollList!.split(',').map((e) => e.trim()).toList();
      // Remove empty strings that might result from trailing commas etc.
      awardsList.removeWhere((item) => item.isEmpty);
    }

    // Determine if the join button should be enabled
    final bool isJoinAllowed =
        race.startTime != null && timeRemaining <= const Duration(minutes: 15);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true, // Make body extend behind AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove shadow
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              race.specialRaceRoomName ?? 'Yarış Adı Yok', // Null check
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            Text(
              // Null check for startTime, format if not null
              race.startTime != null
                  ? dateFormat.format(race.startTime!)
                  : 'Tarih Yok',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Image Banner with Tag ---
            Builder(builder: (context) {
              // Use Builder to get context for print
              final imageUrl = race.imagePath ?? '';

              return Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 250,
                      color: Colors.grey[800],
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white54),
                      ),
                    ),
                    errorWidget: (context, url, error) {
                      return Container(
                        height: 250,
                        color: Colors.grey[800],
                        child: const Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: Colors.redAccent)),
                      );
                    },
                  ),
                  // Dark gradient overlay for better text visibility
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top +
                        kToolbarHeight -
                        40, // Align below AppBar content
                    left: 16,
                    // TODO: Determine if race is featured based on API data if available
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC4FF62), // Lime green
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Öne Çıkan', // Keep for now, adjust if API provides this info
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Description ---
                  Text(
                    race.description ?? 'Açıklama bulunamadı.', // Null check
                    style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  ),
                  const SizedBox(height: 20),

                  // --- Info Cards Grid ---
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(), // Disable grid scrolling
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.5, // Adjust aspect ratio
                    children: [
                      _buildInfoCard(Icons.directions_run, 'Yarış Türü',
                          race.type ?? 'Bilinmiyor'), // Null check
                      _buildInfoCard(
                          Icons.emoji_events_outlined,
                          'Ödül Havuzu',
                          // Use giftPoll from model, provide default
                          '${race.giftPoll ?? '0'} mCoin'),
                      _buildInfoCard(
                          Icons.timer_outlined,
                          'Süre',
                          // Null check for duration
                          '${race.duration ?? 0} dakika'),
                      _buildInfoCard(Icons.group_outlined, 'Katılımcı',
                          '$placeholderParticipantCount Kişi'), // Placeholder
                    ],
                  ),
                  const SizedBox(height: 20),

                  // --- Time Remaining ---
                  Text(
                    'Başlangıca kalan süre',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    // Display calculated time or a message based on different conditions
                    race.startTime == null
                        ? 'Başlangıç zamanı yok' // Case 1: No start time
                        : timeRemaining <=
                                Duration
                                    .zero // Use <= to catch potential negative durations
                            ? 'Yarış başladı' // Case 2: Race has started or passed
                            : isJoinAllowed // Case 3: Join is allowed (<= 15 mins)
                                ? 'Yarış 15 dakika içinde başlıyor'
                                : _formatRemainingTime(
                                    timeRemaining), // Case 4: More than 15 mins left
                    style: const TextStyle(
                        color: Color(0xFFC4FF62), // Lime green
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // --- Awards ---
                  Text(
                    'Ödüller',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  // Use processed awardsList or show a message if empty/error
                  awardsList.isEmpty
                      ? const Text('Ödül bilgisi bulunamadı.',
                          style: TextStyle(color: Colors.white70))
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount:
                              awardsList.length, // Use processed list length
                          itemBuilder: (context, index) {
                            final String awardName =
                                awardsList[index]; // Get award name string
                            // Display only the award name
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(
                                awardName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500),
                              ),
                            );
                          },
                        ),
                  // Removed the SizedBox after ListView

                  // --- Participation Status ---
                  const SizedBox(height: 20), // Add space before this section
                ],
              ),
            ),
          ],
        ),
      ),
      // --- Bottom Button ---
      bottomNavigationBar: Builder(
        // Use Builder to ensure context is available if needed
        builder: (context) {
          // Log button state just before building

          return Padding(
            padding: const EdgeInsets.all(16.0),
            // Restore original ElevatedButton code
            child: ElevatedButton(
              onPressed:
                  (_isLoading || !isJoinAllowed) ? null : _joinPrivateRace,
              style: ElevatedButton.styleFrom(
                // Explicitly define styles for enabled and disabled states
                backgroundColor: const Color(0xFFC4FF62),
                foregroundColor: Colors.black,
                disabledBackgroundColor: const Color(0xFFC4FF62)
                    .withOpacity(0.5), // Lighter green when disabled
                disabledForegroundColor: Colors.black
                    .withOpacity(0.7), // Slightly faded text when disabled
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                splashFactory: (_isLoading || !isJoinAllowed)
                    ? NoSplash.splashFactory
                    : null,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Yarışa Katıl',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            /* Remove temporary Container test code
            child: Container(
              height: 50,
              color: Colors.red, // Make it visible
              child: const Center(child: Text('Test Bottom Nav')),
            ),*/
          );
        },
      ),
    );
  }

  // Helper function to format remaining time
  String _formatRemainingTime(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);

    List<String> parts = [];
    if (days > 0) {
      parts.add('$days Gün');
    }
    if (hours > 0) {
      parts.add('$hours Saat');
    }
    // Always show minutes if time is left, even if 0?
    // Or only if > 0? Let's show if > 0 or if it's the only unit left.
    if (minutes > 0 || (days == 0 && hours == 0)) {
      parts.add('$minutes Dakika');
    }

    return parts.isNotEmpty
        ? parts.join(' ')
        : 'Başlıyor'; // Handle case where less than a minute is left
  }

  // Helper widget for info cards (no change needed here)
  Widget _buildInfoCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFC4FF62), size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
