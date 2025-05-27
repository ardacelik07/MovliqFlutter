import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/signalr_service.dart';
import '../screens/tabs.dart';
import 'dart:math' as math;
import '../widgets/user_profile_avatar.dart';

import '../providers/race_coin_tracker_provider.dart';

// Define colors from the image design
const Color _screenBackground = Color(0xFF121212);
const Color _cardBackground = Color(0xFF2A2A2A);
const Color _primaryText = Colors.white;
const Color _secondaryText =
    Color(0xFFB0B0B0); // Lighter grey for subtitles/secondary info
const Color _accentGreen =
    Color(0xFFC4FF62); // Bright green for button and highlights
const Color _goldColor = Color(0xFFFFD700);
const Color _silverColor = Color(0xFFC0C0C0);
const Color _bronzeColor = Color(0xFFCD7F32);
const Color _currentUserLeaderboardHighlightBorder =
    Color(0xFF66BB6A); // Green border for current user in leaderboard

// Asset Paths (User needs to replace these with actual paths)
const String _finishFlagAsset =
    'assets/icons/bayrak.png'; // TODO: REPLACE WITH YOUR ASSET PATH
const String _newConfettiIconAsset =
    'assets/icons/konfeti.png'; // Added new confetti icon asset
const String _rankCupAsset =
    'assets/icons/coupa.png'; // TODO: REPLACE WITH YOUR ASSET PATH
const String _locationPinAsset =
    'assets/icons/location.png'; // TODO: REPLACE WITH YOUR ASSET PATH
const String _stepsShoeAsset =
    'assets/icons/steps.png'; // TODO: REPLACE WITH YOUR ASSET PATH
const String _rank1BadgeAsset =
    'assets/icons/1.png'; // TODO: REPLACE WITH YOUR ASSET PATH
const String _rank2BadgeAsset =
    'assets/icons/2.png'; // TODO: REPLACE WITH YOUR ASSET PATH
const String _rank3BadgeAsset =
    'assets/icons/3.png'; // TODO: REPLACE WITH YOUR ASSET PATH

class FinishRaceScreen extends ConsumerStatefulWidget {
  final List<RaceParticipant> leaderboard;
  final String? myEmail;
  final bool isIndoorRace; // Indoor yarış tipini belirten parametre ekledik
  final Map<String, String?> profilePictureCache;

  const FinishRaceScreen({
    super.key,
    required this.leaderboard,
    this.myEmail,
    required this.isIndoorRace, // Constructor'a ekledik
    required this.profilePictureCache,
  });

  @override
  ConsumerState<FinishRaceScreen> createState() => _FinishRaceScreenState();
}

