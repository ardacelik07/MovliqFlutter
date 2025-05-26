import 'dart:async'; // For TimeoutException
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/core/services/signalr_service.dart'; // For RaceParticipant
import 'package:my_flutter_project/features/auth/presentation/widgets/user_profile_avatar.dart';
import 'package:video_player/video_player.dart';

// --- Participant Marker Widget ---
class _ParticipantMarkerWidget extends StatelessWidget {
  final RaceParticipant participant;
  final String? profilePicUrl;
  final bool isMe;
  final String rankAsset;

  const _ParticipantMarkerWidget({
    required this.participant,
    this.profilePicUrl,
    required this.isMe,
    required this.rankAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color:
            Colors.black.withOpacity(0.7), // Slightly more prominent background
        borderRadius: BorderRadius.circular(12),
        border: isMe
            ? Border.all(color: const Color(0xFFC4FF62), width: 2.5)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomLeft,
            children: [
              UserProfileAvatar(
                  imageUrl: profilePicUrl,
                  radius: 24), // Avatar slightly larger
              if (rankAsset.isNotEmpty && participant.rank <= 3)
                Positioned(
                  left: -6,
                  bottom: -6,
                  child: Image.asset(rankAsset,
                      width: 22, height: 22), // Rank icon slightly larger
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            participant.userName,
            style: TextStyle(
                color: Colors.white,
                fontSize: 13, // Font size slightly larger
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                shadows: const [
                  Shadow(
                      blurRadius: 1.0,
                      color: Colors.black54,
                      offset: Offset(1, 1))
                ]),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            '${participant.distance.toStringAsFixed(1)}km - ${participant.steps} steps',
            style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 10,
                shadows: const [
                  Shadow(
                      blurRadius: 1.0,
                      color: Colors.black54,
                      offset: Offset(1, 1))
                ]),
          ),
        ],
      ),
    );
  }
}
// --- End of Participant Marker Widget ---

class RaceUIWidget extends ConsumerStatefulWidget {
  final List<RaceParticipant> participants;
  final String? myEmail;
  final Map<String, String?> profilePictureCache;
  final bool isIndoorRace;
  final Duration remainingTime;

  const RaceUIWidget({
    super.key,
    required this.participants,
    required this.myEmail,
    required this.profilePictureCache,
    required this.isIndoorRace,
    required this.remainingTime,
  });

  @override
  ConsumerState<RaceUIWidget> createState() => _RaceUIWidgetState();
}

class _RaceUIWidgetState extends ConsumerState<RaceUIWidget> {
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoPlayerFuture;

  // --- Perspective and Layout Constants ---
  final double _unscaledMarkerHeight =
      100.0; // Base height of the marker widget
  final double _bottomScreenPadding = 10.0;

  // Y-axis perspective: where the "finish line" and "start line" appear
  final double _yFinishLineRatio =
      0.25; // Furthest point (top of screen, e.g., 25%)
  final double _yStartLineRatio =
      0.90; // Closest point (bottom of screen, e.g., 90%)

  // X-axis perspective: track width ratios
  final double _xTrackCenterRatio =
      0.5; // Center of the track (50% of screen width)
  final double _trackWidthAtFinishRatio =
      0.3; // Track width at the finish line (e.g., 30% of screen width)
  final double _trackWidthAtStartRatio =
      0.95; // Track width at the start line (e.g., 95% of screen width)

  // Scaling perspective: how much smaller/larger participants appear based on depth
  final double _minScale = 0.55; // Scale for rank 1 (furthest)
  final double _maxScale = 1.0; // Scale for last rank (closest)
  // --- End of Perspective Constants ---

