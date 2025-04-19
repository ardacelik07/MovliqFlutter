import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/leaderboard_provider.dart';
import '../providers/user_data_provider.dart';
import '../../domain/models/leaderboard_model.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    // Ekran ilk açıldığında veriyi yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCurrentLeaderboard();
      // Kullanıcı verilerini de yükle
      ref.read(userDataProvider.notifier).fetchUserData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  // Mevcut tab'a göre leaderboard'ı yenile
  void _refreshCurrentLeaderboard() {
    final isOutdoor = ref.read(isOutdoorSelectedProvider);

    // Provider'ları yenilemek için invalidate yerine refresh kullanalım
    if (isOutdoor) {
      ref.refresh(outdoorLeaderboardProvider);
    } else {
      ref.refresh(indoorLeaderboardProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOutdoorSelected = ref.watch(isOutdoorSelectedProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Title Section
            Container(
              margin: const EdgeInsets.all(16.0),
              padding:
                  const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              decoration: BoxDecoration(
                color: const Color(0xFFC4FF62),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.emoji_events, color: Colors.black),
                  const SizedBox(width: 8),
                  Text(
                    'Ödül Reklamı',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Indoor/Outdoor Toggle
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!isOutdoorSelected) {
                          // Sadece tab değiştiğinde yeni istek at
                          ref.read(isOutdoorSelectedProvider.notifier).state =
                              true;
                          // invalidate yerine refresh kullanalım
                          ref.refresh(outdoorLeaderboardProvider);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        decoration: BoxDecoration(
                          color: isOutdoorSelected
                              ? const Color(0xFFC4FF62)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Center(
                          child: Text(
                            'Outdoor',
                            style: TextStyle(
                              color: isOutdoorSelected
                                  ? Colors.black
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (isOutdoorSelected) {
                          // Sadece tab değiştiğinde yeni istek at
                          ref.read(isOutdoorSelectedProvider.notifier).state =
                              false;
                          // invalidate yerine refresh kullanalım
                          ref.refresh(indoorLeaderboardProvider);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        decoration: BoxDecoration(
                          color: !isOutdoorSelected
                              ? const Color(0xFFC4FF62)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Center(
                          child: Text(
                            'Indoor',
                            style: TextStyle(
                              color: !isOutdoorSelected
                                  ? Colors.black
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Leaderboard Content
            Expanded(
              child: isOutdoorSelected
                  ? _buildOutdoorLeaderboard()
                  : _buildIndoorLeaderboard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutdoorLeaderboard() {
    final outdoorLeaderboardAsync = ref.watch(outdoorLeaderboardProvider);
    final userDataAsync = ref.watch(userDataProvider);

    return outdoorLeaderboardAsync.when(
      data: (leaderboardUsers) {
        if (leaderboardUsers.isEmpty) {
          return const Center(
            child: Text(
              'No data available',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        // Mevcut kullanıcının adını al
        final currentUserName = userDataAsync.whenOrNull(
          data: (userData) => userData?.userName,
        );

        // Sort by generalDistance in descending order
        final sortedUsers = [...leaderboardUsers]..sort((a, b) =>
            (b.generalDistance ?? 0).compareTo(a.generalDistance ?? 0));

        // Add ranks based on the sorted order
        final rankedUsers = sortedUsers.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final user = entry.value;
          return OutdoorRankedUser(
            id: user.id,
            userId: user.userId,
            userName: user.userName,
            profilePicture: user.profilePicture,
            outdoorSteps: user.outdoorSteps ?? 0,
            generalDistance: user.generalDistance ?? 0,
            rank: rank,
          );
        }).toList();

        // Get top 3 and remaining users
        final topThree = rankedUsers.take(3).toList();
        final remainingUsers = rankedUsers.length > 3
            ? rankedUsers.sublist(3)
            : <OutdoorRankedUser>[];

        return Column(
          children: [
            // Top 3
            if (topThree.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (topThree.length > 1)
                    _buildTopUser(topThree[1], 2, currentUserName),
                  const SizedBox(width: 8),
                  if (topThree.isNotEmpty)
                    _buildTopUser(topThree[0], 1, currentUserName),
                  const SizedBox(width: 8),
                  if (topThree.length > 2)
                    _buildTopUser(topThree[2], 3, currentUserName),
                ],
              ),

            const SizedBox(height: 16),

            // Remaining Users List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: remainingUsers.length,
                itemBuilder: (context, index) {
                  final user = remainingUsers[index];
                  final isCurrentUser = currentUserName != null &&
                      user.userName == currentUserName;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    decoration: BoxDecoration(
                      color: isCurrentUser
                          ? const Color(0xFFC4FF62).withOpacity(0.2)
                          : const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrentUser
                          ? Border.all(
                              color: const Color(0xFFC4FF62), width: 1.5)
                          : null,
                    ),
                    child: ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${user.rank}',
                              style: TextStyle(
                                color: isCurrentUser
                                    ? const Color(0xFFC4FF62)
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: Colors.blue.withOpacity(0.2),
                            backgroundImage: user.profilePicture != null &&
                                    user.profilePicture!.isNotEmpty
                                ? NetworkImage(user.profilePicture!)
                                : null,
                            child: (user.profilePicture == null ||
                                    user.profilePicture!.isEmpty)
                                ? Text(
                                    user.userName.isNotEmpty
                                        ? user.userName[0]
                                        : '?',
                                    style: const TextStyle(color: Colors.white),
                                  )
                                : null,
                          ),
                        ],
                      ),
                      title: Text(
                        user.userName,
                        style: TextStyle(
                          color: isCurrentUser
                              ? const Color(0xFFC4FF62)
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: Text(
                        '${user.generalDistance?.toStringAsFixed(2) ?? "0.00"} km',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFC4FF62),
        ),
      ),
      error: (error, stackTrace) => Center(
        child: SelectableText.rich(
          TextSpan(
            text: 'Error loading leaderboard\n',
            style:
                const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            children: [
              TextSpan(
                text: error.toString(),
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndoorLeaderboard() {
    final indoorLeaderboardAsync = ref.watch(indoorLeaderboardProvider);
    final userDataAsync = ref.watch(userDataProvider);

    return indoorLeaderboardAsync.when(
      data: (leaderboardUsers) {
        if (leaderboardUsers.isEmpty) {
          return const Center(
            child: Text(
              'No data available',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        // Mevcut kullanıcının adını al
        final currentUserName = userDataAsync.whenOrNull(
          data: (userData) => userData?.userName,
        );

        // Sort by indoor steps in descending order
        final sortedUsers = [...leaderboardUsers]
          ..sort((a, b) => (b.indoorSteps ?? 0).compareTo(a.indoorSteps ?? 0));

        // Add ranks based on the sorted order
        final rankedUsers = sortedUsers.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final user = entry.value;
          return IndoorRankedUser(
            id: user.id,
            userId: user.userId,
            userName: user.userName,
            profilePicture: user.profilePicture,
            indoorSteps: user.indoorSteps ?? 0,
            rank: rank,
          );
        }).toList();

        // Get top 3 and remaining users
        final topThree = rankedUsers.take(3).toList();
        final remainingUsers = rankedUsers.length > 3
            ? rankedUsers.sublist(3)
            : <IndoorRankedUser>[];

        return Column(
          children: [
            // Top 3
            if (topThree.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (topThree.length > 1)
                    _buildTopUser(topThree[1], 2, currentUserName),
                  const SizedBox(width: 20),
                  if (topThree.isNotEmpty)
                    _buildTopUser(topThree[0], 1, currentUserName),
                  const SizedBox(width: 20),
                  if (topThree.length > 2)
                    _buildTopUser(topThree[2], 3, currentUserName),
                ],
              ),

            const SizedBox(height: 16),

            // Remaining Users List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                itemCount: remainingUsers.length,
                itemBuilder: (context, index) {
                  final user = remainingUsers[index];
                  final isCurrentUser = currentUserName != null &&
                      user.userName == currentUserName;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    decoration: BoxDecoration(
                      color: isCurrentUser
                          ? const Color(0xFFC4FF62).withOpacity(0.2)
                          : const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(8),
                      border: isCurrentUser
                          ? Border.all(
                              color: const Color(0xFFC4FF62), width: 1.5)
                          : null,
                    ),
                    child: ListTile(
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${user.rank}',
                              style: TextStyle(
                                color: isCurrentUser
                                    ? const Color(0xFFC4FF62)
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: Colors.blue.withOpacity(0.2),
                            backgroundImage: user.profilePicture != null &&
                                    user.profilePicture!.isNotEmpty
                                ? NetworkImage(user.profilePicture!)
                                : null,
                            child: (user.profilePicture == null ||
                                    user.profilePicture!.isEmpty)
                                ? Text(
                                    user.userName.isNotEmpty
                                        ? user.userName[0]
                                        : '?',
                                    style: const TextStyle(color: Colors.white),
                                  )
                                : null,
                          ),
                        ],
                      ),
                      title: Text(
                        user.userName,
                        style: TextStyle(
                          color: isCurrentUser
                              ? const Color(0xFFC4FF62)
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: Text(
                        '${user.indoorSteps} steps',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFC4FF62),
        ),
      ),
      error: (error, stackTrace) => Center(
        child: SelectableText.rich(
          TextSpan(
            text: 'Error loading leaderboard\n',
            style:
                const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            children: [
              TextSpan(
                text: error.toString(),
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopUser(dynamic user, int position, String? currentUserName) {
    final double size = position == 1 ? 90.0 : 70.0;
    final double fontSize = position == 1 ? 18.0 : 16.0;
    final bool isCurrentUser =
        currentUserName != null && user.userName == currentUserName;

    return Column(
      children: [
        if (position == 1)
          const Icon(Icons.star, color: Colors.yellow, size: 24),
        if (position != 1) const SizedBox(height: 24),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrentUser
                      ? const Color(0xFFC4FF62)
                      : position == 1
                          ? Colors.yellow
                          : position == 2
                              ? Colors.grey.shade300
                              : Colors.brown,
                  width: isCurrentUser ? 3.0 : 2.0,
                ),
              ),
              child: CircleAvatar(
                radius: size / 2,
                backgroundColor: Colors.blue,
                backgroundImage: user.profilePicture != null &&
                        user.profilePicture!.isNotEmpty
                    ? NetworkImage(user.profilePicture!)
                    : null,
                child: (user.profilePicture == null ||
                        user.profilePicture!.isEmpty)
                    ? Text(
                        user.userName.isNotEmpty ? user.userName[0] : '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFFC4FF62),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$position',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          user.userName,
          style: TextStyle(
            color: isCurrentUser ? const Color(0xFFC4FF62) : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: fontSize - 4,
          ),
        ),
        if (user is IndoorRankedUser)
          Text(
            '${user.indoorSteps} steps',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: fontSize - 2,
            ),
          )
        else if (user is OutdoorRankedUser)
          Column(
            children: [
              Text(
                '${user.generalDistance?.toStringAsFixed(2) ?? "0.00"} km',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize - 1,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// Helper classes to add rank to the data
class IndoorRankedUser extends LeaderboardIndoorDto {
  final int rank;

  IndoorRankedUser({
    required int id,
    required int userId,
    required String userName,
    String? profilePicture,
    required int indoorSteps,
    required this.rank,
  }) : super(
          id: id,
          userId: userId,
          userName: userName,
          profilePicture: profilePicture,
          indoorSteps: indoorSteps,
        );
}

class OutdoorRankedUser extends LeaderboardOutdoorDto {
  final int rank;

  OutdoorRankedUser({
    required int id,
    required int userId,
    required String userName,
    String? profilePicture,
    required int outdoorSteps,
    required double generalDistance,
    required this.rank,
  }) : super(
          id: id,
          userId: userId,
          userName: userName,
          profilePicture: profilePicture,
          outdoorSteps: outdoorSteps,
          generalDistance: generalDistance,
        );
}
