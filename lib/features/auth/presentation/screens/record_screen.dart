import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen>
    with SingleTickerProviderStateMixin {
  bool _isRecording = false;
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

    _checkLocationPermission();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // Konum izinlerini kontrol eden fonksiyon
  Future<void> _checkLocationPermission() async {
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

    if (_hasLocationPermission) {
      _getCurrentLocation();
    }
  }

  // Mevcut konumu al ve haritayı oraya taşı
  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

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

    // En az 10 metrede bir konum güncellemesi al
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // metre cinsinden minimum mesafe değişikliği
      ),
    ).listen((Position position) {
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
    });
  }

  // Konum takibini durdur
  void _stopLocationTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  void _toggleRecording() {
    setState(() {
      _isRecording = !_isRecording;

      if (_isRecording) {
        _pulseController.forward();

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
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_activityType Activity',
                      style: const TextStyle(
                        fontSize: 28,
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

              // Activity Stats Preview
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Current Session',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn(_formatTime(_seconds), 'Time'),
                        _buildStatColumn(
                            _distance.toStringAsFixed(2), 'Distance (km)'),
                        _buildStatColumn('$_calories', 'Calories'),
                      ],
                    ),
                    if (_isRecording) ...[
                      const Divider(height: 24, color: Colors.grey),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn(
                              '${_pace.toStringAsFixed(1)} km/h', 'AVG PACE'),
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

              // Google Maps instead of static image
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16.0),
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
                        ? GoogleMap(
                            mapType: MapType.normal,
                            initialCameraPosition: _initialCameraPosition,
                            myLocationEnabled: true,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            markers: _markers,
                            polylines: _polylines,
                            onMapCreated: (GoogleMapController controller) {
                              _mapController = controller;
                              // Harita oluşturulduktan sonra mevcut konumu al
                              _getCurrentLocation();
                            },
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
                                  onPressed: _checkLocationPermission,
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

              // Record Button
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: GestureDetector(
                  onTap: _toggleRecording,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isRecording ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 80,
                          height: 80,
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
                            size: 40,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Activity Type Selection
              Container(
                margin: const EdgeInsets.only(
                    bottom: 20.0, left: 16.0, right: 16.0),
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
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
}
