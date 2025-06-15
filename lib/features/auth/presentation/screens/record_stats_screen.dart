import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RecordStatsScreen extends ConsumerWidget {
  final int durationSeconds;
  final double distanceKm;
  final int steps;
  final int calories;
  final bool isPaused;
  final VoidCallback onPauseToggle;
  final VoidCallback onLocationViewToggle;
  final VoidCallback onFinishRecording;

  const RecordStatsScreen({
    super.key,
    required this.durationSeconds,
    required this.distanceKm,
    required this.steps,
    required this.calories,
    required this.isPaused,
    required this.onPauseToggle,
    required this.onLocationViewToggle,
    required this.onFinishRecording,
  });

  String _formatDuration(int totalSeconds) {
    final Duration duration = Duration(seconds: totalSeconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String hours = twoDigits(duration.inHours);
    final String minutes = twoDigits(duration.inMinutes.remainder(60));
    final String seconds = twoDigits(duration.inSeconds.remainder(60));
    if (hours == '00') {
      return '$minutes:$seconds';
    }
    return '$hours:$minutes:$seconds';
  }

  String _formatAverageSpeed(double distanceKm, int totalSeconds) {
    if (totalSeconds == 0 || distanceKm <= 0) {
      return '0.0'; // Return string for consistency with RecordScreen
    }
    // Calculate speed in km/hr
    double speedKmh = distanceKm / (totalSeconds / 3600.0);
    return speedKmh.toStringAsFixed(1); // Format to one decimal place
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String formattedTime = _formatDuration(durationSeconds);
    final String formattedAvgSpeed =
        _formatAverageSpeed(distanceKm, durationSeconds);

    return Container(
      color: const Color(0xFF121212), // Dark background
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            children: [
              // Top Stats Section - Wrapped in Expanded
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment
                      .center, // Center the large stats vertically
                  children: [
                    const Text('SÜRE',
                        style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(formattedTime,
                          style: const TextStyle(
                              fontSize: 90,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC4FF62))),
                    ),
                    const SizedBox(height: 30),
                    const Text('MESAFE',
                        style: TextStyle(
                            fontSize: 20,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                          distanceKm.toStringAsFixed(2).replaceAll('.', ','),
                          style: const TextStyle(
                              fontSize: 90,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC4FF62))),
                    ),
                    const Text('KM',
                        style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildTextStatItem(
                            "ORT. HIZ", formattedAvgSpeed, "KM/SA"),
                        _buildTextStatItem("ADIM", steps.toString(), "ADIM"),
                        _buildTextStatItem(
                            "KALORİ", calories.toString(), "KKAL"),
                      ],
                    ),
                  ],
                ),
              ),
              // Bottom Controls - Kept outside Expanded, at the bottom of the Column
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0, top: 10.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.stop_circle_outlined,
                          color: Colors.redAccent, size: 35),
                      onPressed: onFinishRecording,
                    ),
                    GestureDetector(
                      onTap: onPauseToggle,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPaused
                                ? Colors.green.shade400
                                : Colors.amber.shade600,
                            boxShadow: [
                              BoxShadow(
                                color: (isPaused
                                        ? Colors.green.shade400
                                        : Colors.amber.shade600)
                                    .withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              )
                            ]),
                        child: Icon(isPaused ? Icons.play_arrow : Icons.pause,
                            color: Colors.white, size: 40),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.map_outlined,
                          color: Color(0xFFC4FF62), size: 35),
                      onPressed: onLocationViewToggle,
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextStatItem(
      String topLabel, String value, String bottomUnitLabel) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(topLabel.toUpperCase(),
            style: const TextStyle(
                fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC4FF62))),
        ),
        const SizedBox(height: 2),
        Text(bottomUnitLabel.toUpperCase(),
            style: const TextStyle(
                fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
