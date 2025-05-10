import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pedometer/pedometer.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/record_request_model.dart';
import '../providers/record_provider.dart';
import '../providers/user_data_provider.dart';
import '../providers/recording_state_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isPaused = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Timer related properties
  int _seconds = 0;
  Timer? _timer;
  double _distance = 0.0;
  int _calories = 0;
  double _pace = 0.0;
  DateTime? _startTime;

  // Selected activity type
  String _activityType = 'Running';

  // Google Maps related properties
  GoogleMapController? _mapController;
  Position? _currentPosition;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> _routeCoordinates = [];
  bool _hasLocationPermission = false;
  StreamSubscription<Position>? _positionStreamSubscription;

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

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(41.0082, 28.9784), // İstanbul koordinatları (varsayılan)
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
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
    _positionStreamSubscription?.cancel();
    _stepCountSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
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
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
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
      await Geolocator.openLocationSettings();
      return;
    }

    // Önce izinleri kontrol et - zaten verilmişse istemek zorunda kalma
    if (Platform.isIOS) {
      // iOS için Geolocator ile izin kontrolü
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always || 
          permission == LocationPermission.whileInUse) {
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
        if (!stepsAvailable && mounted) {
          
        }
      } catch (e) {
        print('RecordScreen - Pedometer başlatma hatası: $e');
        // Hata durumunda dialog göster
        if (mounted) {
          
        }
      }
    }
  }

  // Health Kit izni için özel dialog (iOS)
  

  // Konum izinlerini kontrol eden fonksiyon
  Future<void> _checkLocationPermission() async {
    print('RecordScreen - Konum izni kontrolü başlatılıyor...');
    
    if (Platform.isIOS) {
      // iOS için: Geolocator'ı doğrudan kullan (daha iyi çalışıyor)
      LocationPermission permission = await Geolocator.checkPermission();
      print('RecordScreen - iOS konum izni durumu: $permission');
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('RecordScreen - iOS konum izni istendikten sonra: $permission');
      }
      
      // LocationPermission.whileInUse ve LocationPermission.always her ikisi de yeterli
      setState(() {
        _hasLocationPermission = permission == LocationPermission.whileInUse || 
                                 permission == LocationPermission.always;
      });
      
      print('RecordScreen - iOS konum izni var mı?: $_hasLocationPermission');
      
      if (_hasLocationPermission) {
        // İzin varsa konumu al
        await _getCurrentLocation();
      } else if (permission == LocationPermission.denied || 
                 permission == LocationPermission.deniedForever) {
        
      }
    } else {
      // Android için: Permission.locationAlways kullanmaya devam et
      final status = await Permission.locationAlways.status;
      print('RecordScreen - Android konum izni durumu: $status');
      
      // Eğer izin henüz verilmemişse iste
      if (!status.isGranted && !status.isLimited) {
        final requestedStatus = await Permission.locationAlways.request();
        print('RecordScreen - Android izin istendikten sonra: $requestedStatus');
        
        setState(() {
          _hasLocationPermission = requestedStatus.isGranted || requestedStatus.isLimited;
        });
        
        if (!_hasLocationPermission && (requestedStatus.isDenied || requestedStatus.isPermanentlyDenied)) {
          
        }
      } else {
        setState(() {
          _hasLocationPermission = true;
        });
      }
      
      print('RecordScreen - Android konum izni var mı?: $_hasLocationPermission');
      
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
      print('Konum alınıyor...');
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      print('Konum alındı: ${position.latitude}, ${position.longitude}');

      setState(() {
        _currentPosition = position;

        // Haritaya mevcut konum için marker ekle
        _markers.add(
          Marker(
            markerId: const MarkerId('currentLocation'),
            position: LatLng(position.latitude, position.longitude),
            infoWindow: const InfoWindow(title: 'Konumunuz'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
          ),
        );

        // Rota listesine başlangıç noktası olarak ekle
        _routeCoordinates.add(LatLng(position.latitude, position.longitude));
      });

      // Harita varsa kamerayı kullanıcının konumuna getir
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude), 18));
    } catch (e) {
      print('Konum alınamadı: $e');
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

      // --- Platforma Özel LocationSettings ---
      LocationSettings locationSettings;

      if (Platform.isAndroid) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          // intervalDuration: const Duration(seconds: 10), // Optional
          foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationText:
                  "Movliq aktivitenizi kaydederken konumunuzu takip ediyor.",
              notificationTitle: "Movliq Kayıt Devam Ediyor",
              enableWakeLock: true,
              notificationIcon: AndroidResource(
                  name: 'launcher_icon', defType: 'mipmap') // App icon
              ),
        );
      } else if (Platform.isIOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.high,
          activityType: ActivityType.fitness, // Specify activity type
          distanceFilter: 5,
          pauseLocationUpdatesAutomatically:
              false, // Prevent iOS from pausing updates
          showBackgroundLocationIndicator:
              true, // Show blue indicator bar on iOS
        );
      } else {
        // Default settings for other platforms
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        );
      }
      // --- Platforma Özel LocationSettings Bitişi ---

      // En az 5 metrede bir konum güncellemesi al
      _positionStreamSubscription = Geolocator.getPositionStream(
        // Güncellenmiş locationSettings'i kullan
        locationSettings: locationSettings,
      ).listen((Position position) {
        print('Konum güncellendi: ${position.latitude}, ${position.longitude}');
        if (mounted && _isRecording && !_isPaused) {
          // Only update if recording and not paused
          setState(() {
            // Eski konum varsa, iki nokta arasındaki mesafeyi hesapla
            if (_currentPosition != null) {
              double newDistance = Geolocator.distanceBetween(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                position.latitude,
                position.longitude,
              );

              // Kilometre cinsine çevirip toplam mesafeye ekle
              _distance += newDistance / 1000;
            }

            _currentPosition = position;

            // Rota listesine yeni konum ekle
            LatLng newPosition = LatLng(position.latitude, position.longitude);
            _routeCoordinates.add(newPosition);

            // Marker pozisyonunu güncelle
            _markers = {
              Marker(
                markerId: const MarkerId('currentLocation'),
                position: newPosition,
                infoWindow: const InfoWindow(title: 'Konumunuz'),
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen),
              )
            };

            // Polyline'ı güncelle
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                points: _routeCoordinates,
                color: const Color(0xFFC4FF62),
                width: 5,
              )
            };

            // Harita varsa kamerayı kullanıcının konumuna getir
            _mapController?.animateCamera(CameraUpdate.newLatLng(newPosition));
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
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  void _toggleRecording() {
    if (_isRecording) {
      // Finishing recording
      _finishRecording();
    } else {
      // Starting recording
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
      _routeCoordinates = [];
      _polylines = {};
      _lastCalorieCalculationTime = null;

      _pulseController.forward();

      // Start timer
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_isPaused && _isRecording) {
          setState(() {
            _seconds++;
            // Her 10 saniyede bir kalori hesapla
            if (_seconds % 10 == 0) {
              _calculateCalories();
              // Calculate pace (km/h)
              _pace = _seconds > 0 ? (_distance / (_seconds / 3600.0)) : 0;
            }
          });
        }
      });

      // Start GPS tracking
      _startLocationTracking();
      // Start pedometer if permission granted
      if (_hasPedometerPermission) {
        _initPedometer();
      }
    });
    // Notify the state provider
    ref
        .read(recordStateProvider.notifier)
        .startRecording(_forceStopAndResetActivity);
  }

  void _finishRecording() {
    // Save final values before resetting
    final int finalDuration = _seconds;
    final double finalDistance = _distance;
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
      _pulseController.stop();
      _pulseController.reset();

      // Stop timer
      _timer?.cancel();

      // Stop GPS tracking
      _stopLocationTracking();

      // Reset activity data
      _seconds = 0;
      _distance = 0.0;
      _calories = 0;
      _pace = 0.0;
      _steps = 0;
      _startTime = null;

      // Clear map route data
      _routeCoordinates = [];
      _polylines = {};

      // Clear markers except current location
      if (_currentPosition != null) {
        _markers = {
          Marker(
            markerId: const MarkerId('currentLocation'),
            position:
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            infoWindow: const InfoWindow(title: 'Konumunuz'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
          )
        };
      } else {
        _markers = {};
      }

      // Get current location again and center map on it
      _getCurrentLocation();
    });

    // Notify the state provider
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
        (response) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aktivite başarıyla kaydedildi!'),
              backgroundColor: Colors.green,
            ),
          );
          print("💰 Coins fetched after successful activity record.");
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
        // Timer'ı durdurmuyoruz, _startRecording içindeki if kontrolü yeterli.
        // _timer?.cancel();
        // Konum takibi için de benzer bir mantık, _positionStreamSubscription.pause() daha iyi olabilir.
        // Şimdilik _stopLocationTracking() ve _startLocationTracking() kalsın.
        _stopLocationTracking();
        _stepCountSubscription?.pause(); // Pause pedometer
      } else {
        // Resume recording
        _pulseController.forward();
        // Timer zaten devam ediyor.
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
    required IconData icon,
    required String value,
    required String unit,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 26,
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
    return Scaffold(
      body: Stack(
        children: [
          // --- Map Area with Dark Style Handling ---
          Stack(
            children: [
              // Black background to prevent white flash
              Container(color: Colors.black),
              _hasLocationPermission
                  ? AnimatedOpacity(
                      opacity: _isMapStyleSet ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: GoogleMap(
                        mapType: MapType.normal,
                        initialCameraPosition: _initialCameraPosition,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        compassEnabled: true,
                        markers: _markers,
                        polylines: _polylines,
                        onMapCreated: (GoogleMapController controller) async {
                          _mapController = controller;
                          try {
                            print("Applying dark map style...");
                            await _mapController
                                ?.setMapStyle(_darkMapStyleJson);
                            print("Dark map style applied successfully.");
                            if (mounted) {
                              setState(() {
                                _isMapStyleSet = true;
                              });
                            }
                          } catch (e) {
                            print("Error applying map style: $e");
                            // If style fails, still show the map
                            if (mounted) {
                              setState(() {
                                _isMapStyleSet = true;
                              });
                            }
                          }
                          // Get location AFTER style attempt
                          if (_hasLocationPermission && mounted) {
                            await _getCurrentLocation();
                          }
                        },
                      ),
                    )
                  : Container(
                      // Placeholder if no location permission
                      color: Colors.grey[850], // Dark grey placeholder
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
          SafeArea(
            child: Column(
              children: [
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
                      // Title row with optional pause button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Running time',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color.fromARGB(248, 255, 255, 255),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Large time display
                      Text(
                        _formatTime(_seconds),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(221, 255, 255, 255),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Statistics row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Distance
                          _buildStat(
                            icon: Icons.directions_run,
                            value: _distance.toStringAsFixed(2),
                            unit: 'km',
                            iconColor: Colors.orange,
                          ),

                          // Calories
                          _buildStat(
                            icon: Icons.local_fire_department,
                            value: _calories.toString(),
                            unit: 'kcal',
                            iconColor: Colors.red,
                          ),
                          const SizedBox(width: 8),

                          // Steps
                          _buildStat(
                            icon: Icons.do_not_step_outlined,
                            value: _steps.toString(),
                            unit: 'steps',
                            iconColor: Colors.green,
                          ),

                          // Pace
                          _buildStat(
                            icon: Icons.bolt,
                            value: _pace.toStringAsFixed(1),
                            unit: 'km/hr',
                            iconColor: Colors.blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Boş alan
                const Spacer(),

                // Butonlar ve Aktivite Seçimi
                Column(
                  children: [
                    // Record Button and Pause Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Record Button
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
                                              : const Color(0xFFC4FF62),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (_isRecording
                                                      ? Colors.red
                                                      : const Color(0xFFC4FF62))
                                                  .withOpacity(0.5),
                                              blurRadius:
                                                  _isRecording ? 20 : 10,
                                              spreadRadius:
                                                  _isRecording ? 5 : 0,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          _isRecording
                                              ? Icons.stop
                                              : Icons.fiber_manual_record,
                                          color: Colors.black,
                                          size: 35,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          _isRecording ? 'Finish' : 'Record',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
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

                        // Pause Button - only visible when recording
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
                                                  ? const Color(0xFF4CAF50)
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
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _isPaused ? 'Resume' : 'Pause',
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

                    // Activity Type Selection
                    Container(
                      margin: const EdgeInsets.only(
                          bottom: 16.0, left: 16.0, right: 16.0, top: 8.0),
                      padding: const EdgeInsets.symmetric(
                          vertical: 6.0, horizontal: 12.0),
                      decoration: BoxDecoration(
                        color:
                            const Color.fromARGB(255, 0, 0, 0).withOpacity(0.9),
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
                  ],
                ),
              ],
            ),
          ),

          // Konum butonu
          if (_hasLocationPermission)
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
        ],
      ),
    );
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
        _stepCountSubscription = Pedometer.stepCountStream.listen(
          (StepCount event) {
            print('RecordScreen - Adım olayı alındı: ${event.steps}');
            
            if (!mounted || !_isRecording || _isPaused) {
              print('RecordScreen - Adım kaydedilmedi: kayıt aktif değil veya duraklatılmış');
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
                print('RecordScreen - Güncel adım: ${event.steps}, Başlangıç: $_initialSteps, Hesaplanan: $_steps');
              }
            });
          },
          onError: (error) {
            print('RecordScreen - Adım sayar hatası: $error');
            
            // iOS için özel hata mesajı
            if (Platform.isIOS) {
              print('RecordScreen - iOS için Health Kit izni tekrar kontrol ediliyor');
            }
          },
          onDone: () {
            print('RecordScreen - Adım sayar stream kapandı');
          }
        );
        
        // Eğer stream başlatıldı, ancak 5 saniye içinde veri gelmezse tekrar başlat 
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _isRecording && _initialSteps == 0) {
            print('RecordScreen - 5 saniye içinde adım verisi gelmedi, stream yeniden başlatılıyor');
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

  // Yeni kalori hesaplama metodu
  void _calculateCalories() {
    final now = DateTime.now();

    // İlk kalori hesaplaması ise, başlangıç değerlerini kaydet
    if (_lastCalorieCalculationTime == null) {
      _lastDistance = _distance;
      _lastSteps = _steps;
      _lastCalorieCalculationTime = now;
      setState(() {
        _calories = 0;
      });
      return;
    }

    // Son hesaplamadan bu yana geçen süre (saniye)
    final elapsedSeconds =
        now.difference(_lastCalorieCalculationTime!).inSeconds;
    if (elapsedSeconds < 1) return; // Avoid rapid recalculation

    // Son hesaplamadan bu yana kat edilen mesafe ve adım farkı
    final distanceDifference = _distance - _lastDistance;
    final stepsDifference = _steps - _lastSteps;

    // Hareket tespiti
    final bool isMoving = distanceDifference > 0.001 || stepsDifference > 0;

    debugPrint(
        '📊 Hareket kontrolü: Mesafe farkı=${distanceDifference.toStringAsFixed(4)} km, Adım farkı=$stepsDifference, Hareket=${isMoving ? "VAR" : "YOK"}');

    // Son periyottaki anlık hızı hesapla (km/saat)
    // distanceDifference km cinsinden, elapsedSeconds saniye cinsinden
    final double currentPaceKmH = distanceDifference > 0 && elapsedSeconds > 0
        ? (distanceDifference) / (elapsedSeconds / 3600.0)
        : 0;
    debugPrint('⚡ Anlık Hız: ${currentPaceKmH.toStringAsFixed(2)} km/h');

    // UserDataProvider'dan kullanıcı verilerini al
    final userDataAsync = ref.read(userDataProvider);

    userDataAsync.whenOrNull(
      data: (userData) {
        if (userData != null) {
          final weight = userData.weight ?? 70.0;
          final height = userData.height ?? 170.0;

          // Aktivite tipine ve ANLIK HIZA göre MET değeri belirle
          // TODO: Bu MET değerlerini Compendium of Physical Activities (CPA) gibi güvenilir bir kaynaktan almak daha doğru olur.
          double metValue;

          if (!isMoving) {
            metValue = 1.0; // Resting MET
          } else {
            switch (_activityType) {
              case 'Running':
                // Anlık koşu hızına göre MET
                if (currentPaceKmH < 6.5)
                  metValue = 6.0; // ~10 min/mile or slower
                else if (currentPaceKmH < 8.0)
                  metValue = 8.3; // ~12 km/h - 7.5 min/mile
                else if (currentPaceKmH < 10.0)
                  metValue = 10.0; // ~10 km/h - 6 min/mile
                else if (currentPaceKmH < 12.0)
                  metValue = 11.5;
                else
                  metValue = 12.8; // Faster running
                break;
              case 'Walking':
                // Anlık yürüyüş hızına göre MET
                if (currentPaceKmH < 3.0)
                  metValue = 2.0; // Slow walk
                else if (currentPaceKmH < 5.0)
                  metValue = 3.0; // Moderate walk
                else if (currentPaceKmH < 6.5)
                  metValue = 3.8; // Brisk walk
                else
                  metValue = 5.0; // Very brisk walk
                break;
              case 'Cycling':
                // Anlık bisiklet hızına göre MET
                if (currentPaceKmH < 16.0)
                  metValue = 4.0; // Leisurely cycling
                else if (currentPaceKmH < 20.0)
                  metValue = 6.8; // Moderate cycling
                else if (currentPaceKmH < 24.0)
                  metValue = 8.0;
                else
                  metValue = 10.0; // Faster cycling
                break;
              default:
                metValue = 5.0; // Default generic MET
            }
          }

          // Kalori hesaplama formülü: Kalori = Ağırlık (kg) × MET değeri × Süre (saat)
          double hours = elapsedSeconds / 3600.0;
          int newCalories = (weight * metValue * hours).round();

          // BMI faktörünü kaldırdık - daha basit ve MET odaklı
          // double heightInMeters = height / 100.0;
          // double bmi = weight / (heightInMeters * heightInMeters);
          // if (bmi > 25) {
          //   double bmiFactor = 1.0 + ((bmi - 25) * 0.01);
          //   newCalories = (newCalories * bmiFactor).round();
          // }

          if (newCalories < 0) newCalories = 0;

          setState(() {
            _calories += newCalories;
          });

          debugPrint(
              'Kalori hesaplandı: +$newCalories kal eklendi (Toplam: $_calories) - Hareket: ${isMoving ? "VAR" : "YOK"}, MET: $metValue, Süre: $hours saat, Hız: ${currentPaceKmH.toStringAsFixed(2)} km/h');
        } else {
          // Kullanıcı verisi yoksa veya hata varsa fallback mantığı
          // Eski distanceDifference * 60 yerine daha tutarlı bir varsayılan MET kullanalım
          double fallbackMet =
              isMoving ? 3.5 : 1.0; // Ortalama yürüyüş veya dinlenme
          double defaultWeight = 70.0;
          double hours = elapsedSeconds / 3600.0;
          int newCalories = (defaultWeight * fallbackMet * hours).round();
          if (newCalories < 0) newCalories = 0;
          setState(() {
            _calories += newCalories;
          });
          debugPrint(
              'Kullanıcı verisi yok/hatalı, fallback hesaplama: +$newCalories kal (Toplam: $_calories) - MET: $fallbackMet');
        }
      },
      // loading ve error durumlarında da fallback mantığını kullanalım
      loading: () {
        double fallbackMet = isMoving ? 3.5 : 1.0;
        double defaultWeight = 70.0;
        double hours = elapsedSeconds / 3600.0;
        int newCalories = (defaultWeight * fallbackMet * hours).round();
        if (newCalories < 0) newCalories = 0;
        setState(() {
          _calories += newCalories;
        });
        debugPrint(
            'Kullanıcı verisi yükleniyor, fallback hesaplama: +$newCalories kal (Toplam: $_calories) - MET: $fallbackMet');
      },
      error: (_, __) {
        double fallbackMet = isMoving ? 3.5 : 1.0;
        double defaultWeight = 70.0;
        double hours = elapsedSeconds / 3600.0;
        int newCalories = (defaultWeight * fallbackMet * hours).round();
        if (newCalories < 0) newCalories = 0;
        setState(() {
          _calories += newCalories;
        });
        debugPrint(
            'Kullanıcı verisi hatası, fallback hesaplama: +$newCalories kal (Toplam: $_calories) - MET: $fallbackMet');
      },
    );

    // Son değerleri güncelle
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
      _stopLocationTracking();
      _stepCountSubscription?.cancel();
      _stepCountSubscription = null;

      // Aktivite verilerini sıfırla
      _seconds = 0;
      _distance = 0.0;
      _calories = 0;
      _pace = 0.0;
      _steps = 0;
      _initialSteps = 0;
      _startTime = null;
      _lastCalorieCalculationTime = null;

      // Harita rota verilerini temizle
      _routeCoordinates = [];
      _polylines = {};

      // Markerları temizle (mevcut konum hariç)
      if (_currentPosition != null) {
        _markers = {
          Marker(
            markerId: const MarkerId('currentLocation'),
            position:
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            infoWindow: const InfoWindow(title: 'Konumunuz'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
          )
        };
      } else {
        _markers = {};
      }
    });
  }
}
