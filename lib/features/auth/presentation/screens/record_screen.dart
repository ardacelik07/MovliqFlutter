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
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:google_fonts/google_fonts.dart';

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

  int _seconds = 0;
  Timer? _timer;
  Timer? _calorieCalculationTimer;
  double _distance = 0.0;
  int _calories = 0;
  double _pace = 0.0;
  DateTime? _startTime;

  String _activityType = 'Running';

  mb.MapboxMap? _mapboxMap;
  mb.PointAnnotationManager? _pointAnnotationManager;
  mb.PolylineAnnotationManager? _polylineAnnotationManager;
  List<mb.Point> _mapboxRouteCoordinates = [];
  mb.Point? _currentMapboxPoint;
  mb.PointAnnotation? _currentLocationMarker;
  Uint8List? _maleMarkerIcon;
  Uint8List? _femaleMarkerIcon;

  bool _hasLocationPermission = false;

  int _steps = 0;
  int _initialSteps = 0;
  StreamSubscription<StepCount>? _stepCountSubscription;
  bool _hasPedometerPermission = false;

  double _lastDistance = 0.0;
  int _lastSteps = 0;
  DateTime? _lastCalorieCalculationTime;

  final mb.CameraOptions _initialCameraOptions = mb.CameraOptions(
    center: mb.Point(coordinates: mb.Position(28.9784, 41.0082)),
    zoom: 12.0,
  );

  geo.Position? _currentGeoPosition;
  StreamSubscription<geo.Position>? _positionStreamSubscriptionGeo;

  @override
  void initState() {
    super.initState();
    _loadMarkerImage();

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

    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _checkAndRequestPermissionsSequentially();
      }
    });

    // Listen to userDataProvider for gender changes
    // Ensure this is called after _pointAnnotationManager and _mapboxMap are potentially initialized.
    // It might be better to set up this listener after _onMapCreated or _onStyleLoaded.
    // For now, we'll add a null check for managers.
    ref.listenManual(userDataProvider, (previous, next) {
      final prevGender = previous?.value?.gender;
      final String? nextGender = next.value?.gender;

      debugPrint(
          'RecordScreen: userDataProvider listener triggered. Prev gender: $prevGender, Next gender: $nextGender');

      // Check if gender actually changed or became available
      if (prevGender != nextGender && nextGender != null) {
        debugPrint(
            'RecordScreen: Gender changed from $prevGender to $nextGender or became available. Attempting to update marker icon.');
        if (_pointAnnotationManager != null && _mapboxMap != null) {
          // Ensure map and manager are ready
          // Call async function without awaiting, or make listener async if needed
          _updateMarkerIconForGenderChange();
        } else {
          debugPrint(
              'RecordScreen: userDataProvider listener - map or annotation manager not ready for icon update.');
        }
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
    _mapboxMap?.dispose();
    super.dispose();
  }

  void _finishRecordingAndHideStats() {
    _finishRecording();
    if (mounted) {
      setState(() {
        _showStatsScreen = false;
      });
    }
  }

  Future<void> _loadMarkerImage() async {
    try {
      final ByteData maleByteData =
          await rootBundle.load('assets/images/mapbox.png');
      _maleMarkerIcon = maleByteData.buffer.asUint8List();
      debugPrint('RecordScreen: _loadMarkerImage - Male marker icon LOADED.');

      final ByteData femaleByteData =
          await rootBundle.load('assets/icons/locaitonwomen.webp');
      _femaleMarkerIcon = femaleByteData.buffer.asUint8List();
      debugPrint('RecordScreen: _loadMarkerImage - Female marker icon LOADED.');

      if (mounted) {
        setState(() {});
        // If a marker already exists and icons just loaded, try to update it
        if (_currentLocationMarker != null && _pointAnnotationManager != null) {
          debugPrint(
              'RecordScreen: Icons loaded after marker existed, attempting refresh.');
          await _updateMarkerIconForGenderChange();
        }
      }
    } catch (e) {
      debugPrint(
          'RecordScreen: _loadMarkerImage - Özel işaretçi yüklenirken HATA: $e');
    }
  }

  Future<void> _checkAndRequestPermissionsSequentially() async {
    // Önce bildirim iznini iste (en kritik olmayan)

    // Sonra konum iznini iste
    await _checkAndRequestLocationPermission();

    // En son aktivite iznini iste
    if (mounted) {
      await _checkAndRequestActivityPermission();
    }
    if (mounted) {
      setState(() {}); // Refresh UI if needed after permission checks
    }
  }

  Future<bool> _requestIOSNotificationPermission() async {
    const platform = MethodChannel('com.movliq/notifications');
    try {
      final bool result =
          await platform.invokeMethod('requestNotificationPermission');
      return result;
    } catch (e) {
      debugPrint('RecordScreen - iOS bildirim izni alma hatası: $e');
      return false;
    }
  }

  Future<void> _checkAndRequestLocationPermission() async {
    debugPrint('RecordScreen - Konum izni kontrolü başlatılıyor...');
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lütfen konum servislerini açın.'),
            duration: Duration(seconds: 3),
          ),
        );
        // Consider guiding the user to settings if they don't enable it.
        await geo.Geolocator.openLocationSettings();
      }
      setState(() {
        _hasLocationPermission = false;
      });
      return;
    }

    if (Platform.isIOS) {
      geo.LocationPermission permission =
          await geo.Geolocator.checkPermission();
      debugPrint('RecordScreen - iOS konum izni durumu: $permission');

      if (permission == geo.LocationPermission.deniedForever) {
        if (mounted) {
          // _showPermissionPermanentlyDeniedDialog('Konum'); // ÇAĞRI KALDIRILDI
          debugPrint(
              'RecordScreen - iOS konum izni kalıcı olarak reddedilmiş.');
        }
        setState(() {
          _hasLocationPermission = false;
        });
      } else if (permission == geo.LocationPermission.whileInUse ||
          permission == geo.LocationPermission.always) {
        setState(() {
          _hasLocationPermission = true;
        });
        await _getCurrentLocation(); // Try to get location if permission granted
      } else {
        // If permission is denied (but not forever), we don't request it.
        // The user needs to grant it manually via settings.
        debugPrint(
            'RecordScreen - iOS konum izni verilmemiş, kullanıcı ayarlarından vermeli.');
        setState(() {
          _hasLocationPermission = false;
        });
      }
    } else {
      // Android
      final status = await Permission.location.status;
      debugPrint('RecordScreen - Android konum izin durumu: $status');

      if (!status.isGranted && !status.isLimited) {
        // final requestedStatus = await Permission.location.request(); // İZİN İSTEĞİ KALDIRILDI
        // debugPrint(
        //     'RecordScreen - Android izin istenen durum (Uygulamayı Kullanırken): $requestedStatus');
        // if (requestedStatus.isPermanentlyDenied) {
        if (status.isPermanentlyDenied) {
          // Check current status for permanent denial
          if (mounted) {
            // _showPermissionPermanentlyDeniedDialog('Konum'); // ÇAĞRI KALDIRILDI
            debugPrint(
                'RecordScreen - Android konum izni kalıcı olarak reddedilmiş.');
          }
          setState(() {
            _hasLocationPermission = false;
          });
          // } else if (requestedStatus.isGranted || requestedStatus.isLimited) {
          //   setState(() {
          //     _hasLocationPermission = true;
          //   });
          //   await _getCurrentLocation();
        } else {
          // If permission is denied (but not forever), we don't request it.
          debugPrint(
              'RecordScreen - Android konum izni verilmemiş, kullanıcı ayarlarından vermeli.');
          setState(() {
            _hasLocationPermission = false;
          });
        }
      } else {
        debugPrint(
            'RecordScreen - Android konum izni (Uygulamayı Kullanırken veya Her Zaman) zaten verilmiş.');
        setState(() {
          _hasLocationPermission = true;
        });
        await _getCurrentLocation();
      }
    }
  }

  Future<void> _checkAndRequestActivityPermission() async {
    debugPrint('RecordScreen - Aktivite izni kontrolü başlatılıyor...');
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.status;
      debugPrint('RecordScreen - Android aktivite izin durumu: $status');
      if (!status.isGranted) {
        // final requestedStatus = await Permission.activityRecognition.request(); // İZİN İSTEĞİ KALDIRILDI
        // debugPrint(
        //     'RecordScreen - Android aktivite izin istenen durum: $requestedStatus');
        // if (requestedStatus.isPermanentlyDenied) {
        if (status.isPermanentlyDenied) {
          // Check current status for permanent denial
          if (mounted) {
            // _showPermissionPermanentlyDeniedDialog('Fiziksel Aktivite'); // ÇAĞRI KALDIRILDI
            debugPrint(
                'RecordScreen - Android aktivite izni kalıcı olarak reddedilmiş.');
          }
          setState(() {
            _hasPedometerPermission = false;
          });
          // } else if (requestedStatus.isGranted) {
          //   setState(() {
          //     _hasPedometerPermission = true;
          //   });
          //   _initPedometer();
        } else {
          debugPrint(
              'RecordScreen - Android aktivite izni verilmemiş, kullanıcı ayarlarından vermeli.');
          setState(() {
            _hasPedometerPermission = false;
          });
        }
      } else {
        debugPrint('RecordScreen - Android aktivite izni zaten verilmiş.');
        setState(() {
          _hasPedometerPermission = true;
        });
        _initPedometer();
      }
    } else if (Platform.isIOS) {
      // For iOS, we rely on Pedometer stream and Permission.sensors
      // First, check general sensor access, which is a prerequisite for motion data.
      final sensorStatus =
          await Permission.sensors.status; // İZİN İSTEĞİ DEĞİL, DURUM KONTROLÜ
      debugPrint(
          'RecordScreen - iOS sensör (motion) izin durumu: $sensorStatus');

      // Then, try to listen to Pedometer stream to confirm HealthKit access for steps.
      bool healthKitStepsVerified = false;
      StreamSubscription<StepCount>? healthCheckSubscription;

      if (sensorStatus.isGranted) {
        // Proceed only if sensor permission is already granted
        try {
          healthCheckSubscription =
              Pedometer.stepCountStream.listen((StepCount event) {
            debugPrint(
                'RecordScreen - HealthKit adım verisi alındı: ${event.steps}');
            healthKitStepsVerified = true;
            healthCheckSubscription?.cancel(); // Stop listening once verified
          }, onError: (error) {
            debugPrint(
                'RecordScreen - HealthKit adım verisi dinleme hatası: $error');
            healthCheckSubscription?.cancel();
          }, onDone: () {
            debugPrint('RecordScreen - HealthKit adım verisi stream bitti.');
          });

          // Wait a short period for data to arrive.
          await Future.delayed(const Duration(seconds: 2));
          await healthCheckSubscription?.cancel(); // Ensure cancellation

          if (healthKitStepsVerified) {
            debugPrint(
                'RecordScreen - iOS HealthKit (Adımlar) izni doğrulandı.');
            setState(() {
              _hasPedometerPermission = true;
            });
            _initPedometer();
          } else {
            debugPrint(
                'RecordScreen - iOS HealthKit (Adımlar) izni DOĞRULANAMADI veya sensör izni reddedildi.');
            setState(() {
              _hasPedometerPermission = false;
            });
            // if (mounted &&
            //     (sensorStatus.isDenied ||
            //         sensorStatus.isPermanentlyDenied ||
            //         !healthKitStepsVerified)) {
            //   // _showIOSHealthKitPermissionDialog(); // ÇAĞRI KALDIRILDI
            //   debugPrint(
            //       'RecordScreen - iOS HealthKit (Adımlar) veya sensör izni reddedilmiş/doğrulanamadı.');
            // }
          }
        } catch (e) {
          debugPrint(
              'RecordScreen - iOS HealthKit izin kontrolü sırasında genel hata: $e');
          setState(() {
            _hasPedometerPermission = false;
          });
          // if (mounted) {
          //   // _showIOSHealthKitPermissionDialog(); // ÇAĞRI KALDIRILDI
          //   debugPrint(
          //       'RecordScreen - iOS HealthKit izin kontrol hatası, dialog gösterilmeyecek.');
          // }
        }
      } else {
        // Sensor permission not granted
        debugPrint(
            'RecordScreen - iOS sensör (motion) izni verilmemiş. Adım sayar kullanılamaz.');
        setState(() {
          _hasPedometerPermission = false;
        });
        // if (mounted) {
        //    // _showIOSHealthKitPermissionDialog(); // ÇAĞRI KALDIRILDI
        //    debugPrint('RecordScreen - iOS sensör izni yok, HealthKit dialog gösterilmeyecek.');
        // }
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      geo.Position position = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high);

      _currentGeoPosition = position;
      _currentMapboxPoint = mb.Point(
          coordinates: mb.Position(position.longitude, position.latitude));

      if (_currentLocationMarker != null &&
          _pointAnnotationManager != null &&
          _currentMapboxPoint != null) {
        try {
          _currentLocationMarker!.geometry = _currentMapboxPoint!;
          await _pointAnnotationManager!.update(_currentLocationMarker!);
        } catch (e) {
          debugPrint(
              'RecordScreen: _getCurrentLocation - İşaretçi güncellenirken HATA: $e');
        }
      } else if (_currentMapboxPoint != null &&
          _pointAnnotationManager != null) {
        if (_maleMarkerIcon == null || _femaleMarkerIcon == null) {
          await _loadMarkerImage();
        }
        final Uint8List? selectedMarkerIconBytes = _getCurrentMarkerIconBytes();

        if (selectedMarkerIconBytes == null) {
          debugPrint(
              'RecordScreen: _getCurrentLocation - Seçilen işaretçi resmi yüklenemedi veya bulunamadı.');
          return;
        }

        try {
          _currentLocationMarker = await _pointAnnotationManager!.create(
            mb.PointAnnotationOptions(
              geometry: _currentMapboxPoint!,
              image: selectedMarkerIconBytes,
              iconSize:
                  selectedMarkerIconBytes == _femaleMarkerIcon ? 0.20 : 0.15,
            ),
          );
          debugPrint(
              'RecordScreen: _getCurrentLocation - Marker created. Icon was: ${selectedMarkerIconBytes == _femaleMarkerIcon ? "FEMALE" : (selectedMarkerIconBytes == _maleMarkerIcon ? "MALE" : "UNKNOWN/NULL")}');
        } catch (e) {
          debugPrint(
              'RecordScreen: _getCurrentLocation - Yeni işaretçi oluşturulurken HATA: $e');
        }
      }

      if (_mapboxMap != null && _currentMapboxPoint != null) {
        await _mapboxMap!.flyTo(
          mb.CameraOptions(
            center: _currentMapboxPoint!,
            zoom: 17.0,
          ),
          mb.MapAnimationOptions(duration: 1500, startDelay: 0),
        );
      }

      if (mounted) {
        setState(() {});
      }

      if (!_isRecording &&
          _mapboxRouteCoordinates.isEmpty &&
          _currentMapboxPoint != null) {
        _mapboxRouteCoordinates.add(_currentMapboxPoint!);
      }
    } catch (e) {
      debugPrint('RecordScreen: _getCurrentLocation genel HATA: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _startLocationTracking() {
    if (!_hasLocationPermission) {
      _checkAndRequestLocationPermission();
      return;
    }

    try {
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
                  'RecordScreen: _startLocationTracking - Yeni özel işaretçi oluşturuluyor. Point: ${newMapboxPoint.encode()}');
              final Uint8List? selectedMarkerIconBytes =
                  _getCurrentMarkerIconBytes();
              if (selectedMarkerIconBytes != null) {
                _pointAnnotationManager
                    ?.create(mb.PointAnnotationOptions(
                  geometry: newMapboxPoint,
                  image: selectedMarkerIconBytes,
                  iconSize: selectedMarkerIconBytes == _femaleMarkerIcon
                      ? 0.20
                      : 0.15,
                ))
                    .then((annotation) {
                  _currentLocationMarker = annotation;
                  debugPrint(
                      'RecordScreen: _startLocationTracking - Yeni işaretçi OLUŞTURULDU. ID: ${annotation.id}. Icon was: ${selectedMarkerIconBytes == _femaleMarkerIcon ? "FEMALE" : (selectedMarkerIconBytes == _maleMarkerIcon ? "MALE" : "UNKNOWN/NULL")}');
                }).catchError((e) => debugPrint(
                        "RecordScreen: _startLocationTracking - Takip sırasında işaretçi oluşturulurken HATA: $e"));
              }
            }

            if (_polylineAnnotationManager != null &&
                _mapboxRouteCoordinates.length > 1) {
              _polylineAnnotationManager?.deleteAll().catchError(
                  (e) => debugPrint("Error deleting polylines: $e"));
              _polylineAnnotationManager
                  ?.create(mb.PolylineAnnotationOptions(
                    geometry: mb.LineString(
                        coordinates: _mapboxRouteCoordinates
                            .map((p) => p.coordinates)
                            .toList()),
                    lineColor: const Color(0xFFC4FF62).value,
                    lineWidth: 5.0,
                  ))
                  .catchError((e) => debugPrint("Error creating polyline: $e"));
            }

            _mapboxMap?.flyTo(mb.CameraOptions(center: newMapboxPoint),
                mb.MapAnimationOptions(duration: 500));
          });
        }
      }, onError: (e) {
        debugPrint('Konum takibi hatası: $e');
      });
    } catch (e) {
      debugPrint('Konum takibi başlatma hatası: $e');
    }
  }

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
    debugPrint('RecordScreen: _startRecording çağrıldı.');
    // Ensure permissions before starting, _hasLocationPermission is key
    if (!_hasLocationPermission) {
      debugPrint(
          'RecordScreen: Konum izni yok, kayıt başlatılamıyor. İzinler isteniyor...');
      _checkAndRequestLocationPermission(); // Re-request if not granted
      // Optionally, show a message to the user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Lütfen konum iznini verdikten sonra tekrar deneyin.')));
      }
      return;
    }
    if (!_hasPedometerPermission && (Platform.isAndroid || Platform.isIOS)) {
      debugPrint(
          'RecordScreen: Adım sayar izni yok, kayıt başlatılıyor ancak adımlar eksik olabilir. İzinler isteniyor...');
      _checkAndRequestActivityPermission(); // Re-request if not granted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Adım sayar izni verilmedi, adımlarınız kaydedilemeyebilir.')));
      }
      // Allow recording to start without pedometer, but steps might be 0.
    }

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
      _mapboxRouteCoordinates = [];
      _polylineAnnotationManager?.deleteAll().catchError(
          (e) => debugPrint("Error deleting polylines on start: $e"));
      if (_currentLocationMarker != null) {
        _pointAnnotationManager?.delete(_currentLocationMarker!).catchError(
            (e) => debugPrint("Error deleting marker on start: $e"));
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
    debugPrint('RecordScreen: _finishRecording çağrıldı.');
    final int finalDuration = _seconds;
    final double finalDistance = _distance;
    final int finalCalories = _calories;
    final int finalSteps = _steps;
    final int averageSpeed = _pace.toInt();
    final DateTime recordStartTime = _startTime ?? DateTime.now();

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
          (e) => debugPrint("Error deleting polylines on finish: $e"));

      if (_currentLocationMarker != null) {
        _pointAnnotationManager?.delete(_currentLocationMarker!).catchError(
            (e) => debugPrint("Error deleting marker on finish: $e"));
        _currentLocationMarker = null;
      }

      _getCurrentLocation();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aktiviteniz kaydediliyor...'),
          duration: Duration(seconds: 2),
        ),
      );

      ref.read(recordSubmissionProvider(recordRequest).future).then(
        (response) async {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aktivite başarıyla kaydedildi!'),
              backgroundColor: Colors.green,
            ),
          );

          try {
            final double earnedAmount =
                await ref.read(recordEarnCoinProvider(distance).future);

            if (earnedAmount > 0 && mounted) {
              _showCoinPopup(context, earnedAmount);
            }
          } catch (coinError) {
            debugPrint("🪙 Coin Kazanma İsteği Hatası: $coinError");
          }
        },
        onError: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Aktivite kaydedilemedi: ${error.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _togglePause() {
    debugPrint(
        'RecordScreen: _togglePause çağrıldı. _isPaused: $_isPaused -> ${!_isPaused}');
    setState(() {
      _isPaused = !_isPaused;

      if (_isPaused) {
        _pulseController.stop();
        _calorieCalculationTimer?.cancel();
        _stopLocationTracking();
        _stepCountSubscription?.pause();
      } else {
        _pulseController.forward();
        _initializeCalorieCalculation();
        _startLocationTracking();
        _stepCountSubscription?.resume();
      }
    });
  }

  void _selectActivityType(String type) {
    if (!_isRecording) {
      setState(() {
        _activityType = type;
      });
    } else {
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

  Widget _buildStatColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.bangers(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.bangers(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

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
              style: GoogleFonts.bangers(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              unit,
              style: GoogleFonts.bangers(
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
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: const Color(0xFF121212),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            if (!(_isRecording && _showStatsScreen))
              Stack(
                children: [
                  Container(color: Colors.black),
                  _hasLocationPermission
                      ? mb.MapWidget(
                          key: const ValueKey("mapbox_map_record"),
                          styleUri: mb.MapboxStyles.STANDARD,
                          cameraOptions: (_currentMapboxPoint != null)
                              ? mb.CameraOptions(
                                  center: _currentMapboxPoint!, zoom: 17.0)
                              : _initialCameraOptions,
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
                                Text(
                                  'Konum izni gerekiyor',
                                  style: GoogleFonts.bangers(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed:
                                      _checkAndRequestPermissionsSequentially,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFC4FF62),
                                    foregroundColor: Colors.black,
                                  ),
                                  child: Text(
                                    'İzin Ver',
                                    style: GoogleFonts.bangers(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ],
              ),
            _showStatsScreen
                ? Column(
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
                          onFinishRecording: _finishRecordingAndHideStats,
                        ),
                      ),
                    ],
                  )
                : SafeArea(
                    child: Column(
                      children: [
                        if (!_isRecording && !_showStatsScreen)
                          Container(
                            margin: const EdgeInsets.only(
                                bottom: 8.0, left: 16.0, right: 16.0, top: 8.0),
                            padding: const EdgeInsets.symmetric(
                                vertical: 6.0, horizontal: 12.0),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 0, 0, 0)
                                  .withOpacity(0.7),
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
                                    'Koşu',
                                    Icons.directions_run,
                                    _activityType == 'Running',
                                    () => _selectActivityType('Running')),
                                _buildActivityTypeButton(
                                    'Yürüyüş',
                                    Icons.directions_walk,
                                    _activityType == 'Walking',
                                    () => _selectActivityType('Walking')),
                                _buildActivityTypeButton(
                                    'Bisiklet',
                                    Icons.directions_bike,
                                    _activityType == 'Cycling',
                                    () => _selectActivityType('Cycling')),
                              ],
                            ),
                          ),
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
                                  children: [],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _formatTime(_seconds),
                                  style: GoogleFonts.bangers(
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
                                                          ? 'Bitir'
                                                          : 'Başla',
                                                      style:
                                                          GoogleFonts.bangers(
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
                                                      ? 'Devam Et'
                                                      : 'Durdur',
                                                  style: GoogleFonts.bangers(
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
            if (_hasLocationPermission && !(_isRecording && _showStatsScreen))
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
            if (_isRecording && !_showStatsScreen)
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
          ],
        ),
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
            style: GoogleFonts.bangers(
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

  void _initPedometer() {
    // Ensure we have permission before initializing
    if (!_hasPedometerPermission) {
      debugPrint(
          "RecordScreen: _initPedometer - Adım sayar izni yok, başlatılamıyor.");
      // Optionally, try to request it again here or ensure it's requested before _startRecording
      // _checkAndRequestActivityPermission(); // Could be called here
      return;
    }
    _stepCountSubscription?.cancel();

    try {
      Future.delayed(const Duration(milliseconds: 100), () {
        _stepCountSubscription =
            Pedometer.stepCountStream.listen((StepCount event) {
          if (!mounted || !_isRecording || _isPaused) {
            return;
          }

          setState(() {
            if (_initialSteps == 0 && event.steps > 0) {
              _initialSteps = event.steps;
              _steps = 0;
            } else if (_initialSteps > 0) {
              _steps = event.steps - _initialSteps;
              if (_steps < 0) {
                _steps = 0;
              }
            }
          });
        }, onError: (error) {
          debugPrint('RecordScreen - Adım sayar hatası: $error');
          if (Platform.isIOS) {}
        }, onDone: () {});

        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && _isRecording && _initialSteps == 0) {
            _stepCountSubscription?.cancel();
            _initPedometer();
          }
        });
      });
    } catch (e) {
      debugPrint('RecordScreen - Pedometer başlatma hatası: $e');
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

  void _showCoinPopup(BuildContext context, double coins) {
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return EarnCoinPopup(
            earnedCoin: coins,
            onGoHomePressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(selectedTabProvider.notifier).state = 0;
            },
          );
        },
      );
    }
  }

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

  void _calculateCalories() {
    final now = DateTime.now();

    if (_lastCalorieCalculationTime == null) {
      _lastDistance = _distance;
      _lastSteps = _steps;
      _lastCalorieCalculationTime = now;
      setState(() {
        _calories = 0;
      });
      return;
    }

    final elapsedSeconds =
        now.difference(_lastCalorieCalculationTime!).inSeconds;
    if (elapsedSeconds < 4) return;

    final distanceDifference = _distance - _lastDistance;
    final stepsDifference = _steps - _lastSteps;
    final bool isMoving = distanceDifference > 0.001 || stepsDifference > 0;
    final double currentPaceKmH = distanceDifference > 0 && elapsedSeconds > 0
        ? (distanceDifference) / (elapsedSeconds / 3600.0)
        : 0;

    final userData = ref.read(userDataProvider).value;
    double weightKg = 70.0;
    double heightCm = 170.0;
    int ageYears = 25;
    String gender = 'male';

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
    }

    double bmr;
    if (gender == 'female') {
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears) - 161;
    } else {
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears) + 5;
    }
    if (bmr < 0) bmr = 0;

    double metValue;
    if (!isMoving) {
      metValue = 1.0;
    } else {
      if (_activityType == 'Running' || _activityType == 'Walking') {
        if (currentPaceKmH < 3.2) {
          metValue = 2.0;
        } else if (currentPaceKmH < 4.8) {
          metValue = 3.0;
        } else if (currentPaceKmH < 6.4) {
          metValue = 3.8;
        } else if (currentPaceKmH < 8.0) {
          metValue = 8.3;
        } else if (currentPaceKmH < 9.7) {
          metValue = 9.8;
        } else if (currentPaceKmH < 11.3) {
          metValue = 11.0;
        } else if (currentPaceKmH < 12.9) {
          metValue = 11.8;
        } else if (currentPaceKmH < 14.5) {
          metValue = 12.8;
        } else if (currentPaceKmH < 16.0) {
          metValue = 14.5;
        } else if (currentPaceKmH < 17.5) {
          metValue = 16.0;
        } else {
          metValue = 19.0;
        }
      } else if (_activityType == 'Cycling') {
        if (currentPaceKmH < 16.0)
          metValue = 4.0;
        else if (currentPaceKmH < 20.0)
          metValue = 6.8;
        else if (currentPaceKmH < 24.0)
          metValue = 8.0;
        else
          metValue = 10.0;
      } else {
        metValue = 5.0;
      }
    }

    double bmrPerSecond = bmr / (24 * 60 * 60);
    int newCalories = (bmrPerSecond * elapsedSeconds * metValue).round();
    if (newCalories < 0) newCalories = 0;

    setState(() {
      _calories += newCalories;
    });

    debugPrint(
        'RecordScreen 🔥 Kalori hesaplandı: +$newCalories kal (Toplam: $_calories) - MET: $metValue, Hız: ${currentPaceKmH.toStringAsFixed(2)} km/h, Aktivite: $_activityType');

    _lastDistance = _distance;
    _lastSteps = _steps;
    _lastCalorieCalculationTime = now;
  }

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
          (e) => debugPrint("Error deleting polylines on force stop: $e"));
      if (_currentLocationMarker != null) {
        _pointAnnotationManager?.delete(_currentLocationMarker!).catchError(
            (e) => debugPrint("Error deleting marker on force stop: $e"));
        _currentLocationMarker = null;
      }
      _currentMapboxPoint = null;
      _currentGeoPosition = null;
      _mapboxMap?.flyTo(
          _initialCameraOptions, mb.MapAnimationOptions(duration: 1000));
    });
  }

  void _onMapCreated(mb.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
  }

  void _onStyleLoadedListener(dynamic data) async {
    if (_mapboxMap == null || !mounted) {
      debugPrint(
          'RecordScreen: _onStyleLoadedListener - Map is null or widget not mounted, returning.');
      return;
    }

    debugPrint(
        'RecordScreen: _onStyleLoadedListener - Style loaded, (re)initializing annotation managers.');

    try {
      _pointAnnotationManager =
          await _mapboxMap!.annotations.createPointAnnotationManager();
      debugPrint(
          'RecordScreen: _onStyleLoadedListener - PointAnnotationManager created.');
    } catch (e) {
      debugPrint(
          'RecordScreen: _onStyleLoadedListener - Error creating PointAnnotationManager: $e');
    }

    try {
      _polylineAnnotationManager =
          await _mapboxMap!.annotations.createPolylineAnnotationManager();
      debugPrint(
          'RecordScreen: _onStyleLoadedListener - PolylineAnnotationManager created.');
    } catch (e) {
      debugPrint(
          'RecordScreen: _onStyleLoadedListener - Error creating PolylineAnnotationManager: $e');
    }

    if (!mounted) {
      debugPrint(
          'RecordScreen: _onStyleLoadedListener - Widget unmounted after creating managers, returning.');
      return;
    }

    if (_isRecording) {
      debugPrint(
          'RecordScreen: _onStyleLoadedListener - Recording is active. Restoring route and marker.');
      // Restore polyline
      if (_polylineAnnotationManager != null &&
          _mapboxRouteCoordinates.length > 1) {
        debugPrint(
            'RecordScreen: _onStyleLoadedListener - Restoring polyline with ${_mapboxRouteCoordinates.length} points.');
        _polylineAnnotationManager!.deleteAll().then((_) {
          return _polylineAnnotationManager!
              .create(mb.PolylineAnnotationOptions(
            geometry: mb.LineString(
                coordinates:
                    _mapboxRouteCoordinates.map((p) => p.coordinates).toList()),
            lineColor: const Color(0xFFC4FF62).value,
            lineWidth: 5.0,
          ));
        }).then((_) {
          debugPrint(
              'RecordScreen: _onStyleLoadedListener - Polyline restored.');
        }).catchError((e) {
          debugPrint(
              'RecordScreen: _onStyleLoadedListener - Error restoring polyline: $e');
        });
      } else {
        debugPrint(
            'RecordScreen: _onStyleLoadedListener - Polyline manager null or not enough points for polyline (${_mapboxRouteCoordinates.length}).');
      }

      // Restore current location marker
      if (_currentMapboxPoint != null && _pointAnnotationManager != null) {
        if (_maleMarkerIcon == null || _femaleMarkerIcon == null) {
          debugPrint(
              'RecordScreen: _onStyleLoadedListener - İşaretçi resimleri null, yükleniyor.');
          await _loadMarkerImage();
          if (!mounted) return;
        }

        final Uint8List? selectedMarkerIconBytes = _getCurrentMarkerIconBytes();

        if (selectedMarkerIconBytes != null) {
          debugPrint(
              'RecordScreen: _onStyleLoadedListener - Mevcut konum işaretçisi geri yükleniyor/oluşturuluyor.');
          _pointAnnotationManager!
              .create(
            mb.PointAnnotationOptions(
              geometry: _currentMapboxPoint!,
              image: selectedMarkerIconBytes,
              iconSize:
                  selectedMarkerIconBytes == _femaleMarkerIcon ? 0.20 : 0.15,
            ),
          )
              .then((newMarker) {
            if (mounted) {
              _currentLocationMarker = newMarker;
              debugPrint(
                  'RecordScreen: _onStyleLoadedListener - Current location marker restored/created. ID: ${newMarker.id}. Icon was: ${selectedMarkerIconBytes == _femaleMarkerIcon ? "FEMALE" : (selectedMarkerIconBytes == _maleMarkerIcon ? "MALE" : "UNKNOWN/NULL")}');
            }
          }).catchError((e) {
            debugPrint(
                'RecordScreen: _onStyleLoadedListener - Error restoring current location marker: $e');
          });
        } else {
          debugPrint(
              'RecordScreen: _onStyleLoadedListener - Marker image still null after attempting load, cannot create marker.');
        }
      } else {
        debugPrint(
            'RecordScreen: _onStyleLoadedListener - Current mapbox point or point manager is null, cannot restore marker.');
      }
    } else {
      // Not recording
      debugPrint(
          'RecordScreen: _onStyleLoadedListener - Not recording. Calling _getCurrentLocation after delay.');
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _getCurrentLocation();
        } else {
          debugPrint(
              'RecordScreen: _onStyleLoadedListener - Widget unmounted before _getCurrentLocation callback.');
        }
      });
    }
  }

  Uint8List? _getCurrentMarkerIconBytes() {
    final userData = ref.read(userDataProvider).value;
    final String? genderFromProvider = userData?.gender;
    debugPrint(
        'RecordScreen: _getCurrentMarkerIconBytes - Gender from provider: $genderFromProvider');
    debugPrint(
        'RecordScreen: _getCurrentMarkerIconBytes - _femaleMarkerIcon is null: ${_femaleMarkerIcon == null}');
    debugPrint(
        'RecordScreen: _getCurrentMarkerIconBytes - _maleMarkerIcon is null: ${_maleMarkerIcon == null}');

    // Default to 'male' if gender is null, not available, or not 'female'
    final String effectiveGender =
        (genderFromProvider?.toLowerCase() == 'female') ? 'female' : 'male';
    debugPrint(
        'RecordScreen: _getCurrentMarkerIconBytes - Effective gender for icon choice: $effectiveGender');

    if (effectiveGender == 'female' && _femaleMarkerIcon != null) {
      debugPrint(
          'RecordScreen: _getCurrentMarkerIconBytes - Returning FEMALE icon.');
      return _femaleMarkerIcon;
    }
    debugPrint(
        'RecordScreen: _getCurrentMarkerIconBytes - Returning MALE icon (or null if male icon not loaded).');
    return _maleMarkerIcon;
  }

  // Function to update marker icon, typically called when gender changes or icons load late.
  Future<void> _updateMarkerIconForGenderChange() async {
    // Ensure point manager and a current point are available
    if (_pointAnnotationManager == null || _currentMapboxPoint == null) {
      debugPrint(
          'RecordScreen: _updateMarkerIconForGenderChange - PointAnnotationManager or currentMapboxPoint is null. Cannot update icon yet.');
      return;
    }

    // If a current marker exists, delete it first
    if (_currentLocationMarker != null) {
      debugPrint(
          'RecordScreen: _updateMarkerIconForGenderChange - Deleting existing marker ID: ${_currentLocationMarker!.id} to update icon.');
      try {
        await _pointAnnotationManager!.delete(_currentLocationMarker!);
        _currentLocationMarker = null; // Nullify after deletion
      } catch (e) {
        debugPrint(
            'RecordScreen: _updateMarkerIconForGenderChange - Error deleting existing marker: $e');
        // Continue, as we want to try creating a new one anyway
      }
    } else {
      debugPrint(
          'RecordScreen: _updateMarkerIconForGenderChange - No existing marker to delete.');
    }

    final Uint8List? newIconBytes =
        _getCurrentMarkerIconBytes(); // Get the latest icon based on current gender and loaded icons

    if (newIconBytes != null) {
      debugPrint(
          'RecordScreen: _updateMarkerIconForGenderChange - Attempting to create new marker with fresh icon.');
      try {
        _currentLocationMarker = await _pointAnnotationManager!.create(
          mb.PointAnnotationOptions(
            geometry: _currentMapboxPoint!, // Use the current map point
            image: newIconBytes,
            iconSize: newIconBytes == _femaleMarkerIcon
                ? 0.20
                : 0.15, // Dynamic icon size
          ),
        );
        debugPrint(
            'RecordScreen: _updateMarkerIconForGenderChange - Marker recreated/created. ID: ${_currentLocationMarker?.id}. Icon is: ${newIconBytes == _femaleMarkerIcon ? "FEMALE" : (newIconBytes == _maleMarkerIcon ? "MALE" : "UNKNOWN/NULL")}');
      } catch (e) {
        debugPrint(
            'RecordScreen: _updateMarkerIconForGenderChange - Error recreating marker: $e');
      }
    } else {
      debugPrint(
          'RecordScreen: _updateMarkerIconForGenderChange - Failed to get new icon bytes. Marker not created/updated.');
    }
  }
}
