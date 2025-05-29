import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/leaderboard_provider.dart';
import '../providers/user_data_provider.dart';
import '../../domain/models/leaderboard_model.dart';
import '../widgets/network_error_widget.dart';
import 'package:http/http.dart' show ClientException;
import 'dart:io' show SocketException;
import 'package:google_fonts/google_fonts.dart';

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
      //ref.read(userDataProvider.notifier).fetchUserData();Coini Sıfırlıyordu
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
      ref.refresh(userLeaderboardEntryProvider);
    } else {
      ref.refresh(indoorLeaderboardProvider);
      ref.refresh(userLeaderboardEntryProvider);
    }
    // Also refresh the current user's leaderboard entry
  }

  @override
  Widget build(BuildContext context) {
    final isOutdoorSelected = ref.watch(isOutdoorSelectedProvider);
    // Choose the primary provider based on the selected tab
    final currentLeaderboardProvider = isOutdoorSelected
        ? outdoorLeaderboardProvider
        : indoorLeaderboardProvider;
    final leaderboardAsync = ref.watch(currentLeaderboardProvider);
    // Watch user rank separately, handle its loading/error within the data state
    final userRankAsync = ref.watch(userLeaderboardEntryProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      // Use the chosen leaderboard provider's state for the main body
      body: leaderboardAsync.when(
        data: (leaderboardUsers) {
          // Data loaded, build the UI
          return SafeArea(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.info_outline,
                          color: Color(0xFFC4FF62)),
                      onPressed: () => _showLeaderboardInfoDialog(context),
                    ),
                  ],
                ),
                // Title Section

                // Title Section
                Container(
                  margin: const EdgeInsets.all(16.0),
                  padding: const EdgeInsets.symmetric(
                      vertical: 12.0, horizontal: 16.0),
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
                        style: GoogleFonts.bangers(
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
                              ref
                                  .read(isOutdoorSelectedProvider.notifier)
                                  .state = true;
                              ref.refresh(outdoorLeaderboardProvider);
                              ref.refresh(
                                  userLeaderboardEntryProvider); // Refresh user rank too
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
                                style: GoogleFonts.bangers(
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
                              ref
                                  .read(isOutdoorSelectedProvider.notifier)
                                  .state = false;
                              ref.refresh(indoorLeaderboardProvider);
                              ref.refresh(
                                  userLeaderboardEntryProvider); // Refresh user rank too
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
                                style: GoogleFonts.bangers(
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

                // --- User Rank Card (handles its own loading/error state internally) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: userRankAsync.when(
                    data: (userEntry) {
                      if (userEntry != null) {
                        return _buildUserRankCard(userEntry, isOutdoorSelected);
                      }
                      return const SizedBox.shrink(); // Hide if no rank data
                    },
                    loading: () => const SizedBox(
                      height: 60,
                      child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFFC4FF62))),
                    ),
                    // Show subtle error for user rank card, don't block main screen
                    error: (error, stackTrace) {
                      if (error is SocketException ||
                          error is ClientException) {
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.signal_wifi_off_rounded,
                                  color: Colors.redAccent, size: 16),
                              SizedBox(width: 8),
                              Text('Sıralamanız yüklenemedi',
                                  style: GoogleFonts.bangers(
                                      color: Colors.redAccent, fontSize: 12)),
                            ],
                          ),
                        );
                      } else {
                        print("User rank card error: $error");
                        return const SizedBox.shrink(); // Hide for other errors
                      }
                    },
                  ),
                ),
                userRankAsync.maybeWhen(
                  data: (d) => d != null
                      ? const SizedBox(height: 16)
                      : const SizedBox.shrink(),
                  orElse: () => const SizedBox.shrink(),
                ),
                // --- User Rank Card End ---

                // Leaderboard Content (uses the data from the main .when)
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => _refreshCurrentLeaderboard(),
                    child: isOutdoorSelected
                        ? _buildOutdoorLeaderboardView(
                            leaderboardUsers as List<LeaderboardOutdoorDto>)
                        : _buildIndoorLeaderboardView(
                            leaderboardUsers as List<LeaderboardIndoorDto>),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFFC4FF62)),
        ),
        error: (error, stackTrace) {
          // ALWAYS show NetworkErrorWidget for any full-screen error
          return Center(
            child: NetworkErrorWidget(
              // Provide generic title/message for all errors
              title: 'Liderlik Tablosu Yüklenemedi',
              message: 'Bir sorun oluştu, lütfen tekrar deneyin.',
              onRetry: () {
                // Retry fetching the current leaderboard and user rank
                _refreshCurrentLeaderboard();
              },
            ),
          );
        },
      ),
    );
  }

  void _showLeaderboardInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          backgroundColor: const Color(0xFF333333),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '🏅 Liderlik Tablosu Hakkında',
                  style: GoogleFonts.bangers(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Liderlik tablosu her ay sonunda sıfırlanır ve yalnızca canlı, genel yarışlardaki performansına göre şekillenir.',
                    style: GoogleFonts.bangers(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '📌 Solo Mod ve arkadaşlarla yapılan özel oda yarışları sıralamaya dahil değildir.',
                    style: GoogleFonts.bangers(
                        color: Colors.white70, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Canlı yarışlarda kat ettiğin toplam mesafe (km) baz alınarak sıralama oluşturulur.',
                    style: GoogleFonts.bangers(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ayrıca iç mekân ve dış mekân yarışları ayrı kategorilerde değerlendirilir.',
                    style: GoogleFonts.bangers(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '🎁 Her Kategoride Ödül Var!',
                    style: GoogleFonts.bangers(
                        color: Color(0xFFC4FF62),
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ay sonunda iç mekân ve dış mekân kategorilerinde ayrı ayrı:',
                    style: GoogleFonts.bangers(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🥇 İlk 3\'e giren kullanıcılar sürpriz ödüller kazanır!',
                    style: GoogleFonts.bangers(
                        color: Color(0xFFC4FF62), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ne kadar çok yarışa katılır ve hareket edersen, zirveye o kadar yaklaşırsın.',
                    style: GoogleFonts.bangers(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      '🏃‍♂️ Şimdi sıranı al, yarışlara katıl, ödülleri kap! 💥',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.bangers(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Anladım',
                style: GoogleFonts.bangers(color: Color(0xFFC4FF62)),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Renamed: Builds the outdoor list VIEW using provided data
  Widget _buildOutdoorLeaderboardView(
      List<LeaderboardOutdoorDto> leaderboardUsers) {
    final userDataAsync = ref.watch(userDataProvider);
    final currentUserName = userDataAsync.whenOrNull(
      data: (userData) => userData?.userName,
    );

    if (leaderboardUsers.isEmpty) {
      return const Center(
        child: Text('No data available', style: TextStyle(color: Colors.white)),
      );
    }

    final sortedUsers = [...leaderboardUsers]..sort(
        (a, b) => (b.generalDistance ?? 0).compareTo(a.generalDistance ?? 0));

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

    final topThree = rankedUsers.take(3).toList();
    final remainingUsers =
        rankedUsers.length > 3 ? rankedUsers.sublist(3) : <OutdoorRankedUser>[];

    return ListView(
      children: [
        if (topThree.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
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
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: remainingUsers.length,
          itemBuilder: (context, index) {
            final user = remainingUsers[index];
            final isCurrentUser =
                currentUserName != null && user.userName == currentUserName;
            return Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? const Color(0xFFC4FF62).withOpacity(0.2)
                    : const Color(0xFF333333),
                borderRadius: BorderRadius.circular(8),
                border: isCurrentUser
                    ? Border.all(color: const Color(0xFFC4FF62), width: 1.5)
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
                        style: GoogleFonts.bangers(
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
                              user.userName.isNotEmpty ? user.userName[0] : '?',
                              style: const TextStyle(color: Colors.white),
                            )
                          : null,
                    ),
                  ],
                ),
                title: Text(
                  user.userName,
                  style: GoogleFonts.bangers(
                    color:
                        isCurrentUser ? const Color(0xFFC4FF62) : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: Text(
                  '${user.generalDistance?.toStringAsFixed(2) ?? "0.00"} km',
                  style: GoogleFonts.bangers(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // Renamed: Builds the indoor list VIEW using provided data
  Widget _buildIndoorLeaderboardView(
      List<LeaderboardIndoorDto> leaderboardUsers) {
    final userDataAsync = ref.watch(userDataProvider);
    final currentUserName = userDataAsync.whenOrNull(
      data: (userData) => userData?.userName,
    );

    if (leaderboardUsers.isEmpty) {
      return const Center(
        child: Text('No data available', style: TextStyle(color: Colors.white)),
      );
    }

    final sortedUsers = [...leaderboardUsers]
      ..sort((a, b) => (b.indoorSteps ?? 0).compareTo(a.indoorSteps ?? 0));

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

    final topThree = rankedUsers.take(3).toList();
    final remainingUsers =
        rankedUsers.length > 3 ? rankedUsers.sublist(3) : <IndoorRankedUser>[];

    return ListView(
      children: [
        if (topThree.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
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
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: remainingUsers.length,
          itemBuilder: (context, index) {
            final user = remainingUsers[index];
            final isCurrentUser =
                currentUserName != null && user.userName == currentUserName;
            return Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? const Color(0xFFC4FF62).withOpacity(0.2)
                    : const Color(0xFF333333),
                borderRadius: BorderRadius.circular(8),
                border: isCurrentUser
                    ? Border.all(color: const Color(0xFFC4FF62), width: 1.5)
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
                        style: GoogleFonts.bangers(
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
                              user.userName.isNotEmpty ? user.userName[0] : '?',
                              style: const TextStyle(color: Colors.white),
                            )
                          : null,
                    ),
                  ],
                ),
                title: Text(
                  user.userName,
                  style: GoogleFonts.bangers(
                    color:
                        isCurrentUser ? const Color(0xFFC4FF62) : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: Text(
                  '${user.indoorSteps} steps',
                  style: GoogleFonts.bangers(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ],
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
                        style: GoogleFonts.bangers(
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
                    style: GoogleFonts.bangers(
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
          style: GoogleFonts.bangers(
            color: isCurrentUser ? const Color(0xFFC4FF62) : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: fontSize - 4,
          ),
        ),
        if (user is IndoorRankedUser)
          Text(
            '${user.indoorSteps} steps',
            style: GoogleFonts.bangers(
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
                style: GoogleFonts.bangers(
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

  // --- YENİ: Kullanıcı Sıralama Kartı Oluşturucu ---
  Widget _buildUserRankCard(UserLeaderboardEntryDto userEntry, bool isOutdoor) {
    final String rankText = '#${userEntry.rank}';
    // Veri modelinin hem indoorSteps hem de generalDistance içerdiğinden emin ol
    final String valueText = isOutdoor
        ? '${userEntry.generalDistance?.toStringAsFixed(2) ?? "0.00"} km'
        : '${userEntry.indoorSteps ?? 0} steps';

    return Container(
      margin:
          const EdgeInsets.only(bottom: 0), // Alt boşluğu Padding ile verdik
      decoration: BoxDecoration(
        color: const Color(0xFFC4FF62).withOpacity(0.2), // Vurgu rengi
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFC4FF62), // Vurgu kenarlığı
          width: 1.5,
        ),
      ),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30, // Sıralama için genişlik
              child: Text(
                rankText,
                textAlign: TextAlign.center,
                style: GoogleFonts.bangers(
                  color: Color(0xFFC4FF62),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 20, // Avatar boyutu
              backgroundColor: Colors.grey.shade800, // Arkaplan rengi
              backgroundImage: userEntry.profilePicture != null &&
                      userEntry.profilePicture!.isNotEmpty
                  ? NetworkImage(userEntry.profilePicture!)
                  : null, // AssetImage or default icon
              child: (userEntry.profilePicture == null ||
                      userEntry.profilePicture!.isEmpty)
                  ? Text(
                      userEntry.userName.isNotEmpty
                          ? userEntry.userName[0].toUpperCase()
                          : '?',
                      style: GoogleFonts.bangers(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
          ],
        ),
        title: Text(
          userEntry.userName, // Kullanıcı adı
          style: GoogleFonts.bangers(
            color: Color(0xFFC4FF62), // Vurgu rengi
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          // Modified trailing to include IconButton
          mainAxisSize: MainAxisSize.min, // To keep Row compact
          children: [
            Text(
              valueText, // Değer (km veya adım)
              style: GoogleFonts.bangers(
                color: Colors.white, // Değer rengi
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        dense: true, // Daha kompakt görünüm
      ),
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
