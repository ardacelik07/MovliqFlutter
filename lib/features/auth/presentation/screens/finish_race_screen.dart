import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/signalr_service.dart';
import '../screens/tabs.dart';
import 'dart:math' as math;

class FinishRaceScreen extends ConsumerStatefulWidget {
  final List<RaceParticipant> leaderboard;
  final String? myEmail;
  final bool isIndoorRace; // Indoor yarış tipini belirten parametre ekledik

  const FinishRaceScreen({
    super.key,
    required this.leaderboard,
    this.myEmail,
    required this.isIndoorRace, // Constructor'a ekledik
  });

  @override
  ConsumerState<FinishRaceScreen> createState() => _FinishRaceScreenState();
}

class _FinishRaceScreenState extends ConsumerState<FinishRaceScreen> {
  @override
  void initState() {
    super.initState();
  }

  // Mevcut kullanıcıyı tespit eden yardımcı metod
  RaceParticipant? _getCurrentUser() {
    if (widget.myEmail == null) return null;

    try {
      return widget.leaderboard.firstWhere(
        (user) => user.email == widget.myEmail,
        orElse: () => widget.leaderboard.first,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kullanıcının kendi sonucunu bul
    final currentUser = _getCurrentUser();
    final bool isWinner = currentUser?.rank == 1;

    return WillPopScope(
      onWillPop: () async {
        _navigateToHomePage();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E), // Dark background
        body: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              color: const Color(0xFF1E1E1E), // Dark background
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 40), // Increased top spacing
                    // Başlık
                    const Text(
                      'Yarış Sona Erdi!',
                      style: TextStyle(
                        fontSize: 28, // Keep size
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // White text
                      ),
                    ),
                    const SizedBox(height: 8), // Adjust spacing
                    // Alt başlık
                    if (currentUser != null)
                      Text(
                        // Use the rank in the subtitle as per image
                        'Yarışı ${currentUser.rank}. sırada bitirdiniz.',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey, // Grey text
                        ),
                      ),
                    const SizedBox(height: 30), // Increased spacing

                    // Kullanıcının kendi sonuçları - Updated Card
                    if (currentUser != null)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800, // Darker card color
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          // Use Row directly
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildResultItem(
                              icon:
                                  Icons.emoji_events_outlined, // Outlined icon
                              value: currentUser.rank.toString(),
                              label: 'Sıralama', // Turkish label
                              iconColor: Colors.amber, // Amber color for rank
                            ),
                            // Indoor yarışta mesafe gösterme
                            if (!widget.isIndoorRace)
                              _buildResultItem(
                                icon: Icons
                                    .directions_run_outlined, // Outlined icon
                                value: currentUser.distance.toStringAsFixed(2),
                                label: 'Mesafe (km)', // Turkish label
                                iconColor: Colors
                                    .blueAccent, // Blue color for distance
                              ),
                            _buildResultItem(
                              icon: Icons
                                  .directions_walk_outlined, // Outlined icon
                              value: currentUser.steps.toString(),
                              label: 'Adım', // Turkish label
                              iconColor:
                                  Colors.greenAccent, // Green color for steps
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 30), // Increased spacing

                    // Liderlik Tablosu Title
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Liderlik Tablosu', // Turkish Title
                          style: TextStyle(
                            fontSize: 20, // Adjusted size
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // White text
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15), // Adjusted spacing

                    // Liderlik Tablosu List - Updated List
                    Expanded(
                      // Remove outer container styling
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16), // Padding for list
                        itemCount: widget.leaderboard.length,
                        itemBuilder: (context, index) {
                          final user = widget.leaderboard[index];
                          final isCurrentUser = user.email == widget.myEmail;

                          // Use ParticipantTile style from RaceScreen but adapt for finish screen
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12.0, horizontal: 16.0),
                            decoration: BoxDecoration(
                              // Highlight current user's tile slightly differently
                              color: isCurrentUser
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade800,
                              borderRadius: BorderRadius.circular(12),
                              // No special border needed here based on image
                            ),
                            child: Row(
                              children: [
                                // Rank Badge and Avatar (Similar to RaceScreen's ParticipantTile)
                                _buildRankAvatar(user),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.userName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Simplified distance/steps text
                                      Text(
                                        // Combine distance (if applicable) and steps
                                        widget.isIndoorRace
                                            ? '${user.steps} adım'
                                            : '${user.distance.toStringAsFixed(2)} km   ${user.steps} adım',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors
                                              .grey, // Grey text for stats
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    // Ana Sayfaya Dön Butonu - Updated Button Style
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          16, 16, 16, 24), // Adjusted padding
                      child: ElevatedButton(
                        onPressed: _navigateToHomePage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFC4FF62), // Light green bg
                          foregroundColor: Colors.black, // Black text/icon
                          minimumSize: const Size(
                              double.infinity, 50), // Full width, fixed height
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12), // Rounded corners
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.home_outlined), // Outlined icon
                            SizedBox(width: 8),
                            Text('Ana Sayfaya Dön',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor, // Use iconColor for consistency
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 28, color: iconColor),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white, // White text for value
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey, // Grey text for label
          ),
        ),
      ],
    );
  }

  Widget _buildRankAvatar(RaceParticipant participant) {
    Color rankColor;
    Color rankTextColor = Colors.black87;
    if (participant.rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankTextColor = Colors.black;
    } else if (participant.rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankTextColor = Colors.black;
    } else if (participant.rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankTextColor = Colors.white;
    } else {
      rankColor = Colors.grey.shade600; // Darker grey for others
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey.shade700,
          // TODO: Add profile picture logic here if available
          // backgroundImage: profilePictureUrl != null
          //     ? NetworkImage(profilePictureUrl!)
          //     : null,
          child: /* profilePictureUrl == null ? */ Text(
            participant.userName.isNotEmpty
                ? participant.userName[0].toUpperCase()
                : '?',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ) /* : null */,
        ),
        Positioned(
          top: -4,
          left: -4,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: rankColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade800, width: 2),
            ),
            child: Center(
              child: Text(
                participant.rank.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: rankTextColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToHomePage() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const TabsScreen()),
      (route) => false,
    );
  }
}
