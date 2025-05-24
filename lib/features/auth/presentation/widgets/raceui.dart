import 'dart:async'; // ADDED for TimeoutException
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/core/services/signalr_service.dart'; // For RaceParticipant
import 'package:my_flutter_project/features/auth/presentation/widgets/user_profile_avatar.dart';
import 'package:video_player/video_player.dart';

// --- Yeni: Katılımcı İşaretleyici Widget'ı ---
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
        color: Colors.black.withOpacity(0.7), // Biraz daha belirgin arka plan
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
                  radius: 24), // Avatar biraz daha büyük
              if (rankAsset.isNotEmpty && participant.rank <= 3)
                Positioned(
                  left: -6,
                  bottom: -6,
                  child: Image.asset(rankAsset,
                      width: 22, height: 22), // Rank ikonu biraz daha büyük
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            participant.userName,
            style: TextStyle(
                color: Colors.white,
                fontSize: 13, // Yazı boyutu biraz daha büyük
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
            '${participant.distance.toStringAsFixed(1)}km - ${participant.steps} adım',
            style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 10,
                shadows: [
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
// --- Katılımcı İşaretleyici Widget'ı Sonu ---

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

  final double _unscaledMarkerHeight = 100.0;
  final double _bottomScreenPadding = 10.0;

  @override
  void initState() {
    super.initState();
    _videoController =
        VideoPlayerController.asset('assets/images/racevideo.mp4');
    _initializeVideoPlayerFuture = _videoController!
        .initialize()
        .timeout(const Duration(seconds: 10), onTimeout: () {
      print("Video player initialization timed out after 10 seconds.");
      throw TimeoutException(
          'Video player initialization timed out after 10 seconds');
    }).then((_) {
      if (!mounted) return;
      _videoController!.setLooping(true);
      _videoController!.play();
      print("Video player initialized and playing.");
      if (mounted) {
        setState(() {});
      }
    }).catchError((error, stackTrace) {
      print("Video player initialization error: $error");
      print("Video player stackTrace: $stackTrace");
      if (mounted) {
        setState(() {
          // Optionally, you could set a flag here to explicitly show an error message
          // instead of relying on snapshot.hasError in FutureBuilder, if that's not working.
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
      int rank, int totalParticipants, Size screenSize) {
    double scale = _getParticipantScale(rank, totalParticipants, screenSize);
    double currentMarkerScaledHeight = _unscaledMarkerHeight * scale;
    double markerVisualWidthEstimate = 90 * scale; // Genişlik de arttı

    double yPos;
    double xPos;

    // En uzaktaki katılımcının Y konumu (kartın üst kenarı)
    double yEndPosFurthest = screenSize.height * 0.10; // Daha yukarı alındı
    double yStartPosLowest =
        screenSize.height - currentMarkerScaledHeight - _bottomScreenPadding;

    if (totalParticipants == 1) {
      yPos = screenSize.height * 0.68 -
          currentMarkerScaledHeight; // Tek katılımcı için daha aşağıda ve merkezde
      xPos = screenSize.width / 2 - markerVisualWidthEstimate / 2;
    } else {
      if (rank == 1) {
        yPos = yStartPosLowest - (currentMarkerScaledHeight * 1.5);
        xPos = screenSize.width / 2 - markerVisualWidthEstimate / 2;
      } else if (rank == 2) {
        yPos = yStartPosLowest -
            (currentMarkerScaledHeight * 3.5); // 1.'in biraz üzeri
        xPos = screenSize.width / 2 -
            markerVisualWidthEstimate * 1.0; // 1.'in solu
      } else if (rank == 3) {
        yPos = yStartPosLowest -
            (currentMarkerScaledHeight *
                5.5); // 2.'nin biraz üzeri veya aynı hizada
        xPos = screenSize.width / 2 +
            markerVisualWidthEstimate * 0.05; // Adjusted for better centering
      } else {
        // Linter hatasını düzeltmek için: (totalParticipants - 3) ifadesinin 0 olmamasını sağla
        double divisor = (totalParticipants - 3).toDouble();
        if (divisor <= 0) divisor = 1.0; // 0 veya negatif olmasını engelle
        double rankFactor = (rank - 3) / divisor;

        yPos = (yStartPosLowest - currentMarkerScaledHeight * 7.5) -
            (rankFactor *
                ((yStartPosLowest - currentMarkerScaledHeight * 1.5) -
                    yEndPosFurthest));

        if (rank % 2 == 0) {
          xPos = screenSize.width * 0.35 -
              (markerVisualWidthEstimate / 2) -
              (rankFactor * 15); // Adjusted spread
        } else {
          xPos = screenSize.width * 0.65 -
              (markerVisualWidthEstimate / 2) +
              (rankFactor * 15); // Adjusted spread
        }
      }
    }

    // Sınırlamalar
    double minX = 5.0;
    double maxX = screenSize.width - markerVisualWidthEstimate - 5.0;
    double minY = yEndPosFurthest;
    // Tek katılımcı varsa veya rank 1 ise, yStartPosLowest'a kadar inebilir.
    // Diğer durumlarda yStartPosLowest'ın biraz daha yukarısında kalmalı.
    double maxY = (totalParticipants == 1 || rank == 1)
        ? yStartPosLowest
        : yStartPosLowest -
            (currentMarkerScaledHeight *
                0.05); // Reduced upward shift for ranks > 1

    // Tek katılımcı için özel Y clamp
    if (totalParticipants == 1) {
      minY =
          screenSize.height * 0.25; // Allow more space for single participant
      maxY = screenSize.height * 0.72 -
          currentMarkerScaledHeight; // Allow to be lower
    }

    xPos = xPos.clamp(minX, maxX);
    yPos = yPos.clamp(minY, maxY);

    return Offset(xPos, yPos);
  }

  double _getParticipantScale(
      int rank, int totalParticipants, Size screenSize) {
    if (totalParticipants == 1) {
      return 1.05; // Tek katılımcı için biraz daha büyük
    }
    if (rank == 1) return 1.0;
    if (rank == 2) return 0.92;
    if (rank == 3) return 0.86;

    // Diğerleri için kademeli küçülme
    double baseScale = 0.86;
    double reductionFactor = 0.05;
    int effectiveRank = rank - 3;
    double scale = baseScale - (effectiveRank * reductionFactor);
    return scale.clamp(0.50, baseScale); // Minimum ölçek 0.50
  }

  @override
  Widget build(BuildContext context) {
    List<RaceParticipant> sortedParticipants = List.from(widget.participants);
    sortedParticipants.sort((a, b) => a.rank.compareTo(b.rank));

    final screenSize = MediaQuery.of(context).size;
    final String formattedTime = _formatDuration(widget.remainingTime);

    if (widget.participants.isEmpty) {
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
                return const Center(
                    child: Text("Video yüklenemedi",
                        style: TextStyle(color: Colors.white)));
              }
              return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFC4FF62)));
            },
          ),
          const Center(
            child: Text(
              'Yarışmacı bekleniyor...',
              style: TextStyle(color: Colors.white, fontSize: 18),
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
                  "Video Player Error, falling back to image: ${snapshot.error}");
              return Positioned.fill(
                child: Image.asset(
                  'assets/images/raceui2.png',
                  fit: BoxFit.cover,
                ),
              );
            }
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFC4FF62)));
          },
        ),
        Positioned(
          top: 10.0,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Kalan Süre: $formattedTime',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                          blurRadius: 1.0,
                          color: Colors.black54,
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

            final position = _getParticipantPosition(
                participant.rank, sortedParticipants.length, screenSize);
            final scale = _getParticipantScale(
                participant.rank, sortedParticipants.length, screenSize);

            return AnimatedPositioned(
              key: ValueKey(participant.email ?? participant.userName),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOutCubic,
              top: position.dy,
              left: position.dx,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.bottomCenter,
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
