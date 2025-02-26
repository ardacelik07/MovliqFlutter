import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_controller);

    _pulseAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Üst kısım - Profil
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 25,
                    backgroundImage: AssetImage('assets/images/nike.png'),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back!',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const Text(
                        'John Doe',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            // Slider
            Container(
              height: 180,
              color: Colors.white,
              child: PageView.builder(
                itemCount: 5,
                controller: PageController(viewportFraction: 0.93),
                padEnds: false,
                itemBuilder: (context, index) {
                  return Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 0,
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.purple[300]!,
                                  Colors.purple[600]!,
                                ],
                              ),
                            ),
                            child: Image.asset(
                              index == 0
                                  ? 'assets/images/nike.png'
                                  : index == 1
                                      ? 'assets/images/slider.png'
                                      : index == 2
                                          ? 'assets/images/active.jpg'
                                          : index == 3
                                              ? 'assets/images/finish.jpg'
                                              : 'assets/images/welcome.png',
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${index + 1}/5',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            bottom: 16,
                            right: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'NEW',
                                    style: TextStyle(
                                      color: Colors.purple,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  index == 0
                                      ? 'Special Challenge'
                                      : index == 1
                                          ? 'Daily Workout'
                                          : index == 2
                                              ? 'Active Goals'
                                              : index == 3
                                                  ? 'Race Time'
                                                  : 'Welcome Runner',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  index == 0
                                      ? 'Join now and win rewards! 🏆'
                                      : index == 1
                                          ? 'Start your daily challenge 💪'
                                          : index == 2
                                              ? 'Reach your goals today 🎯'
                                              : index == 3
                                                  ? 'Race with others now 🏃'
                                                  : 'Begin your journey 🌟',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Quick Actions Grid

            // Challenge kısmı
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Ready to challenge yourself today?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Make cardio fun! Click now to join a live race and win unique rewards! 🚀🏆',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    // 3D Animasyonlu Movliq Butonu
                    GestureDetector(
                      onTapDown: (_) => setState(() => _isPressed = true),
                      onTapUp: (_) => setState(() => _isPressed = false),
                      onTapCancel: () => setState(() => _isPressed = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF43A047),
                              Color(0xFF2E7D32),
                            ],
                            stops: [0.2, 0.9],
                          ),
                          boxShadow: [
                            // Alt gölge (3D efekti için)
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              offset: Offset(0, _isPressed ? 2 : 4),
                              blurRadius: _isPressed ? 4 : 8,
                            ),
                            // Üst ışık efekti
                            const BoxShadow(
                              color: Colors.white24,
                              offset: Offset(-2, -2),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                            // Yeşil parlama
                            BoxShadow(
                              color: const Color(0xFF4CAF50).withOpacity(0.4),
                              spreadRadius: _isPressed ? 1 : 4,
                              blurRadius: _isPressed ? 8 : 16,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Dönme efekti
                            TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(seconds: 20),
                              builder: (context, double value, child) {
                                return Transform.rotate(
                                  angle: value * 2 * 3.14,
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: SweepGradient(
                                        colors: [
                                          const Color.fromARGB(
                                                  255, 103, 190, 106)
                                              .withOpacity(0),
                                          const Color.fromARGB(
                                                  255, 143, 216, 146)
                                              .withOpacity(0.3),
                                          const Color.fromARGB(255, 0, 0, 0)
                                              .withOpacity(0),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Nabız efekti
                            TweenAnimationBuilder(
                              tween: Tween<double>(begin: 0.95, end: 1.05),
                              duration: const Duration(milliseconds: 1000),
                              curve: Curves.easeInOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: _isPressed ? 0.9 : value,
                                  child: Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Logo
                            AnimatedScale(
                              duration: const Duration(milliseconds: 200),
                              scale: _isPressed ? 0.8 : 1.0,
                              child: Image.asset(
                                'assets/images/Movliq_beyaz.png',
                                width: 55,
                                height: 55,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionItem(String title, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: Colors.black),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
