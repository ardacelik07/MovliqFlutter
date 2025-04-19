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
  bool _showConfetti = true;

  @override
  void initState() {
    super.initState();

    // 5 saniye sonra konfeti efektini kapat
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showConfetti = false;
        });
      }
    });
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
        body: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFC4FF62),
                    Colors.white,
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Başlık
                    const Text(
                      'Yarış Sona Erdi!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Alt başlık
                    if (currentUser != null)
                      Text(
                        isWinner
                            ? 'Tebrikler! Yarışı kazandınız 🎉'
                            : 'Yarışı ${currentUser.rank}. sırada bitirdiniz.',
                        style: TextStyle(
                          fontSize: 16,
                          color: isWinner
                              ? const Color(0xFFC4FF62)
                              : Colors.black87,
                          fontWeight:
                              isWinner ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Kullanıcının kendi sonuçları
                    if (currentUser != null)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sizin Sonucunuz',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildResultItem(
                                  icon: Icons.emoji_events,
                                  value: currentUser.rank.toString(),
                                  label: 'Sıralama',
                                  color: currentUser.rank == 1
                                      ? Colors.amber
                                      : currentUser.rank == 2
                                          ? Colors.grey
                                          : currentUser.rank == 3
                                              ? Colors.brown
                                              : Colors.black87,
                                ),
                                // Indoor yarışta mesafe gösterme
                                if (!widget.isIndoorRace)
                                  _buildResultItem(
                                    icon: Icons.directions_run,
                                    value:
                                        currentUser.distance.toStringAsFixed(2),
                                    label: 'Mesafe (km)',
                                    color: Colors.blue,
                                  ),
                                _buildResultItem(
                                  icon: Icons.directions_walk,
                                  value: currentUser.steps.toString(),
                                  label: 'Adım',
                                  color: Colors.green,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // Liderlik Tablosu
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Liderlik Tablosu',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: ListView.builder(
                                itemCount: widget.leaderboard.length,
                                itemBuilder: (context, index) {
                                  final user = widget.leaderboard[index];
                                  final isCurrentUser =
                                      user.email == widget.myEmail;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isCurrentUser
                                          ? const Color(0xFFC4FF62)
                                              .withOpacity(0.2)
                                          : Colors.grey.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(8),
                                      border: isCurrentUser
                                          ? Border.all(
                                              color: const Color(0xFFC4FF62),
                                              width: 2)
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        // Sıralama
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: user.rank == 1
                                                ? Colors.amber
                                                : user.rank == 2
                                                    ? Colors.grey.shade300
                                                    : user.rank == 3
                                                        ? Colors.brown.shade300
                                                        : Colors.grey.shade100,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${user.rank}',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: user.rank <= 3
                                                    ? Colors.white
                                                    : Colors.black54,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Kullanıcı adı
                                        Expanded(
                                          child: Text(
                                            user.userName,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: isCurrentUser
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                        // Mesafe (Indoor yarışta gösterme)
                                        if (!widget.isIndoorRace)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.blue.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${user.distance.toStringAsFixed(2)} km',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ),
                                        if (!widget.isIndoorRace)
                                          const SizedBox(width: 8),
                                        // Adım sayısı
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.green.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${user.steps} adım',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Ana Sayfaya Dön Butonu
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: ElevatedButton(
                        onPressed: _navigateToHomePage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC4FF62),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.home),
                            SizedBox(width: 8),
                            Text('Ana Sayfaya Dön',
                                style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),

            // Konfeti efekti
            if (_showConfetti)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: ConfettiPainter(),
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
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black54,
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

class ConfettiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random();
    final paint = Paint();

    // 100 konfeti parçası çiz
    for (int i = 0; i < 100; i++) {
      // Rastgele renk belirle
      paint.color = Color.fromRGBO(
        random.nextInt(255),
        random.nextInt(255),
        random.nextInt(255),
        random.nextDouble() * 0.7 + 0.3,
      );

      // Rastgele pozisyon ve boyut belirle
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final width = random.nextDouble() * 10 + 5;
      final height = random.nextDouble() * 10 + 5;

      // Rastgele şekil seç (0: dikdörtgen, 1: daire)
      final shape = random.nextInt(2);

      if (shape == 0) {
        // Dikdörtgen çiz
        canvas.drawRect(
          Rect.fromLTWH(x, y, width, height),
          paint,
        );
      } else {
        // Daire çiz
        canvas.drawCircle(
          Offset(x, y),
          width / 2,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
