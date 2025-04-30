import 'dart:convert';
import 'dart:developer';

import 'package:flutter/services.dart';

class RaceServiceChannel {
  // Flutter -> Native komutları için
  static const MethodChannel _controlChannel =
      MethodChannel('com.movliq.app/race_control');

  // Native -> Flutter veri akışı için
  static const EventChannel _updateChannel =
      EventChannel('com.movliq.app/race_updates');

  // Başlatma komutu (gerekirse başlangıç verisi gönderilebilir)
  static Future<void> startRaceService({
    Duration? duration,
    required int roomId,
    required String token,
  }) async {
    try {
      final Map<String, dynamic> args = {
        'roomId': roomId,
        'token': token,
      };
      if (duration != null) {
        args['duration'] = duration.inSeconds;
      }

      await _controlChannel.invokeMethod('start', args);
    } on PlatformException catch (e) {
      print(
          "Flutter: Failed to start race service: '${e.message}'. Code: ${e.code}");
      // Bu hatayı kullanıcıya göstermek için rethrow edilebilir veya state'e yansıtılabilir
      rethrow;
    }
  }

  // Durdurma komutu
  static Future<void> stopRaceService() async {
    try {
      print('Flutter: Sending stop command to native...'); // Debug log
      await _controlChannel.invokeMethod('stop');
      print('Flutter: Stop command sent successfully.'); // Debug log
    } on PlatformException catch (e) {
      print(
          "Flutter: Failed to stop race service: '${e.message}'. Code: ${e.code}");
      // Genellikle durdurma hatası kritk değildir
    }
  }

  // Servisten gelen veri akışını dinle
  // Dönen veri Map<String, dynamic> formatında olacak
  static Stream<Map<String, dynamic>> get raceUpdateStream {
    log('[RaceServiceChannel] raceUpdateStream getter accessed. Listening to EventChannel...',
        name: 'RaceServiceChannel');
    return _updateChannel.receiveBroadcastStream().map((event) {
      log('[RaceServiceChannel] Received raw event from native: $event',
          name: 'RaceServiceChannel');
      if (event is String) {
        try {
          // ÖNEMLİ: Dart'ın jsonDecode'u kullanılıyor
          // Native tarafta JSONObject kullandığımız için format uyumlu olmalı
          final Map<String, dynamic> decoded = jsonDecode(event);
          log('[RaceServiceChannel] Decoded event to Map: $decoded',
              name: 'RaceServiceChannel');
          return decoded;
        } catch (e) {
          log("[RaceServiceChannel] Error decoding race update JSON: $e",
              name: 'RaceServiceChannel');
          // Hatalı JSON gelirse boş map veya hata içeren map dönebiliriz
          return {
            'status': 'error',
            'error': 'Invalid JSON format from native'
          };
        }
      } else {
        log("[RaceServiceChannel] Received non-string event: $event",
            name: 'RaceServiceChannel');
        // Beklenmedik tip gelirse hata map'i dönelim
        return {'status': 'error', 'error': 'Unexpected data type from native'};
      }
    });
  }
}