class _FinishRaceScreenState extends ConsumerState<FinishRaceScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure coins are fetched if this logic is still relevant
    // ref.read(userDataProvider.notifier).fetchCoins(); // Original line, keep if needed
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Mevcut kullanıcıyı tespit eden yardımcı metod
  RaceParticipant? _getCurrentUser() {
    if (widget.myEmail == null || widget.leaderboard.isEmpty) return null;

    try {
      return widget.leaderboard.firstWhere(
        (user) => user.email == widget.myEmail,
        // If not found, try to return the first user if their rank suggests they participated.
        // This orElse behavior might need adjustment based on game logic.
        orElse: () => widget.leaderboard.first.rank > 0
            ? widget.leaderboard.first
            : throw Exception("User not found and no fallback"),
      );
    } catch (e) {
      // If leaderboard is not empty but user not found, and no valid fallback
      // return null or the first participant if it makes sense.
      // For now, returning null if specific user not found.
      return widget.leaderboard.isNotEmpty && widget.leaderboard.first.rank > 0
          ? widget.leaderboard.first
          : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _getCurrentUser();
    // final bool isWinner = currentUser?.rank == 1; // This was original, can be used if needed

    // Sort leaderboard by rank for display, handling rank 0 (did not finish/error)
    final List<RaceParticipant> sortedLeaderboard =
        List.from(widget.leaderboard);
    sortedLeaderboard.sort((a, b) {
      if (a.rank == 0 && b.rank == 0) return 0;
      if (a.rank == 0) return 1; // move rank 0 to end
      if (b.rank == 0) return -1; // move rank 0 to end
      return a.rank.compareTo(b.rank);
    });

    return WillPopScope(
      onWillPop: () async {
        _navigateToHomePage();
        return false;
      },
      child: Scaffold(
        backgroundColor: _screenBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: _primaryText, size: 28),
            onPressed: _navigateToHomePage,
          ),
          automaticallyImplyLeading: false,
        ),
        body: Stack(
          alignment: Alignment.topCenter,
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10), // Space below AppBar

                    // Header: Title and Subtitle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(_finishFlagAsset,
                            width: 36,
                            height: 36,
                            errorBuilder: (c, e, s) => const Icon(
                                Icons.flag_rounded,
                                color: _primaryText,
                                size: 36)),
                        const SizedBox(width: 12),
                        const Text(
                          'Yarış Sona Erdi!',
                          style: TextStyle(
                            fontSize: 30, // As per image
                            fontWeight: FontWeight.bold,
                            color: _primaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (currentUser != null && currentUser.rank > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            // Ensures text wraps and centers if very long
                            child: Text(
                              'Yarışı ${currentUser.rank}. sırada tamamladınız!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 24, // As per image
                                color: _accentGreen, // Green text as per image
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // Space before new icon
                          Image.asset(
                            _newConfettiIconAsset, // Use the new confetti icon
                            width: 48,
                            height: 48,
                            errorBuilder: (c, e, s) =>
                                const SizedBox.shrink(), // Hide if asset fails
                          ),
                        ],
                      )
                    else
                      const Text(
                        'Yarış tamamlandı!', // Fallback if rank is not available
                        style: TextStyle(fontSize: 17, color: _secondaryText),
                      ),
                    const SizedBox(height: 24),

                    // User's Personal Stats Card
                    if (currentUser != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 20.0, horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: _cardBackground,
                          borderRadius:
                              BorderRadius.circular(20), // More rounded
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildUserStatItem(
                              assetPath: _rankCupAsset,
                              value: currentUser.rank > 0
                                  ? '${currentUser.rank}.'
                                  : '-',
                              label: 'Sıralama',
                            ),
                            if (!widget
                                .isIndoorRace) // Only show Km for outdoor races
                              _buildUserStatItem(
                                assetPath: _locationPinAsset,
                                value: currentUser.distance.toStringAsFixed(2),
                                label: 'Km',
                              ),
                            _buildUserStatItem(
                              assetPath: _stepsShoeAsset,
                              value: currentUser.steps.toString(),
                              label: 'Adım',
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 30),

                    // Leaderboard Title
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Liderlik Tablosu',
                        style: TextStyle(
                          fontSize: 22, // As per image
                          fontWeight: FontWeight.bold,
                          color: _primaryText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Leaderboard List
                    Expanded(
                      child: sortedLeaderboard.isEmpty
                          ? const Center(
                              child: Text('Liderlik tablosu yüklenemedi.',
                                  style: TextStyle(color: _secondaryText)))
                          : ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: math.min(sortedLeaderboard.length,
                                  10), // Show top N or all
                              itemBuilder: (context, index) {
                                final user = sortedLeaderboard[index];
                                final bool isCurrentUserTile =
                                    user.email == widget.myEmail;
                                return _buildLeaderboardItem(
                                  user,
                                  isCurrentUserTile,
                                  widget.isIndoorRace,
                                  widget.profilePictureCache[
                                      user.userName], // Pass avatar URL
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 10), // Space before button
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding:
              const EdgeInsets.fromLTRB(20, 10, 20, 20), // Adjusted padding
          child: ElevatedButton(
            onPressed: _navigateToHomePage,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentGreen,
              foregroundColor: Colors.black,
              minimumSize:
                  const Size(double.infinity, 55), // As per image style
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16), // More rounded
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'Ana Sayfaya Dön',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  // Helper widget for User's Stat Item in the summary card
  Widget _buildUserStatItem({
    required String assetPath,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(assetPath,
            width: 48,
            height: 48, // Adjust size as needed
            errorBuilder: (c, e, s) =>
                Icon(Icons.error, color: _accentGreen, size: 40)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20, // As per image
            fontWeight: FontWeight.bold,
            color: _primaryText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14, // As per image
            color: _secondaryText,
          ),
        ),
      ],
    );
  }

  // Helper widget for Leaderboard Item
  Widget _buildLeaderboardItem(RaceParticipant user, bool isCurrentUser,
      bool isIndoor, String? avatarUrl) {
    Widget rankBadge;
    switch (user.rank) {
      case 1:
        rankBadge = Image.asset(_rank1BadgeAsset,
            width: 36,
            height: 36,
            errorBuilder: (c, e, s) => _defaultRankCircle(1, _goldColor));
        break;
      case 2:
        rankBadge = Image.asset(_rank2BadgeAsset,
            width: 36,
            height: 36,
            errorBuilder: (c, e, s) => _defaultRankCircle(2, _silverColor));
        break;
      case 3:
        rankBadge = Image.asset(_rank3BadgeAsset,
            width: 36,
            height: 36,
            errorBuilder: (c, e, s) => _defaultRankCircle(3, _bronzeColor));
        break;
      default:
        rankBadge = _defaultRankCircle(
            user.rank, _secondaryText); // Fallback for other ranks
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10), // Adjusted padding
      decoration: BoxDecoration(
        color: _cardBackground, // Darker card background
        borderRadius: BorderRadius.circular(16),
        border: isCurrentUser
            ? Border.all(
                color: _currentUserLeaderboardHighlightBorder, width: 2)
            : null,
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              UserProfileAvatar(
                imageUrl: avatarUrl,
                radius: 24, // Slightly smaller avatar
              ),
              Positioned(
                top: -8, // Adjust to overlap correctly
                left: -8, // Adjust to overlap correctly
                child: rankBadge,
              ),
            ],
          ),
          const SizedBox(
              width: 28), // Increased space to account for badge overlap
          Expanded(
            child: Text(
              '@${user.userName}', // Displaying @username as per image
              style: const TextStyle(
                fontWeight: FontWeight.w600, // Bolder
                fontSize: 16,
                color: _primaryText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isIndoor)
                Text(
                  '${user.distance.toStringAsFixed(2)} km',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _primaryText,
                  ),
                ),
              Text(
                '${user.steps} adım',
                style: TextStyle(
                  fontSize: isIndoor ? 14 : 12, // Adjust size
                  fontWeight: isIndoor ? FontWeight.w500 : FontWeight.normal,
                  color: isIndoor ? _primaryText : _secondaryText,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // Helper for default rank circle if badge asset fails or for ranks > 3
  Widget _defaultRankCircle(int rank, Color color) {
    if (rank == 0) return const SizedBox(width: 36); // No badge for rank 0
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
          color: color.withOpacity(0.7),
          shape: BoxShape.circle,
          border: Border.all(color: _cardBackground, width: 2)),
      child: Center(
        child: Text(
          rank.toString(),
          style: const TextStyle(
            color: _primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  void _navigateToHomePage() {
    ref.read(raceCoinTrackingProvider.notifier).markRaceAsFinished();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const TabsScreen()),
      (route) => false,
    );
  }
}
