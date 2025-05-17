import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart';
import 'package:pedometer/pedometer.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/record_request_model.dart';
import '../providers/record_provider.dart';
import '../providers/user_data_provider.dart';
import '../providers/recording_state_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/earn_coin_widget.dart';
import '../screens/tabs.dart';
import './record_stats_screen.dart';
import 'package:flutter/services.dart'; // Import for SystemUiOverlayStyle
import 'dart:typed_data'; // Uint8List için eklendi
import 'package:flutter/services.dart'; // rootBundle için eklendi

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isPaused = false;
  bool _showStatsScreen = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Timer related properties
  int _seconds = 0;
  Timer? _timer;
  Timer? _calorieCalculationTimer; // Added for dedicated calorie calculation
  double _distance = 0.0;
  int _calories = 0;
  double _pace = 0.0;
  DateTime? _startTime;

  // Selected activity type
  String _activityType = 'Running';

  // Mapbox related properties
  mb.MapboxMap? _mapboxMap;
  mb.PointAnnotationManager? _pointAnnotationManager;
  mb.PolylineAnnotationManager? _polylineAnnotationManager;
  List<mb.Point> _mapboxRouteCoordinates = [];
  mb.Point? _currentMapboxPoint;
  mb.PointAnnotation? _currentLocationMarker;
  Uint8List? _markerImage;

  bool _hasLocationPermission = false;

  // Pedometer related properties
  int _steps = 0;
  int _initialSteps = 0;
  StreamSubscription<StepCount>? _stepCountSubscription;
  bool _hasPedometerPermission = false;

  // Hareketsiz durumdaki kalori hesaplaması için değişkenler
  double _lastDistance = 0.0;
  int _lastSteps = 0;
  DateTime? _lastCalorieCalculationTime;

  // Add state for map style and the style JSON itself
  bool _isMapStyleSet = false;
  final String _darkMapStyleJson = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#212121"
      }
    ]
  },
  {
    "elementType": "labels.icon",
    "stylers": [
      {
        "visibility": "on"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#212121"
      }
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "featureType": "administrative.country",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#9e9e9e"
      }
    ]
  },
  {
    "featureType": "administrative.land_parcel",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#bdbdbd"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#181818"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#616161"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#1b1b1b"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#2c2c2c"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8a8a8a"
      }
    ]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#373737"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#3c3c3c"
      }
    ]
  },
  {
    "featureType": "road.highway.controlled_access",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#4e4e4e"
      }
    ]
  },
  {
    "featureType": "road.local",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#616161"
      }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#757575"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#000000"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#3d3d3d"
      }
    ]
  }
]
''';

  // Default camera position (Istanbul) - MODIFIED
  final mb.CameraOptions _initialCameraOptions = mb.CameraOptions(
    center: mb.Point(coordinates: mb.Position(28.9784, 41.0082)), // İstanbul
    zoom: 12.0,
  );

  geo.Position? _currentGeoPosition;
  StreamSubscription<geo.Position>? _positionStreamSubscriptionGeo;

  @override
  void initState() {
    super.initState();
    _loadMarkerImage();
    // _requestPermissions(); // _initPermissions çağrılacak, bu direkt çağrı kaldırıldı.

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _pulseController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _pulseController.forward();
        }
      });

    // İzinleri başlat - hafif bir gecikmeyle (ekranın önce yüklenmesine izin ver)
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _initPermissions();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    _calorieCalculationTimer?.cancel();
    _positionStreamSubscriptionGeo?.cancel();
    _stepCountSubscription?.cancel();
    _timer?.cancel();
    _calorieCalculationTimer?.cancel();
    _mapboxMap?.dispose();
    super.dispose();
  }

  // --- ADDED: Method to handle finishing recording and hiding stats screen ---
  void _finishRecordingAndHideStats() {
    _finishRecording();
    if (mounted) {
      setState(() {
        _showStatsScreen = false;
      });
    }
  }
  // --- END OF ADDED METHOD ---

  Future<void> _loadMarkerImage() async {
    try {
      final ByteData byteData =
          await rootBundle.load('assets/images/mapbox.png');
      if (mounted) {
        setState(() {
          _markerImage = byteData.buffer.asUint8List();
        });
      }
      debugPrint(
          'RecordScreen: _loadMarkerImage - Özel işaretçi (14.png) yüklendi. Boyut: ${_markerImage?.lengthInBytes} bytes');
    } catch (e) {
      debugPrint(
          'RecordScreen: _loadMarkerImage - Özel işaretçi yüklenirken HATA: $e');
    }
  }

  // Tüm izinleri başlatan fonksiyon
  Future<void> _initPermissions() async {
    print('RecordScreen - İzin kontrolü başlatılıyor...');

    // --- Bildirim İzni İsteği (Android 13+) ---
    if (Platform.isAndroid) {
      // Cihazın SDK versiyonunu almak için device_info_plus gerekebilir,
      // ancak permission_handler genellikle bunu kendi içinde yönetir.
      // Direkt olarak izni isteyebiliriz.
      final notificationStatus = await Permission.notification.request();
      print('Bildirim İzin Durumu: $notificationStatus');
      if (notificationStatus.isPermanentlyDenied) {
        // Kullanıcı kalıcı olarak reddettiyse ayarlara yönlendirme gösterilebilir.
        // _showSettingsDialog("Bildirim İzni", "Uygulamanın bildirim gönderebilmesi için izin gereklidir.");
      } else if (notificationStatus.isDenied) {
        // Kullanıcı reddettiyse, belki bir açıklama gösterilebilir.
        print('Bildirim izni reddedildi.');
      }
    }
    // --- Bildirim İzni İsteği Bitişi ---

    // Konum servislerinin açık olup olmadığını kontrol et
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Konum servisleri kapalıysa, kullanıcıyı uyar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen konum servislerini açın'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      // Konum servislerini açma isteği göster
      await geo.Geolocator.openLocationSettings();
      return;
    }

    // Önce izinleri kontrol et - zaten verilmişse istemek zorunda kalma
    if (Platform.isIOS) {
      // iOS için Geolocator ile izin kontrolü
      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.always ||
          permission == geo.LocationPermission.whileInUse) {
        setState(() {
          _hasLocationPermission = true;
        });
        await _getCurrentLocation(); // Hemen konum almaya başla
      } else {
        await _checkLocationPermission(); // İzin yoksa iste
      }
    } else {
      // Android için Permission.locationAlways ile kontrol
      final status = await Permission.locationAlways.status;
      if (status.isGranted) {
        setState(() {
          _hasLocationPermission = true;
        });
        await _getCurrentLocation(); // Hemen konum almaya başla
      } else {
        await _checkLocationPermission(); // İzin yoksa iste
      }
    }

    // Aktivite izinlerini de kontrol et
    await _checkActivityPermission();

    if (mounted) {
      setState(() {}); // İşaretçi oluşturma denemesinden sonra UI'ı güncelle
    }
  }

  // Aktivite izinlerini kontrol eden fonksiyon
  Future<void> _checkActivityPermission() async {
    // Platform-specific permission checks
    if (Platform.isAndroid) {
      // Android'de adım sayar iznini kontrol et
      if (await Permission.activityRecognition.request().isGranted) {
        setState(() {
          _hasPedometerPermission = true;
        });
        _initPedometer();
      }
    } else if (Platform.isIOS) {
      // iOS için pedometer'ı her koşulda başlatmayı deneyelim
      setState(() {
        _hasPedometerPermission = true;
      });

      try {
        // Pedometer'ı başlatmayı dene
        _initPedometer();

        // Sensör iznini kontrol et ve iste
        final sensorStatus = await Permission.sensors.request();
        print('RecordScreen - iOS sensör izin durumu: $sensorStatus');

        // HealthKit izinlerinin verilip verilmediğini kontrol etmek için
        // adım sayma stream'ini dinlemeye başla ve 3 saniye bekle
        bool stepsAvailable = false;
        final subscription = Pedometer.stepCountStream.listen((step) {
          print('RecordScreen - Adım algılandı: ${step.steps}');
          stepsAvailable = true;
          // Eğer adım algılanırsa, artık Health izni var demektir
          setState(() {
            _hasPedometerPermission = true;
          });
        }, onError: (error) {
          print('RecordScreen - Adım algılama hatası: $error');
        });

        // 3 saniye bekle, eğer bu sürede step eventi gelmezse:
        await Future.delayed(const Duration(seconds: 3));
        subscription.cancel();

        // Eğer adım bilgisi alınamadıysa ve daha önce dialog gösterilmediyse Health app'e yönlendir
        if (!stepsAvailable && mounted) {}
      } catch (e) {
        print('RecordScreen - Pedometer başlatma hatası: $e');
        // Hata durumunda dialog göster
        if (mounted) {}
      }
    }
  }

  // Health Kit izni için özel dialog (iOS)

  // Konum izinlerini kontrol eden fonksiyon
  Future<void> _checkLocationPermission() async {
    print('RecordScreen - Konum izni kontrolü başlatılıyor...');

    if (Platform.isIOS) {
      // iOS için: Geolocator'ı doğrudan kullan (daha iyi çalışıyor)
      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      print('RecordScreen - iOS konum izni durumu: $permission');

      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        print('RecordScreen - iOS konum izni istendikten sonra: $permission');
      }

      // LocationPermission.whileInUse ve LocationPermission.always her ikisi de yeterli
      setState(() {
        _hasLocationPermission =
            permission == geo.LocationPermission.whileInUse ||
                permission == geo.LocationPermission.always;
      });

      print('RecordScreen - iOS konum izni var mı?: $_hasLocationPermission');

      if (_hasLocationPermission) {
        // İzin varsa konumu al
        await _getCurrentLocation();
      } else if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {}
    } else {
      // Android için: Permission.locationAlways kullanmaya devam et
      final status = await Permission.locationAlways.status;
      print('RecordScreen - Android konum izni durumu: $status');

      // Eğer izin henüz verilmemişse iste
      if (!status.isGranted && !status.isLimited) {
        final requestedStatus = await Permission.locationAlways.request();
        print(
            'RecordScreen - Android izin istendikten sonra: $requestedStatus');

        setState(() {
          _hasLocationPermission =
              requestedStatus.isGranted || requestedStatus.isLimited;
        });

        if (!_hasLocationPermission &&
            (requestedStatus.isDenied ||
                requestedStatus.isPermanentlyDenied)) {}
      } else {
        setState(() {
          _hasLocationPermission = true;
        });
      }

      print(
          'RecordScreen - Android konum izni var mı?: $_hasLocationPermission');

      if (_hasLocationPermission) {
        // İzin varsa konumu al
        await _getCurrentLocation();
      }
    }
  }

  // Kullanıcı izin vermediğinde gösterilecek dialog (Opsiyonel)

  // Mevcut konumu al ve haritayı oraya taşı
  Future<void> _getCurrentLocation() async {
    try {
      debugPrint('RecordScreen: _getCurrentLocation çağrıldı.');
      geo.Position position = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high);

      debugPrint(
          'RecordScreen: _getCurrentLocation - Konum alındı: ${position.latitude}, ${position.longitude}');

      _currentGeoPosition = position;
      _currentMapboxPoint = mb.Point(
          coordinates: mb.Position(position.longitude, position.latitude));
      debugPrint(
          'RecordScreen: _getCurrentLocation - _currentMapboxPoint ayarlandı: ${_currentMapboxPoint?.encode()}');

      if (_currentLocationMarker != null) {
        debugPrint(
            'RecordScreen: _getCurrentLocation - Önceki işaretçi (${_currentLocationMarker?.id}) siliniyor.');
        try {
          await _pointAnnotationManager?.delete(_currentLocationMarker!);
          _currentLocationMarker = null;
          debugPrint(
              'RecordScreen: _getCurrentLocation - Önceki işaretçi silindi.');
        } catch (e) {
          debugPrint(
              'RecordScreen: _getCurrentLocation - Önceki işaretçiyi silerken HATA: $e');
        }
      }

      debugPrint(
          'RecordScreen: _getCurrentLocation - İşaretçi oluşturma kontrolü. Point: ${_currentMapboxPoint != null}, Manager: ${_pointAnnotationManager != null}');
      if (_currentMapboxPoint != null && _pointAnnotationManager != null) {
        debugPrint(
            'RecordScreen: _getCurrentLocation - Özel işaretçi (14.png) oluşturuluyor. Point: ${_currentMapboxPoint?.encode()}');
        try {
          _currentLocationMarker = await _pointAnnotationManager!.create(
            mb.PointAnnotationOptions(
              geometry: _currentMapboxPoint!,
              image: _markerImage,
              iconSize: 0.15,
            ),
          );
          debugPrint(
              'RecordScreen: _getCurrentLocation - İşaretçi OLUŞTURULDU. ID: ${_currentLocationMarker?.id}');
          if (_mapboxMap != null && _currentMapboxPoint != null) {
            debugPrint(
                'RecordScreen: _getCurrentLocation - Kamera mevcut konuma (${_currentMapboxPoint?.encode()}) uçuruluyor.');
            await _mapboxMap!.flyTo(
              mb.CameraOptions(
                center: _currentMapboxPoint!,
                zoom: 17.0,
              ),
              mb.MapAnimationOptions(duration: 1500, startDelay: 0),
            );
            debugPrint('RecordScreen: _getCurrentLocation - Kamera uçuruldu.');
          }
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          debugPrint(
              'RecordScreen: _getCurrentLocation - Özel işaretçi oluşturulurken HATA: $e');
        }
      } else {
        debugPrint(
            'RecordScreen: _getCurrentLocation - İşaretçi oluşturma ATLANDI. _currentMapboxPoint: ${_currentMapboxPoint}, _pointAnnotationManager: ${_pointAnnotationManager}');
      }

      if (!_isRecording &&
          _mapboxRouteCoordinates.isEmpty &&
          _currentMapboxPoint != null) {
        _mapboxRouteCoordinates.add(_currentMapboxPoint!);
        debugPrint(
            'RecordScreen: _getCurrentLocation - Başlangıç noktası rotaya eklendi.');
      }
    } catch (e) {
      debugPrint('RecordScreen: _getCurrentLocation genel HATA: $e');
      if (mounted) {
        // Hata durumunda da UI güncellenebilir (opsiyonel)
        setState(() {});
      }
    }
  }

  // Konum takibini başlat
  void _startLocationTracking() {
    if (!_hasLocationPermission) {
      _checkLocationPermission();
      return;
    }

    try {
      print('Konum takibi başlatılıyor...');
      geo.LocationSettings locationSettings;
      if (Platform.isAndroid) {
        locationSettings = geo.AndroidSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 5,
          foregroundNotificationConfig: const geo.ForegroundNotificationConfig(
              notificationText:
                  "Movliq aktivitenizi kaydederken konumunuzu takip ediyor.",
              notificationTitle: "Movliq Kayıt Devam Ediyor",
              enableWakeLock: true,
              notificationIcon: geo.AndroidResource(
                  name: 'launcher_icon', defType: 'mipmap')),
        );
      } else if (Platform.isIOS) {
        locationSettings = geo.AppleSettings(
          accuracy: geo.LocationAccuracy.high,
          activityType: geo.ActivityType.fitness,
          distanceFilter: 5,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
        );
      } else {
        locationSettings = const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 5,
        );
      }

      _positionStreamSubscriptionGeo = geo.Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((geo.Position position) {
        print('Konum güncellendi: ${position.latitude}, ${position.longitude}');
        if (mounted && _isRecording && !_isPaused) {
          final newMapboxPoint = mb.Point(
              coordinates: mb.Position(position.longitude, position.latitude));

          setState(() {
            if (_currentGeoPosition != null) {
              double newDistance = geo.Geolocator.distanceBetween(
                _currentGeoPosition!.latitude,
                _currentGeoPosition!.longitude,
                position.latitude,
                position.longitude,
              );
              _distance += newDistance / 1000;
            }

            _currentGeoPosition = position;
            _currentMapboxPoint = newMapboxPoint;
            _mapboxRouteCoordinates.add(newMapboxPoint);

            debugPrint(
                'RecordScreen: _startLocationTracking - İşaretçi güncelleme/oluşturma kontrolü. Manager: ${_pointAnnotationManager != null}, Marker: ${_currentLocationMarker != null}');

            if (_pointAnnotationManager != null &&
                _currentLocationMarker != null) {
              debugPrint(
                  'RecordScreen: _startLocationTracking - Mevcut işaretçi (${_currentLocationMarker?.id}) güncelleniyor. Yeni Point: ${newMapboxPoint.encode()}');
              _pointAnnotationManager
                  ?.update(_currentLocationMarker!..geometry = newMapboxPoint)
                  .then((_) => debugPrint(
                      'RecordScreen: _startLocationTracking - İşaretçi GÜNCELLENDİ.'))
                  .catchError((e) => debugPrint(
                      "RecordScreen: _startLocationTracking - İşaretçi güncellerken HATA: $e"));
            } else if (_pointAnnotationManager != null &&
                _currentLocationMarker == null) {
              debugPrint(
                  'RecordScreen: _startLocationTracking - Yeni özel işaretçi (14.png) oluşturuluyor. Point: ${newMapboxPoint.encode()}');
              _pointAnnotationManager
                  ?.create(mb.PointAnnotationOptions(
                geometry: newMapboxPoint,
                image: _markerImage,
                iconSize: 0.15,
              ))
                  .then((annotation) {
                _currentLocationMarker = annotation;
                debugPrint(
                    'RecordScreen: _startLocationTracking - Yeni işaretçi OLUŞTURULDU. ID: ${annotation.id}');
              }).catchError((e) => debugPrint(
                      "RecordScreen: _startLocationTracking - Takip sırasında işaretçi oluşturulurken HATA: $e"));
            }

            if (_polylineAnnotationManager != null &&
                _mapboxRouteCoordinates.length > 1) {
              _polylineAnnotationManager
                  ?.deleteAll()
                  .catchError((e) => print("Error deleting polylines: $e"));
              _polylineAnnotationManager
                  ?.create(mb.PolylineAnnotationOptions(
                    geometry: mb.LineString(
                        coordinates: _mapboxRouteCoordinates
                            .map((p) => p.coordinates)
                            .toList()), // Pass LineString object directly
                    lineColor: const Color(0xFFC4FF62).value,
                    lineWidth: 5.0,
                  ))
                  .catchError((e) => print("Error creating polyline: $e"));
            }

            _mapboxMap?.flyTo(mb.CameraOptions(center: newMapboxPoint),
                mb.MapAnimationOptions(duration: 500));
          });
        }
      }, onError: (e) {
        print('Konum takibi hatası: $e');
      });
    } catch (e) {
      print('Konum takibi başlatma hatası: $e');
    }
  }

  // Konum takibini durdur
  void _stopLocationTracking() {
    _positionStreamSubscriptionGeo?.cancel();
    _positionStreamSubscriptionGeo = null;
  }

  void _toggleRecording() {
    if (_isRecording) {
      _finishRecording();
    } else {
      _startRecording();
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _isPaused = false;
      _startTime = DateTime.now();
      _initialSteps = 0;
      _steps = 0;
      _distance = 0.0;
      _seconds = 0;
      _calories = 0;
      _pace = 0.0;
      _mapboxRouteCoordinates = []; // Reset Mapbox route coordinates
      _polylineAnnotationManager
          ?.deleteAll()
          .catchError((e) => print("Error deleting polylines on start: $e"));
      if (_currentLocationMarker != null) {
        // Clear existing marker
        _pointAnnotationManager
            ?.delete(_currentLocationMarker!)
            .catchError((e) => print("Error deleting marker on start: $e"));
        _currentLocationMarker = null;
      }
      _lastCalorieCalculationTime = null;
      _pulseController.forward();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_isPaused && _isRecording) {
          setState(() {
            _seconds++;
            _pace = _seconds > 0 ? (_distance / (_seconds / 3600.0)) : 0;
          });
        }
      });
      _initializeCalorieCalculation();
      _startLocationTracking();
      if (_hasPedometerPermission) {
        _initPedometer();
      }
    });
    ref
        .read(recordStateProvider.notifier)
        .startRecording(_forceStopAndResetActivity);
  }

  void _finishRecording() {
    // Save final values before resetting
    final int finalDuration = _seconds;
    final double finalDistance = _distance;
    // Ensure final calorie calculation happens if needed, or use current _calories
    // For simplicity, we use the _calories as updated by the periodic timer.
    final int finalCalories = _calories;
    final int finalSteps = _steps;
    final int averageSpeed = _pace.toInt();
    final DateTime recordStartTime = _startTime ?? DateTime.now();

    // Create and submit the record request
    _submitRecordData(
      duration: finalDuration,
      distance: finalDistance,
      calories: finalCalories,
      steps: finalSteps.toDouble(),
      averageSpeed: averageSpeed,
      startTime: recordStartTime,
    );

    setState(() {
      _isRecording = false;
      _isPaused = false;
      _pulseController.stop();
      _pulseController.reset();

      _timer?.cancel();
      _calorieCalculationTimer?.cancel();
      _stopLocationTracking();

      // Reset activity data
      _seconds = 0;
      _distance = 0.0;
      _calories = 0;
      _pace = 0.0;
      _steps = 0;
      _initialSteps = 0;
      _startTime = null;
      _lastCalorieCalculationTime = null;

      // Harita rota verilerini temizle
      _mapboxRouteCoordinates = [];
      _polylineAnnotationManager
          ?.deleteAll()
          .catchError((e) => print("Error deleting polylines on finish: $e"));

      // İşaretleyiciyi temizle
      if (_currentLocationMarker != null) {
        _pointAnnotationManager
            ?.delete(_currentLocationMarker!)
            .catchError((e) => print("Error deleting marker on finish: $e"));
        _currentLocationMarker = null;
      }

      _getCurrentLocation(); // Haritayı mevcut konuma ortala
    });

    ref.read(recordStateProvider.notifier).stopRecording();
  }

  void _submitRecordData({
    required int duration,
    required double distance,
    required int calories,
    required double steps,
    required int averageSpeed,
    required DateTime startTime,
  }) {
    final recordRequest = RecordRequestModel(
      duration: duration,
      distance: distance,
      calories: calories,
      steps: steps,
      averageSpeed: averageSpeed,
      startTime: startTime,
    );

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktiviteniz kaydediliyor...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Submit data to backend
      ref.read(recordSubmissionProvider(recordRequest).future).then(
        (response) async {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aktivite başarıyla kaydedildi!'),
              backgroundColor: Colors.green,
            ),
          );
          print("💰 Coins fetched after successful activity record.");

          // --- YENİ EKLENEN KISIM: Coin kazanma isteği ---
          try {
            // Provider artık doğrudan double döndürüyor
            final double earnedAmount =
                await ref.read(recordEarnCoinProvider(distance).future);

            print("🪙 Coin Kazanma İsteği Sonucu (double): $earnedAmount");

            if (earnedAmount > 0 && mounted) {
              // Popup'ı göstermek için yeni fonksiyonu çağır (double ile)
              _showCoinPopup(context, earnedAmount);
            }
          } catch (coinError) {
            print("🪙 Coin Kazanma İsteği Hatası: $coinError");
            // Hata durumunda kullanıcıya bilgi verilebilir (opsiyonel)
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(
            //     content: Text('Coin kazanılırken bir hata oluştu: ${coinError.toString()}'),
            //     backgroundColor: Colors.orange,
            //   ),
            // );
          }
          // --- Coin kazanma isteği sonu ---
        },
        onError: (error) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Aktivite kaydedilemedi: ${error.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Duraklatma/devam etme fonksiyonu
  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;

      if (_isPaused) {
        // Pause recording
        _pulseController.stop();
        _calorieCalculationTimer?.cancel(); // Pause calorie timer
        _stopLocationTracking();
        _stepCountSubscription?.pause(); // Pause pedometer
      } else {
        // Resume recording
        _pulseController.forward();
        _initializeCalorieCalculation(); // Resume calorie timer
        // Resume location tracking
        _startLocationTracking();
        _stepCountSubscription?.resume(); // Resume pedometer
      }
    });
    // recordStateProvider'a dokunmuyoruz, kayıt hala aktif (sadece duraklatıldı).
  }

  void _selectActivityType(String type) {
    if (!_isRecording) {
      setState(() {
        _activityType = type;
      });
    } else {
      // Maybe show a snackbar that activity can't be changed while recording
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kayıt sırasında aktivite türü değiştirilemez'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatTime(int seconds) {
    int hours = seconds ~/ 3600;
    int minutes = (seconds % 3600) ~/ 60;
    int remainingSeconds = seconds % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Helper method for building stat columns
  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // Helper method for building stat displays with icon
  Widget _buildStat({
    required String iconAsset,
    required String value,
    required String unit,
  }) {
    return Row(
      children: [
        Image.asset(
          iconAsset,
          width: 26,
          height: 26,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 16,
                color: Color.fromARGB(137, 255, 255, 255),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Make status bar transparent
        statusBarIconBrightness: Brightness
            .light, // Icons on status bar (time, wifi, etc.) should be light
        systemNavigationBarColor: const Color(
            0xFF121212), // Match background color or make transparent
        systemNavigationBarIconBrightness: Brightness
            .light, // Icons on navigation bar (back, home, etc.) should be light
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // --- Map Area --- Conditional visibility
            if (!(_isRecording && _showStatsScreen))
              Stack(
                children: [
                  Container(
                      color: Colors.black), // Background to prevent white flash
                  _hasLocationPermission
                      ? mb.MapWidget(
                          key: const ValueKey("mapbox_map_record"),
                          styleUri: mb.MapboxStyles.STANDARD,
                          cameraOptions: _initialCameraOptions,
                          onMapCreated: _onMapCreated,
                          onScrollListener: null,
                          onTapListener: null,
                          onStyleLoadedListener: _onStyleLoadedListener,
                        )
                      : Container(
                          color: Colors.grey[850],
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.location_off,
                                    size: 48, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text(
                                  'Konum izni gerekiyor',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _initPermissions,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFC4FF62),
                                    foregroundColor: Colors.black,
                                  ),
                                  child: const Text('İzin Ver'),
                                ),
                              ],
                            ),
                          ),
                        ),
                ],
              ),
            // UI Elementleri
            _showStatsScreen
                ? Column(
                    // If stats screen, Column directly in Stack (no SafeArea here)
                    children: [
                      Expanded(
                        child: RecordStatsScreen(
                          durationSeconds: _seconds,
                          distanceKm: _distance,
                          steps: _steps,
                          calories: _calories,
                          isPaused: _isPaused,
                          onPauseToggle: _togglePause,
                          onLocationViewToggle: () {
                            setState(() {
                              _showStatsScreen = false;
                            });
                          },
                          onFinishRecording:
                              _finishRecordingAndHideStats, // Ensure this is passed
                        ),
                      ),
                    ],
                  )
                : SafeArea(
                    // If map view, wrap its content in SafeArea
                    child: Column(
                      children: [
                        // --- MOVED: Activity Type Selection Card ---
                        if (!_isRecording &&
                            !_showStatsScreen) // CORRECTED: Show only when not recording AND not on stats screen
                          Container(
                            margin: const EdgeInsets.only(
                                bottom: 8.0, // Reduced bottom margin
                                left: 16.0,
                                right: 16.0,
                                top: 8.0), // Added top margin
                            padding: const EdgeInsets.symmetric(
                                vertical: 6.0, horizontal: 12.0),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 0, 0, 0)
                                  .withOpacity(0.7), // Slightly less opaque
                              borderRadius: BorderRadius.circular(16.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildActivityTypeButton(
                                    'Running',
                                    Icons.directions_run,
                                    _activityType == 'Running',
                                    () => _selectActivityType('Running')),
                                _buildActivityTypeButton(
                                    'Walking',
                                    Icons.directions_walk,
                                    _activityType == 'Walking',
                                    () => _selectActivityType('Walking')),
                                _buildActivityTypeButton(
                                    'Cycling',
                                    Icons.directions_bike,
                                    _activityType == 'Cycling',
                                    () => _selectActivityType('Cycling')),
                              ],
                            ),
                          ),
                        // --- END OF MOVED Activity Type Selection Card ---

                        // Original layout when _showStatsScreen is false (map view)
                        if (_isRecording && !_showStatsScreen)
                          Container(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 8.0, vertical: 2.0),
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(149, 0, 0, 0),
                              borderRadius: BorderRadius.circular(16.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Running time',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            Color.fromARGB(248, 255, 255, 255),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatTime(_seconds),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromARGB(221, 255, 255, 255),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStat(
                                      iconAsset: 'assets/icons/location.png',
                                      value: _distance.toStringAsFixed(2),
                                      unit: 'km',
                                    ),
                                    _buildStat(
                                      iconAsset: 'assets/icons/alev.png',
                                      value: _calories.toString(),
                                      unit: 'kcal',
                                    ),
                                    const SizedBox(width: 8),
                                    _buildStat(
                                      iconAsset: 'assets/icons/steps.png',
                                      value: _steps.toString(),
                                      unit: 'steps',
                                    ),
                                    _buildStat(
                                      iconAsset: 'assets/icons/speed.png',
                                      value: _pace.toStringAsFixed(1),
                                      unit: 'km/hr',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        if (!_showStatsScreen)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0, horizontal: 8.0),
                                      child: GestureDetector(
                                        onTap: _toggleRecording,
                                        child: AnimatedBuilder(
                                          animation: _pulseAnimation,
                                          builder: (context, child) {
                                            return Transform.scale(
                                              scale: _isRecording && !_isPaused
                                                  ? _pulseAnimation.value
                                                  : 1.0,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 70,
                                                    height: 70,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: _isRecording
                                                          ? Colors.red
                                                          : const Color(
                                                              0xFFC4FF62),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: (_isRecording
                                                                  ? Colors.red
                                                                  : const Color(
                                                                      0xFFC4FF62))
                                                              .withOpacity(0.5),
                                                          blurRadius:
                                                              _isRecording
                                                                  ? 20
                                                                  : 10,
                                                          spreadRadius:
                                                              _isRecording
                                                                  ? 5
                                                                  : 0,
                                                        ),
                                                      ],
                                                    ),
                                                    child: Icon(
                                                      _isRecording
                                                          ? Icons.stop
                                                          : Icons
                                                              .fiber_manual_record,
                                                      color: Colors.black,
                                                      size: 35,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withOpacity(0.6),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    child: Text(
                                                      _isRecording
                                                          ? 'Finish'
                                                          : 'Record',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    if (_isRecording)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8.0, horizontal: 8.0),
                                        child: GestureDetector(
                                          onTap: _togglePause,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 70,
                                                height: 70,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: _isPaused
                                                      ? const Color(0xFF4CAF50)
                                                      : Colors.amber,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: (_isPaused
                                                              ? const Color(
                                                                  0xFF4CAF50)
                                                              : Colors.amber)
                                                          .withOpacity(0.5),
                                                      blurRadius: 10,
                                                      spreadRadius: 0,
                                                    ),
                                                  ],
                                                ),
                                                child: Icon(
                                                  _isPaused
                                                      ? Icons.play_arrow
                                                      : Icons.pause,
                                                  color: Colors.black,
                                                  size: 35,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withOpacity(0.6),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  _isPaused
                                                      ? 'Resume'
                                                      : 'Pause',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
            // Konum butonu (Sağ Alt)
            if (_hasLocationPermission &&
                !(_isRecording && _showStatsScreen)) // Show only on map view
              Positioned(
                right: 16,
                bottom: 140,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  onPressed: _getCurrentLocation,
                  child: const Icon(Icons.my_location),
                ),
              ),
            // İstatistik/Harita geçiş butonu (Sol Alt)
            if (_isRecording &&
                !_showStatsScreen) // Show only when recording AND map is visible
              Positioned(
                left: 16,
                bottom: 140,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor:
                      _showStatsScreen ? Colors.grey : const Color(0xFFC4FF62),
                  foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                  onPressed: () {
                    setState(() {
                      _showStatsScreen = !_showStatsScreen;
                    });
                  },
                  child: Icon(
                      _showStatsScreen ? Icons.map_outlined : Icons.bar_chart),
                ),
              ),
          ], // This is the closing bracket for the main Stack's children
        ), // This is the closing bracket for the main Stack
      ), // This is the closing bracket for the Scaffold
    ); // This is the closing bracket for the AnnotatedRegion
  }

  Widget _buildActivityTypeButton(
      String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? const Color(0xFFC4FF62) : Colors.grey[200],
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.black : Colors.grey[600],
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? const Color.fromARGB(255, 255, 255, 255)
                  : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Adım sayar başlatma fonksiyonu
  void _initPedometer() {
    _stepCountSubscription?.cancel(); // Cancel any existing subscription

    print('RecordScreen - Pedometer başlatılıyor...');

    try {
      // Sensörleri uyandırmak için kısa bir bekleme ekle
      Future.delayed(const Duration(milliseconds: 100), () {
        _stepCountSubscription =
            Pedometer.stepCountStream.listen((StepCount event) {
          print('RecordScreen - Adım olayı alındı: ${event.steps}');

          if (!mounted || !_isRecording || _isPaused) {
            print(
                'RecordScreen - Adım kaydedilmedi: kayıt aktif değil veya duraklatılmış');
            return;
          }

          setState(() {
            // İlk adım sayısını kaydetmek için _initialSteps'i kullan
            if (_initialSteps == 0 && event.steps > 0) {
              _initialSteps = event.steps;
              _steps = 0; // Başlangıçta adımları sıfırla
              print('RecordScreen - Başlangıç adımları: $_initialSteps');
            } else if (_initialSteps > 0) {
              // Sadece initialSteps ayarlandıktan sonra adımları hesapla
              _steps = event.steps - _initialSteps;
              if (_steps < 0) {
                _steps = 0; // Negatif adıma düşmesini engelle (cihaz reset vb.)
              }
              print(
                  'RecordScreen - Güncel adım: ${event.steps}, Başlangıç: $_initialSteps, Hesaplanan: $_steps');
            }
          });
        }, onError: (error) {
          print('RecordScreen - Adım sayar hatası: $error');

          // iOS için özel hata mesajı
          if (Platform.isIOS) {
            print(
                'RecordScreen - iOS için Health Kit izni tekrar kontrol ediliyor');
          }
        }, onDone: () {
          print('RecordScreen - Adım sayar stream kapandı');
        });

        // Eğer stream başlatıldı, ancak 5 saniye içinde veri gelmezse tekrar başlat
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _isRecording && _initialSteps == 0) {
            print(
                'RecordScreen - 5 saniye içinde adım verisi gelmedi, stream yeniden başlatılıyor');
            _stepCountSubscription?.cancel();
            _initPedometer(); // Tekrar dene
          }
        });
      });
    } catch (e) {
      print('RecordScreen - Pedometer başlatma hatası: $e');
      // Hata durumunda kullanıcıya bilgi verme
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Adım sayar başlatılırken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- YENİ YARDIMCI FONKSİYON: Coin Kazanma Popup'ı ---
  void _showCoinPopup(BuildContext context, double coins) {
    // Zaten bir dialog açık mı kontrol et (isteğe bağlı, çift popup engelleme)
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      showDialog(
        context: context,
        barrierDismissible: false, // Dışarı tıklayarak kapatmayı engelle
        builder: (BuildContext dialogContext) {
          return EarnCoinPopup(
            earnedCoin: coins,
            onGoHomePressed: () {
              Navigator.of(dialogContext).pop(); // Önce popup'ı kapat
              // Ana sayfaya (Tab 0) yönlendir
              ref.read(selectedTabProvider.notifier).state = 0;
              print("Ana sayfaya yönlendirildi (Tab 0).");
            },
          );
        },
      );
    }
  }
  // --- Coin popup fonksiyonu sonu ---

  // New method to initialize the dedicated calorie calculation timer
  void _initializeCalorieCalculation() {
    _calorieCalculationTimer?.cancel();
    _calorieCalculationTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_isRecording && !_isPaused) {
        _calculateCalories();
      } else {
        timer.cancel();
        _calorieCalculationTimer = null;
      }
    });
  }

  // Updated calorie calculation method (adapted from RaceProvider)
  void _calculateCalories() {
    final now = DateTime.now();

    if (_lastCalorieCalculationTime == null) {
      _lastDistance = _distance;
      _lastSteps = _steps;
      _lastCalorieCalculationTime = now;
      setState(() {
        _calories = 0; // Initialize calories if it's the first calculation
      });
      return;
    }

    final elapsedSeconds =
        now.difference(_lastCalorieCalculationTime!).inSeconds;
    if (elapsedSeconds < 4) return; // Match RaceProvider's check (for 5s timer)

    final distanceDifference = _distance - _lastDistance;
    final stepsDifference = _steps - _lastSteps;
    final bool isMoving = distanceDifference > 0.001 || stepsDifference > 0;
    final double currentPaceKmH = distanceDifference > 0 && elapsedSeconds > 0
        ? (distanceDifference) / (elapsedSeconds / 3600.0)
        : 0;

    final userData = ref.read(userDataProvider).value;
    double weightKg = 70.0; // Default weight
    double heightCm = 170.0; // Default height
    int ageYears = 25; // Default age
    String gender = 'male'; // Default gender

    if (userData != null) {
      weightKg = (userData.weight != null && userData.weight! > 0)
          ? userData.weight!
          : weightKg;
      heightCm = (userData.height != null && userData.height! > 0)
          ? userData.height!
          : heightCm;
      ageYears = (userData.age != null && userData.age! > 0)
          ? userData.age!
          : ageYears;
      gender = userData.gender?.toLowerCase() == 'female' ? 'female' : 'male';
      debugPrint(
          'RecordScreen Calorie Calc - User Data: Weight=$weightKg, Height=$heightCm, Age=$ageYears, Gender=$gender');
    } else {
      debugPrint('RecordScreen Calorie Calc - Using default user data.');
    }

    double bmr; // Basal Metabolic Rate (Mifflin-St Jeor)
    if (gender == 'female') {
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears) - 161;
    } else {
      // male or default
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears) + 5;
    }
    if (bmr < 0) bmr = 0; // Ensure BMR is not negative
    debugPrint(
        'RecordScreen Calorie Calc - Calculated BMR (per day): ${bmr.toStringAsFixed(2)}');

    double metValue; // Metabolic Equivalent of Task
    if (!isMoving) {
      metValue = 1.0; // Resting MET
    } else {
      // Determine MET based on activity type and pace (assuming outdoor/GPS-based)
      if (_activityType == 'Running' || _activityType == 'Walking') {
        if (currentPaceKmH < 3.2) {
          metValue = 2.0;
        } // ~2.0 mph (Slow walking)
        else if (currentPaceKmH < 4.8) {
          metValue = 3.0;
        } // ~3.0 mph (Moderate walking)
        else if (currentPaceKmH < 6.4) {
          metValue = 3.8;
        } // ~4.0 mph (Very brisk walking)
        else if (currentPaceKmH < 8.0) {
          metValue = 8.3;
        } // ~5.0 mph (Light jog)
        else if (currentPaceKmH < 9.7) {
          metValue = 9.8;
        } // ~6.0 mph (Moderate run)
        else if (currentPaceKmH < 11.3) {
          metValue = 11.0;
        } // ~7.0 mph
        else if (currentPaceKmH < 12.9) {
          metValue = 11.8;
        } // ~8.0 mph
        else if (currentPaceKmH < 14.5) {
          metValue = 12.8;
        } // ~9.0 mph
        else if (currentPaceKmH < 16.0) {
          metValue = 14.5;
        } // ~10.0 mph
        else if (currentPaceKmH < 17.5) {
          metValue = 16.0;
        } // ~11.0 mph
        else {
          metValue = 19.0;
        } // ~12.0 mph+
        debugPrint(
            'RecordScreen Calorie Calc ($_activityType based on GPS) - MET: $metValue, Pace: ${currentPaceKmH.toStringAsFixed(2)} km/h');
      } else if (_activityType == 'Cycling') {
        if (currentPaceKmH < 16.0)
          metValue = 4.0; // Leisurely cycling
        else if (currentPaceKmH < 20.0)
          metValue = 6.8; // Moderate cycling
        else if (currentPaceKmH < 24.0)
          metValue = 8.0;
        else
          metValue = 10.0; // Faster cycling
        debugPrint(
            'RecordScreen Calorie Calc (Cycling based on GPS) - MET: $metValue, Pace: ${currentPaceKmH.toStringAsFixed(2)} km/h');
      } else {
        metValue = 5.0; // Default generic MET for other types
        debugPrint(
            'RecordScreen Calorie Calc (Unknown Activity: $_activityType) - Default MET: $metValue, Pace: ${currentPaceKmH.toStringAsFixed(2)} km/h');
      }
    }

    double bmrPerSecond = bmr / (24 * 60 * 60);
    int newCalories = (bmrPerSecond * elapsedSeconds * metValue).round();
    if (newCalories < 0) newCalories = 0;

    setState(() {
      _calories += newCalories;
    });

    debugPrint(
        'RecordScreen 🔥 Kalori hesaplandı (Yeni): +$newCalories kal (Toplam: $_calories) - BMR: ${bmr.toStringAsFixed(0)}, MET: $metValue, Hız: ${currentPaceKmH.toStringAsFixed(2)} km/h, Aktivite: $_activityType');

    // Update last check values
    _lastDistance = _distance;
    _lastSteps = _steps;
    _lastCalorieCalculationTime = now;
  }

  // Aktiviteyi zorla durdur ve sıfırla
  void _forceStopAndResetActivity() {
    if (!mounted) return;

    debugPrint('RecordScreen: _forceStopAndResetActivity çağrıldı.');
    setState(() {
      _isRecording = false;
      _isPaused = false;

      _pulseController.stop();
      _pulseController.reset();

      _timer?.cancel();
      _timer = null;
      _calorieCalculationTimer?.cancel();
      _stopLocationTracking();
      _stepCountSubscription?.cancel();
      _stepCountSubscription = null;

      _seconds = 0;
      _distance = 0.0;
      _calories = 0;
      _pace = 0.0;
      _steps = 0;
      _initialSteps = 0;
      _startTime = null;
      _lastCalorieCalculationTime = null;

      _mapboxRouteCoordinates = [];
      _polylineAnnotationManager?.deleteAll().catchError(
          (e) => print("Error deleting polylines on force stop: $e"));
      if (_currentLocationMarker != null) {
        _pointAnnotationManager?.delete(_currentLocationMarker!).catchError(
            (e) => print("Error deleting marker on force stop: $e"));
        _currentLocationMarker = null;
      }
      _currentMapboxPoint = null;
      _currentGeoPosition = null;
      _mapboxMap?.flyTo(
          _initialCameraOptions, mb.MapAnimationOptions(duration: 1000));
    });
    // ref.read(recordStateProvider.notifier).forceStop(); // Bu metod RecordStateNotifier'da yoksa yorumda kalsın
  }

  void _onMapCreated(mb.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    debugPrint('MapboxMap oluşturuldu ve _mapboxMap atandı.');
    // Annotation manager oluşturma ve _getCurrentLocation çağrısı onStyleLoadedListener içine taşındı.
  }

  void _onStyleLoadedListener(dynamic data) async {
    debugPrint(
        'RecordScreen: _onStyleLoadedListener çağrıldı - Stil yüklendi. Gelen data runtimeType: ${data.runtimeType}');
    if (_mapboxMap == null) {
      debugPrint(
          'RecordScreen: _onStyleLoadedListener - _mapboxMap null, işlem yapılamıyor.');
      return;
    }
    try {
      _pointAnnotationManager =
          await _mapboxMap!.annotations.createPointAnnotationManager();
      debugPrint(
          'PointAnnotationManager oluşturuldu ve atandı. Manager: ${_pointAnnotationManager}');
    } catch (e) {
      debugPrint('PointAnnotationManager oluşturulurken HATA: $e');
    }

    try {
      _polylineAnnotationManager =
          await _mapboxMap!.annotations.createPolylineAnnotationManager();
      debugPrint(
          'PolylineAnnotationManager oluşturuldu ve atandı. Manager: ${_polylineAnnotationManager}');
    } catch (e) {
      debugPrint('PolylineAnnotationManager oluşturulurken HATA: $e');
    }

    // _getCurrentLocation çağrısını 500ms geciktir
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !(_isRecording || _isPaused)) {
        debugPrint(
            "RecordScreen: _onStyleLoadedListener - Gecikmeli _getCurrentLocation çağrılıyor.");
        _getCurrentLocation();
      }
    });
    debugPrint('MapboxMap stili yüklendi ve annotation managerlar ayarlandı.');
  }

  Future<void> _requestPermissions() async {
    // Bu fonksiyon artık sadece _initPermissions'ı çağırmalı
    // veya _initPermissions'ın içeriğini buraya taşımalıyız.
    // Şimdilik _initPermissions'ı çağıralım ve içindeki eski marker/map
    // mantığının _initPermissions içerisinde doğru yönetildiğinden emin olalım.
    // _initPermissions zaten initState içinde gecikmeli çağrılıyor,
    // bu fonksiyonun initState'den direkt çağrılmasına gerek kalmadı.
    // Eğer bu fonksiyon başka bir yerden çağrılıyorsa, o çağrıyı _initPermissions'a yönlendirmek daha doğru olabilir.
    // Şimdilik bu fonksiyonu boş bırakıyorum, çünkü _initPermissions zaten görevini yapıyor.
    // Eğer harici bir çağrısı varsa, orayı düzeltmek gerekir.
    // Loglardan gördüğüm kadarıyla initState'den çağrılıyordu ve _initPermissions da oradan çağrılıyor.
    // Bu yüzden bu fonksiyonun içeriğini boşaltmak ve initState'deki çağrısını kaldırmak en temizi olacak.
    debugPrint(
        "RecordScreen: _requestPermissions çağrıldı - Artık sadece _initPermissions'ı tetiklemeli (veya _initPermissions içeriğini almalı). Mevcut durumda _initPermissions zaten initState'de yönetiliyor.");
    // _initPermissions(); // _initPermissions zaten initState'de gecikmeli çağrılıyor.
  }

  void _onTapListener(mb.ScreenCoordinate coordinate) {
    if (kDebugMode) {
      print('Map tapped at: ${coordinate.x}, ${coordinate.y}');
    }
    // Example: Convert screen coordinate to map coordinate and log
    // This requires the map controller (_mapboxMap) to be initialized
    _mapboxMap
        ?.pixelForCoordinate(mb.Point(
            coordinates:
                mb.Position(coordinate.x.toDouble(), coordinate.y.toDouble())))
        .then((point) {
      if (kDebugMode) {
        print('Map coordinate: ${point.encode()}');
      }
    }).catchError((e) {
      if (kDebugMode) {
        print('Error converting screen coordinate to map coordinate: $e');
      }
    });
  }

  void _onScrollListener(mb.ScreenCoordinate coordinate) {
    // For simplicity, we're not doing much with scroll events here
    // but you could use them to detect map interaction.
    // if (kDebugMode) {
    //   print('Map scrolled to: ${coordinate.x}, ${coordinate.y}');
    // }
  }

  void _onCameraChangeListener(mb.CameraChangedEventData event) {
    // You can get the new camera state from event.cameraState
    // For example, to get the new zoom level:
    // final newZoom = event.cameraState.zoom;
    // if (kDebugMode) {
    //   print("Camera new zoom: $newZoom");
    // }
    // _currentZoomLevel = newZoom; // Update current zoom level
  }
}
