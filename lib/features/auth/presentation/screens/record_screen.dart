import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pedometer/pedometer.dart';
import 'package:flutter/foundation.dart';

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

    // Önce konum iznini kontrol et, sonra adım sayar iznini kontrol et
    _initPermissions();
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

    await _checkLocationPermission();
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
      // iOS'ta motion sensörü izni için
      if (await Permission.sensors.request().isGranted) {
        setState(() {
          _hasPedometerPermission = true;
        });
        _initPedometer();
      }
    }
  }

  // Konum izinlerini kontrol eden fonksiyon
  Future<void> _checkLocationPermission() async {
    try {
      final LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        final LocationPermission requestedPermission =
            await Geolocator.requestPermission();

        setState(() {
          _hasLocationPermission =
              requestedPermission != LocationPermission.denied &&
                  requestedPermission != LocationPermission.deniedForever;
        });
      } else {
        setState(() {
          _hasLocationPermission = permission != LocationPermission.denied &&
              permission != LocationPermission.deniedForever;
        });
      }

      print('Konum izin durumu: $_hasLocationPermission');

      if (_hasLocationPermission) {
        // İzin varsa konumu al
        await _getCurrentLocation();
      }
    } catch (e) {
      print('Konum izni hatası: $e');
    }
  }

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
      // En az 5 metrede bir konum güncellemesi al
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5, // metre cinsinden minimum mesafe değişikliği
        ),
      ).listen((Position position) {
        print('Konum güncellendi: ${position.latitude}, ${position.longitude}');
        if (mounted) {
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
    setState(() {
      _isRecording = !_isRecording;
      _isPaused = false; // Reset pause state when toggling recording

      if (_isRecording) {
        _pulseController.forward();
        _initialSteps = 0; // Adım sayacını sıfırla

        // Start timer
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _seconds++;

            // Kalori hesaplamasını basitleştirilmiş şekilde yap
            // Gerçek uygulamada kullanıcının ağırlığı, hızı vb. faktörlere dayalı olmalı
            if (_seconds % 10 == 0) {
              _calories = (_distance * 60).toInt(); // Basit bir formül

              // Hız hesapla (km/sa)
              _pace = _seconds > 0 ? (_distance / (_seconds / 3600.0)) : 0;
            }
          });
        });

        // GPS takibi başlat
        _startLocationTracking();
      } else {
        _pulseController.stop();
        _pulseController.reset();

        // Stop timer
        _timer?.cancel();

        // GPS takibini durdur
        _stopLocationTracking();

        // Aktivite verileri sıfırla
        _seconds = 0;
        _distance = 0.0;
        _calories = 0;
        _pace = 0.0;
        _steps = 0;

        // Harita rota verilerini temizle
        _routeCoordinates = [];
        _polylines = {};

        // Mevcut konum marker'ı dışındaki marker'ları temizle
        if (_currentPosition != null) {
          _markers = {
            Marker(
              markerId: const MarkerId('currentLocation'),
              position: LatLng(
                  _currentPosition!.latitude, _currentPosition!.longitude),
              infoWindow: const InfoWindow(title: 'Konumunuz'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
            )
          };
        } else {
          _markers = {};
        }

        // Güncel konumu tekrar alarak haritayı mevcut konuma getir
        _getCurrentLocation();
      }
    });
  }

  // Duraklatma/devam etme fonksiyonu
  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;

      if (_isPaused) {
        // Pause recording
        _pulseController.stop();

        // Pause timer
        _timer?.cancel();

        // Pause location tracking
        _stopLocationTracking();
      } else {
        // Resume recording
        _pulseController.forward();

        // Resume timer
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _seconds++;

            // Kalori ve hız güncelleme
            if (_seconds % 10 == 0) {
              _calories = (_distance * 60).toInt();
              _pace = _seconds > 0 ? (_distance / (_seconds / 3600.0)) : 0;
            }
          });
        });

        // Resume location tracking
        _startLocationTracking();
      }
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFC4FF62),
              Colors.black,
            ],
            stops: [0.0, 0.85],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_activityType Activity',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined,
                          color: Colors.black),
                      onPressed: () {
                        // Show settings dialog
                      },
                    ),
                  ],
                ),
              ),

              // Google Maps with Stats Overlay
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.0),
                    child: _hasLocationPermission
                        ? Stack(
                            children: [
                              // Map Layer
                              GoogleMap(
                                mapType: MapType.normal,
                                initialCameraPosition: _initialCameraPosition,
                                myLocationEnabled: true,
                                myLocationButtonEnabled: false,
                                zoomControlsEnabled: false,
                                compassEnabled: true,
                                markers: _markers,
                                polylines: _polylines,
                                onMapCreated: (GoogleMapController controller) {
                                  _mapController = controller;
                                  // Harita oluşturulduktan sonra mevcut konumu al
                                  _getCurrentLocation();
                                },
                              ),

                              // Stats Overlay
                              Positioned(
                                top: 0,
                                left: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0, vertical: 8.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(12.0),
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
                                      const Text(
                                        'Current Session',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          _buildStatColumn('$_steps', 'Steps'),
                                          _buildStatColumn(
                                              _distance.toStringAsFixed(2),
                                              'Distance (km)'),
                                          _buildStatColumn(
                                              '$_calories', 'Calories'),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Adım sayısı göstergesi
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          _buildStatColumn(
                                              _formatTime(_seconds), 'Time'),
                                        ],
                                      ),
                                      if (_isRecording) ...[
                                        const Divider(
                                            height: 12, color: Colors.grey),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceAround,
                                          children: [
                                            _buildStatColumn(
                                                '${_pace.toStringAsFixed(1)} km/h',
                                                'AVG PACE'),
                                            _buildStatColumn(
                                                _distance > 0
                                                    ? '${(_calories / _distance).toStringAsFixed(0)}'
                                                    : '0',
                                                'Cal/km'),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),

                              // Yeniden konum alma düğmesi
                              Positioned(
                                right: 12,
                                bottom: 12,
                                child: FloatingActionButton(
                                  mini: true,
                                  backgroundColor: const Color(0xFFC4FF62),
                                  foregroundColor: Colors.black,
                                  onPressed: _getCurrentLocation,
                                  child: const Icon(Icons.my_location),
                                ),
                              ),
                            ],
                          )
                        : Center(
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
                ),
              ),

              // Record Button and Pause Button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Record Button
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16.0, horizontal: 8.0),
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
                                        blurRadius: _isRecording ? 20 : 10,
                                        spreadRadius: _isRecording ? 5 : 0,
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
                                const SizedBox(height: 6),
                                Text(
                                  _isRecording ? 'Finish' : 'Record',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
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
                          vertical: 16.0, horizontal: 8.0),
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
                                _isPaused ? Icons.play_arrow : Icons.pause,
                                color: Colors.black,
                                size: 35,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isPaused ? 'Resume' : 'Pause',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
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
                    bottom: 16.0, left: 16.0, right: 16.0),
                padding:
                    const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16.0),
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
        ),
      ),
    );
  }

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
              color: isSelected ? Colors.black : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Adım sayar başlatma fonksiyonu
  void _initPedometer() {
    _stepCountSubscription =
        Pedometer.stepCountStream.listen((StepCount event) {
      setState(() {
        if (_isRecording && _initialSteps == 0) {
          _initialSteps = event.steps;
          _steps = 0;
        } else if (_isRecording) {
          _steps = event.steps - _initialSteps;
        }
      });
    }, onError: (error) {
      print('Adım sayar hatası: $error');
    });
  }
}
