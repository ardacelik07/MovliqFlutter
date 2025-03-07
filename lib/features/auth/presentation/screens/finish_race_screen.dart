import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/signalr_service.dart';
import 'tabs.dart';

class FinishRaceScreen extends ConsumerWidget {
  final List<RaceParticipant> leaderboard;
  final String? myEmail;

  const FinishRaceScreen({
    Key? key,
    required this.leaderboard,
    this.myEmail,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kazanan katılımcıları al (ilk 3)
    final winners =
        leaderboard.length > 3 ? leaderboard.sublist(0, 3) : leaderboard;

    // Kullanıcının kendi sonucunu bul
    RaceParticipant? myResult;
    int? myPosition;

    if (myEmail != null) {
      for (int i = 0; i < leaderboard.length; i++) {
        if (leaderboard[i].email == myEmail) {
          myResult = leaderboard[i];
          myPosition = i + 1;
          break;
        }
      }
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Color(0xFFC4FF62),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Üst başlık
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFC4FF62), Colors.green],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events, color: Colors.black87, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'Yarış Tamamlandı!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              // Kutlama konfetileri
              const SizedBox(height: 10),
              const Icon(Icons.celebration, color: Colors.amber, size: 40),

              // Kupa Platformu
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: winners.isEmpty
                      ? const Center(
                          child: Text(
                            'Sonuçlar yüklenemedi',
                            style: TextStyle(fontSize: 18),
                          ),
                        )
                      : _buildWinnersPodium(winners),
                ),
              ),

              // Divider
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Divider(thickness: 2),
              ),

              // Kendi sonucun
              if (myResult != null) ...[
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Senin Sonucun',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 25,
                                    backgroundColor:
                                        _getPositionColor(myPosition!),
                                    child: CircleAvatar(
                                      radius: 23,
                                      backgroundColor: Colors.white,
                                      child: Text(
                                        myResult.userName[0].toUpperCase(),
                                        style: TextStyle(
                                          color: _getPositionColor(myPosition!),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    myResult.userName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getPositionColor(myPosition!),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$myPosition. Sıra',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatItem(
                                    icon: Icons.directions_run,
                                    value:
                                        '${myResult.distance.toStringAsFixed(2)} m',
                                    label: 'Mesafe',
                                    color: Colors.blue,
                                  ),
                                  _buildStatItem(
                                    icon: Icons.directions_walk,
                                    value: '${myResult.steps}',
                                    label: 'Adım',
                                    color: Colors.green,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],

              // Ana sayfaya dön butonu
              Padding(
                padding: const EdgeInsets.all(20),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const TabsScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC4FF62),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Ana Sayfaya Dön',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWinnersPodium(List<RaceParticipant> winners) {
    final Map<int, RaceParticipant> winnersByRank = {};

    // Katılımcıları sıralamalarına göre haritaya ekle
    for (final winner in winners) {
      winnersByRank[winner.rank] = winner;
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Platform çizgisi
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),

        // 2. ve 3. için platformlar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 2. sıra - sol platform
            if (winnersByRank.containsKey(2))
              _buildPodiumColumn(
                winner: winnersByRank[2]!,
                podiumHeight: 120,
                position: 2,
              )
            else
              _buildEmptyPodium(120, 2),

            // 1. sıra için boşluk (ortada)
            const SizedBox(width: 35),

            // 3. sıra - sağ platform
            if (winnersByRank.containsKey(3))
              _buildPodiumColumn(
                winner: winnersByRank[3]!,
                podiumHeight: 80,
                position: 3,
              )
            else
              _buildEmptyPodium(80, 3),
          ],
        ),

        // 1. sıra - orta platform (en yüksek)
        if (winnersByRank.containsKey(1))
          Positioned(
            bottom: 0,
            child: _buildPodiumColumn(
              winner: winnersByRank[1]!,
              podiumHeight: 160,
              position: 1,
              showCrown: true,
            ),
          )
        else
          Positioned(
            bottom: 0,
            child: _buildEmptyPodium(160, 1),
          ),
      ],
    );
  }

  Widget _buildPodiumColumn({
    required RaceParticipant winner,
    required double podiumHeight,
    required int position,
    bool showCrown = false,
  }) {
    final color = _getPositionColor(position);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Kupa veya Avatar
        Stack(
          alignment: Alignment.center,
          children: [
            // Avatar
            CircleAvatar(
              radius: position == 1 ? 40 : 30,
              backgroundColor: color,
              child: CircleAvatar(
                radius: position == 1 ? 38 : 28,
                backgroundColor: Colors.white,
                child: Text(
                  winner.userName[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: position == 1 ? 28 : 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),

            // Taç (sadece 1. için)
            if (showCrown)
              Positioned(
                top: -15,
                child: Icon(
                  Icons.front_hand,
                  color: Colors.amber[700],
                  size: 30,
                ),
              ),

            // Sıralama rozeti
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '$position',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        // İsim
        Text(
          winner.userName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: position == 1 ? 16 : 14,
            color: position <= 3 ? color : Colors.black,
          ),
        ),

        // Bilgi
        Text(
          '${winner.distance.toStringAsFixed(1)} m',
          style: TextStyle(
            fontSize: position == 1 ? 14 : 12,
            color: Colors.black54,
          ),
        ),

        const SizedBox(height: 6),

        // Platform
        Container(
          width: position == 1 ? 100 : 80,
          height: podiumHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$position',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: position == 1 ? 40 : 30,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPodium(double height, int position) {
    final color = _getPositionColor(position);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Boş avatar
        CircleAvatar(
          radius: position == 1 ? 40 : 30,
          backgroundColor: color.withOpacity(0.5),
          child: const Icon(
            Icons.person_outline,
            color: Colors.white,
            size: 30,
          ),
        ),

        const SizedBox(height: 6),

        // Boş isim
        Text(
          'Boş',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: position == 1 ? 16 : 14,
            color: color.withOpacity(0.7),
          ),
        ),

        // Boş bilgi
        Text(
          '0.0 m',
          style: TextStyle(
            fontSize: position == 1 ? 14 : 12,
            color: Colors.black54,
          ),
        ),

        const SizedBox(height: 6),

        // Platform
        Container(
          width: position == 1 ? 100 : 80,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.5),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Center(
            child: Text(
              '$position',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: position == 1 ? 40 : 30,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getPositionColor(int position) {
    switch (position) {
      case 1:
        return const Color(0xFFFFD700); // Altın
      case 2:
        return const Color(0xFFC0C0C0); // Gümüş
      case 3:
        return const Color(0xFFCD7F32); // Bronz
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 24, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