  @override
  void initState() {
    super.initState();
    _videoController =
        VideoPlayerController.asset('assets/images/racevideo.mp4');
    _initializeVideoPlayerFuture = _videoController!
        .initialize()
        .timeout(const Duration(seconds: 10), onTimeout: () {
      // This will be caught by catchError
      throw TimeoutException(
          'Video player initialization timed out after 10 seconds');
    }).then((_) {
      if (!mounted) return;
      _videoController!.setLooping(true);
      _videoController!.play();
      if (mounted) {
        setState(() {});
      }
    }).catchError((error, stackTrace) {
      // Using print for debugging, consider a proper logger for production
      print("Video player initialization error: $error");
      print("Video player stackTrace: $stackTrace");
      if (mounted) {
        setState(() {
          // The FutureBuilder will handle displaying the error UI
        });
      }
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  String _getRankAsset(int rank) {
    if (rank == 1) return 'assets/icons/1.png';
    if (rank == 2) return 'assets/icons/2.png';
    if (rank == 3) return 'assets/icons/3.png';
    return '';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Offset _getParticipantPosition(
      int rank, int totalParticipants, Size screenSize, double scale) {
    double participantRank = rank.toDouble();
    // Normalized rank (0.0 for rank 1, 1.0 for last rank)
    // If totalParticipants is 1, normalizedRank is 0.0.
    double normalizedRankFactor = totalParticipants > 1
        ? (participantRank - 1) / (totalParticipants - 1)
        : 0.0;

    // Y POSITION (DEPTH)
    // Higher rank (1st) is further up (closer to yFinishLineRatio * screenHeight)
    // Lower rank (last) is further down (closer to yStartLineRatio * screenHeight)
    double yPos = (screenSize.height * _yFinishLineRatio) +
        (normalizedRankFactor *
            (screenSize.height * (_yStartLineRatio - _yFinishLineRatio)));

    // X POSITION (LANES & PERSPECTIVE)
    double markerVisualWidthEstimate = 90 * scale; // Approximate visual width

    // Track width narrows in the distance.
    // Calculate current track width based on the participant's depth (normalizedRankFactor).
    double currentTrackWidth = screenSize.width *
        (_trackWidthAtFinishRatio +
            normalizedRankFactor *
                (_trackWidthAtStartRatio - _trackWidthAtFinishRatio));

    double xPos;

    if (totalParticipants == 1) {
      xPos =
          screenSize.width * _xTrackCenterRatio - markerVisualWidthEstimate / 2;
      // Adjust Y for a single participant to be more centered visually
      yPos = screenSize.height * 0.65 - (_unscaledMarkerHeight * scale) / 2;
    } else {
      if (participantRank == 1) {
        xPos = screenSize.width * _xTrackCenterRatio -
            markerVisualWidthEstimate / 2;
      } else if (participantRank == 2) {
        // Place to the left of the 1st, considering perspective
        double baseOffset =
            markerVisualWidthEstimate * 1.1; // Base separation from center
        double perspectiveOffset = markerVisualWidthEstimate *
            0.3 *
            normalizedRankFactor; // More separation when closer
        xPos = screenSize.width * _xTrackCenterRatio -
            baseOffset -
            perspectiveOffset;
      } else if (participantRank == 3) {
        // Place to the right of the 1st, considering perspective
        double baseOffset = markerVisualWidthEstimate * 0.1;
        double perspectiveOffset =
            markerVisualWidthEstimate * 0.3 * normalizedRankFactor;
        xPos = screenSize.width * _xTrackCenterRatio +
            baseOffset +
            perspectiveOffset;
      } else {
        // For ranks 4 and above, distribute them across the currentTrackWidth.
        int positionIndex =
            participantRank.toInt() - 4; // 0 for rank 4, 1 for rank 5...
        int numGeneralParticipants = totalParticipants - 3;

        if (numGeneralParticipants <= 0) {
          // Should not happen if rank >= 4
          xPos = screenSize.width * _xTrackCenterRatio -
              markerVisualWidthEstimate / 2; // Fallback
        } else {
          // Offset of the current track segment from the left edge of the screen
          double trackStartX = (screenSize.width - currentTrackWidth) / 2.0;
          // Position within the currentTrackWidth.
          double participantSlotWidth =
              currentTrackWidth / numGeneralParticipants;
          // Center participant in their slot
          xPos = trackStartX +
              (positionIndex * participantSlotWidth) +
              (participantSlotWidth / 2.0) -
              (markerVisualWidthEstimate / 2.0);

          // Add slight alternating jitter for a more organic look, more pronounced when closer
          if (numGeneralParticipants > 1) {
            double jitter =
                markerVisualWidthEstimate * 0.15 * normalizedRankFactor;
            xPos += (positionIndex % 2 == 0) ? -jitter : jitter;
          }
        }
      }
    }

    // --- Clamping ---
    double currentMarkerScaledHeight = _unscaledMarkerHeight * scale;

    // Clamp X position to stay within the calculated track width for perspective
    double minXTrack = (screenSize.width - currentTrackWidth) / 2.0;
    double maxXTrack =
        minXTrack + currentTrackWidth - markerVisualWidthEstimate;
    if (totalParticipants > 1) {
      // No track clamping for single participant centered on screen
      xPos = xPos.clamp(minXTrack, maxXTrack);
    }

    // Final X clamp to screen edges as a safeguard
    double minScreenX = 5.0;
    double maxScreenX = screenSize.width - markerVisualWidthEstimate - 5.0;
    xPos = xPos.clamp(minScreenX, maxScreenX);

    // Clamp Y position
    // Top of the marker should not go above a certain point (adjusted by marker height for perspective)
    double minYClamp = screenSize.height *
        _yFinishLineRatio *
        0.9; // Allow some space above the "finish line"
    // Bottom of the marker (yPos is top) should not go below start line ratio
    double maxYClamp =
        (screenSize.height * _yStartLineRatio) - currentMarkerScaledHeight;
    if (totalParticipants == 1) {
      // Adjust Y clamping for single participant
      minYClamp = screenSize.height * 0.2;
      maxYClamp = screenSize.height * 0.8 - currentMarkerScaledHeight;
    }
    yPos = yPos.clamp(minYClamp, maxYClamp);

    return Offset(xPos, yPos);
  }

  double _getParticipantScale(
      int rank, int totalParticipants, Size screenSize) {
    if (totalParticipants == 1) {
      return 1.0; // Prominent scale for a single participant
    }
    // Normalized rank: 0.0 for rank 1, 1.0 for last rank.
    double normalizedRankFactor = (rank - 1) / (totalParticipants - 1);

    // Interpolate scale: rank 1 (furthest) is _minScale, last rank (closest) is _maxScale.
    double scale = _minScale + normalizedRankFactor * (_maxScale - _minScale);
    return scale.clamp(
        _minScale, _maxScale); // Ensure scale is within defined bounds
  }

  @override
  Widget build(BuildContext context) {
    List<RaceParticipant> sortedParticipants = List.from(widget.participants);
    // Sort by rank ascending (1st, 2nd, 3rd...)
    sortedParticipants.sort((a, b) => a.rank.compareTo(b.rank));

    final screenSize = MediaQuery.of(context).size;
    final String formattedTime = _formatDuration(widget.remainingTime);

    if (sortedParticipants.isEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder(
            future: _initializeVideoPlayerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done &&
                  _videoController != null &&
                  _videoController!.value.isInitialized) {
                return SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController!.value.size.width,
                      height: _videoController!.value.size.height,
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                );
              } else if (snapshot.hasError) {
                print(
                    "Video Player Error in FutureBuilder (empty participants): ${snapshot.error}");
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SelectableText.rich(
                      TextSpan(
                        text:
                            'Error: Could not load race background. Please check connection.',
                        style: TextStyle(
                            color: Colors.red.shade300,
                            fontSize: 16,
                            fontWeight: FontWeight.w500),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFC4FF62)));
            },
          ),
          const Center(
            child: Text(
              'Waiting for participants...',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FutureBuilder(
          future: _initializeVideoPlayerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                _videoController != null &&
                _videoController!.value.isInitialized) {
              return SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              );
            } else if (snapshot.hasError) {
              print(
                  "Video Player Error, falling back to static image: ${snapshot.error}");
              // Fallback to a static image if video fails
              return Positioned.fill(
                child: Image.asset(
                  'assets/images/raceui2.png', // Ensure this image exists
                  fit: BoxFit.cover,
                ),
              );
            }
            // Show loading indicator while video is preparing
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFC4FF62)));
          },
        ),
        Positioned(
          top: 20.0, // Adjusted for better visibility from status bar
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Time Remaining: $formattedTime',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                          blurRadius: 2.0,
                          color: Colors.black87,
                          offset: Offset(1, 1))
                    ]),
              ),
            ),
          ),
        ),
        Stack(
          children: sortedParticipants.map((participant) {
            final bool isMe = participant.email?.toLowerCase() ==
                widget.myEmail?.toLowerCase();
            final String? profilePicUrl =
                widget.profilePictureCache[participant.userName];
            final String rankAsset = _getRankAsset(participant.rank);

            // Get scale first, as it might be needed for position calculation (e.g., marker height)
            final scale = _getParticipantScale(
                participant.rank, sortedParticipants.length, screenSize);

            final position = _getParticipantPosition(
                participant.rank, sortedParticipants.length, screenSize, scale);

            return AnimatedPositioned(
              key: ValueKey(participant.email ??
                  participant.userName), // Unique key for animation
              duration: const Duration(
                  milliseconds: 800), // Slightly longer for smoother feel
              curve: Curves.easeInOutCubic, // Smoother animation curve
              top: position.dy,
              left: position.dx,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment
                    .bottomCenter, // Scale from bottom for better ground pinning
                child: _ParticipantMarkerWidget(
                  participant: participant,
                  profilePicUrl: profilePicUrl,
                  isMe: isMe,
                  rankAsset: rankAsset,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
