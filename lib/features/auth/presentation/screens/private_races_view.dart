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
        print('Successfully joined private race room via API.');

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
              ),
            ),
          );
        }
      } else {
        // Handle API error
        print(
            'Failed to join private race room: ${response.statusCode} - ${response.body}');
        throw Exception(
            'Odaya katılırken hata oluştu: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error joining private race: $e');
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
    print('🎁 Race Data Received:');
    print('  giftPoll: ${race.giftPoll}');
    print('  giftPollList: ${race.giftPollList}');

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
              print('🖼️ Loading image from URL: $imageUrl'); // Print the URL
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
                      print(
                          "Error loading race image: $imageUrl, Error: $error"); // Null check
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
                    // Display calculated time or a message if start time is null/past
                    race.startTime == null
                        ? 'Başlangıç zamanı yok'
                        : timeRemaining == Duration.zero
                            ? 'Yarış başladı'
                            : '${timeRemaining.inDays} Gün ${timeRemaining.inHours.remainder(24)} Saat',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Katılım Durumu',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                      Text(
                        '$placeholderParticipantCount Kişi', // Placeholder
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Overlapping Avatars (Placeholder)
                      SizedBox(
                        height: 30,
                        width: 100, // Adjust width based on overlap and count
                        child: Stack(
                          children: List.generate(
                            placeholderParticipantImages.length,
                            (i) => Positioned(
                              left: i * 18.0, // Adjust overlap
                              child: CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.grey[700],
                                backgroundImage:
                                    AssetImage(placeholderParticipantImages[i]),
                                // Add border
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.black, width: 1.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        // Use Expanded to prevent overflow
                        child: Text(
                          // Adjust text based on placeholder count
                          placeholderParticipantCount >
                                  placeholderParticipantImages.length
                              ? 've ${placeholderParticipantCount - placeholderParticipantImages.length} kişi daha katılıyor'
                              : 'kişi katılıyor', // Or hide if count is 0
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 12),
                          overflow: TextOverflow.ellipsis, // Handle overflow
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/mCoin.png',
                        width: 18,
                        height: 18,
                        color: const Color(0xFFC4FF62), // Tint icon
                      ),
                      const SizedBox(width: 8),
                      Text(
                        // Placeholder
                        'Her katılımcıya $placeholderParticipationBonus mCoin',
                        style: const TextStyle(
                            color: Color(0xFFC4FF62), // Lime green
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // --- Bottom Button ---
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          // Call the join function on press
          onPressed: _isLoading ? null : _joinPrivateRace,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC4FF62), // Lime green
            foregroundColor: Colors.black, // Text color
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            // Disable splash effect when loading
            splashFactory: _isLoading ? NoSplash.splashFactory : null,
          ),
          // Show indicator when loading
          child: _isLoading
              ? const SizedBox(
                  height: 20, // Consistent height
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.black,
                  ),
                )
              : const Text(
                  'Yarışa Katıl',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
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
