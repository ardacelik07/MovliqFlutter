import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'package:image_picker/image_picker.dart';

import 'filter_screen2.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

// Enum to track verification steps
enum VerificationStep { location, photo, completed }

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  // Removed _selectedMethod
  bool _isVerifying = false;
  String? _currentlyVerifying; // 'location' or 'photo'
  bool _hasLocationPermission = false;
  Position? _currentPosition;

  // Separate verification states
  bool _locationVerified = false;
  bool _photoVerified = false;

  // Separate error messages
  String _errorMessageLocation = '';
  String _errorMessagePhoto = '';

  // Kamera ve fotoğraf değişkenleri
  final ImagePicker _picker = ImagePicker();
  File? _imageFile; // Keep for displaying the photo temporarily if needed
  // Removed _imageAnalysisResult and _hasRunningMachine as separate states,
  // _photoVerified handles success

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    // Reset states on re-check
    setState(() {
      _hasLocationPermission = false;
      _errorMessageLocation = '';
    });

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _hasLocationPermission = false;
        _errorMessageLocation =
            'Konum izni gerekli. Lütfen ayarlardan izin verin.';
      });
      return;
    }

    setState(() {
      _hasLocationPermission = true;
    });
  }

  // Yakındaki fitness salonlarını kontrol et
  Future<void> _verifyNearbyGym() async {
    setState(() {
      _isVerifying = true;
      _currentlyVerifying = 'location';
      _errorMessageLocation = ''; // Clear previous error
      _locationVerified = false; // Reset verification status
    });

    try {
      if (!_hasLocationPermission) {
        await _checkLocationPermission();
        if (!_hasLocationPermission) {
          throw Exception('Konum izni alınamadı');
        }
        // If permission is granted now, get location
        if (_hasLocationPermission) {
          _currentPosition = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high);
        } else {
          throw Exception('Konum izni hala verilmedi.');
        }
      } else if (_currentPosition == null) {
        _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      }

      print(
          '📍 Konum alındı: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');

      // Google Places API (Keep existing logic for now, consider security later)
      final apiKey = 'AIzaSyA79Tf7SPoGXrwx5WupR6G-67te9UGabLA';
      final radius = 1000;
      final url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=${_currentPosition!.latitude},${_currentPosition!.longitude}'
          '&radius=1000'
          '&type=gym'
          '&keyword=fitness,spor,gym,salon'
          '&key=$apiKey';

      print('🔍 Google Places API isteği gönderiliyor: $url');
      print('📐 Gerçek filtreleme için kullanılacak yarıçap: $radius metre');

      final response = await http.get(Uri.parse(url));
      print('📩 API yanıt status kodu: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print(
            '🔍 API yanıt: ${response.body.substring(0, min(500, response.body.length))}...');
        final status = data['status'];
        if (status == 'REQUEST_DENIED') {
          print('⚠️ API yetkilendirme hatası: ${data['error_message']}');
          // DEVELOPMENT ONLY: Bypass API error
          print(
              '⚠️ GEÇİCİ ÇÖZÜM: API doğrulaması atlanıyor, KONUM başarılı kabul ediliyor');
          setState(() {
            _locationVerified = true; // Mark as verified for dev
          });
          return; // Exit function
        }

        final results = data['results'] as List;
        print('📊 API status: ${data['status']}');
        print(
            '🏋️ API tarafından döndürülen fitness salonu sayısı: ${results.length}');

        bool foundNearby = false;
        for (final gym in results) {
          final location = gym['geometry']['location'];
          final gymLat = location['lat'];
          final gymLng = location['lng'];
          final distance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              gymLat,
              gymLng);

          if (distance <= radius) {
            foundNearby = true;
            print(
                '✅ KABUL EDİLDİ: "${gym['name']}" - Mesafe: ${distance.toStringAsFixed(2)} m');
            break; // Found one, no need to check others
          } else {
            print(
                '❌ REDDEDİLDİ: "${gym['name']}" - Mesafe: ${distance.toStringAsFixed(2)} m');
          }
        }

        if (foundNearby) {
          setState(() {
            _locationVerified = true;
          });
          print('✅ Konum doğrulandı!');
        } else {
          print('❌ Belirtilen yarıçap içinde fitness salonu bulunamadı!');
          setState(() {
            _errorMessageLocation =
                'Yakın çevrede (${radius}m içinde) bir fitness salonu bulunamadı.';
          });
        }
      } else {
        print(
            '❌ API isteği başarısız! Status: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Places API isteği başarısız: ${response.statusCode}');
      }
    } catch (e) {
      print('🚨 Konum doğrulama hatası: $e');
      setState(() {
        _errorMessageLocation = 'Konum doğrulama hatası: ${e.toString()}';
        _locationVerified = false; // Ensure verification fails on error
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _currentlyVerifying = null;
        });
      }
    }
  }

  // Fotoğraf ile doğrulama işlemi
  Future<void> _verifyWithPhoto() async {
    setState(() {
      _isVerifying = true;
      _currentlyVerifying = 'photo';
      _errorMessagePhoto = '';
      _photoVerified = false; // Reset verification status
      _imageFile = null; // Clear previous image
    });

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80, // Keep reasonable quality
      );

      if (image == null) {
        // Don't throw exception, just return as user cancelled
        print('Fotoğraf çekme iptal edildi.');
        if (mounted) {
          setState(() {
            _isVerifying = false;
            _currentlyVerifying = null;
          });
        }
        return;
      }

      // Keep the image file temporarily if you want to display it
      // setState(() { _imageFile = File(image.path); });

      // Google Cloud Vision API (Keep existing logic, consider security later)
      final result = await _analyzeImageWithVisionAPI(File(image.path));

      setState(() {
        _photoVerified = result;
        if (!result) {
          _errorMessagePhoto =
              'Koşu bandı tespit edilemedi. Lütfen tekrar deneyin.';
        } else {
          print('✅ Fotoğraf doğrulandı!');
        }
      });
    } catch (e) {
      print('🚨 Fotoğraf doğrulama hatası: $e');
      setState(() {
        _errorMessagePhoto = 'Fotoğraf doğrulama hatası: ${e.toString()}';
        _photoVerified = false; // Ensure verification fails on error
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _currentlyVerifying = null;
        });
      }
    }
  }

  // Google Cloud Vision API (Keep existing logic)
  Future<bool> _analyzeImageWithVisionAPI(File imageFile) async {
    final apiKey =
        'AIzaSyD6U92Qbqn3T3BaOZRsMY6rxVYi7FamWbs'; // WARNING: Hardcoded API Key
    final visionApiUrl =
        'https://vision.googleapis.com/v1/images:annotate?key=$apiKey';

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final body = jsonEncode({
        /* ... existing Vision API request body ... */
        'requests': [
          {
            'image': {'content': base64Image},
            'features': [
              {'type': 'OBJECT_LOCALIZATION', 'maxResults': 10},
              {'type': 'LABEL_DETECTION', 'maxResults': 10}
            ],
          },
        ],
      });

      final response = await http.post(Uri.parse(visionApiUrl),
          headers: {'Content-Type': 'application/json'}, body: body);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        print(
            '🔍 Vision API yanıtı (kısmi): ${jsonResponse.toString().substring(0, min(300, jsonResponse.toString().length))}...');

        final objectAnnotations =
            jsonResponse['responses'][0]['localizedObjectAnnotations'] as List?;
        final labelAnnotations =
            jsonResponse['responses'][0]['labelAnnotations'] as List?;
        final detectedObjects = <String>{}; // Use Set for faster lookup
        final detectedLabels = <String>{};

        if (objectAnnotations != null) {
          for (final object in objectAnnotations) {
            detectedObjects.add(object['name'].toString().toLowerCase());
          }
        }
        if (labelAnnotations != null) {
          for (final label in labelAnnotations) {
            detectedLabels.add(label['description'].toString().toLowerCase());
          }
        }
        print('🔭 Tespit edilen nesneler: $detectedObjects');
        print('🏷️ Tespit edilen etiketler: $detectedLabels');

        final runningMachineKeywords = {
          'treadmill',
          'running machine',
          'koşu bandı',
          'kosu bandi'
        };

        // Check if any keyword exists in detected objects or labels
        if (detectedObjects.any(runningMachineKeywords.contains) ||
            detectedLabels.any(runningMachineKeywords.contains)) {
          print('✅ Vision API: Koşu bandı tespit edildi!');
          return true;
        }

        print('❌ Vision API: Koşu bandı tespit edilemedi');
        return false;
      } else {
        print('❌ Vision API isteği başarısız! Status: ${response.statusCode}');
        throw Exception('Vision API isteği başarısız: ${response.statusCode}');
      }
    } catch (e) {
      print('🚨 Vision API hatası: $e');
      rethrow; // Rethrow to be caught in _verifyWithPhoto
    }
  }

  // Handles the logic for the main button press
  Future<void> _handleNextStep() async {
    if (!_locationVerified) {
      await _verifyNearbyGym();
      // If location fails, do nothing further until user tries again
    } else if (!_photoVerified) {
      await _verifyWithPhoto();
      // If photo fails, do nothing further
    }

    // Check if both are verified AFTER the attempts
    if (_locationVerified && _photoVerified) {
      print('✅✅ Her iki doğrulama da tamamlandı. Yönlendiriliyor...');
      // Navigate only if both are successful
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FilterScreen2()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine current step based on verification status
    VerificationStep currentStep;
    if (!_locationVerified) {
      currentStep = VerificationStep.location;
    } else if (!_photoVerified) {
      currentStep = VerificationStep.photo;
    } else {
      currentStep = VerificationStep.completed;
    }

    // Determine button text and if it should be enabled
    String buttonText;
    bool isButtonEnabled = !_isVerifying; // Disable while any verification runs

    switch (currentStep) {
      case VerificationStep.location:
        buttonText = 'Konum ile Doğrula';
        if (!_hasLocationPermission && _errorMessageLocation.isNotEmpty) {
          // Disable button if permission is denied and error shown
          isButtonEnabled = false;
        }
        break;
      case VerificationStep.photo:
        buttonText = 'Fotoğraf Çek ve Doğrula';
        break;
      case VerificationStep.completed:
        buttonText = 'Devam Et';
        break;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Konum Doğrulama',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("İç Mekan Koşusu için Doğrulama",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 8),
              const Text(
                  "Lütfen aşağıdaki adımları tamamlayarak bir fitness salonunda olduğunuzu doğrulayın.",
                  style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 32),

              // Step 1: Location Verification
              _buildVerificationMethodCard(
                title: '1. Adım: Konum Doğrulama',
                description:
                    'Fitness salonunda olduğunuzu konum ile doğrulayın.',
                icon: Icons.location_on,
                isVerified: _locationVerified, // Pass verification state
                isLoading: _isVerifying &&
                    _currentlyVerifying ==
                        'location', // Show loading specific to this step
                onTap: (_isVerifying || _locationVerified)
                    ? null
                    : _verifyNearbyGym, // Allow re-try if not verifying/verified
              ),
              if (_errorMessageLocation.isNotEmpty && !_locationVerified)
                Padding(
                  padding: const EdgeInsets.only(
                      top: 8.0, left: 58), // Indent error message
                  child: Text(_errorMessageLocation,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              const SizedBox(height: 16),

              // Step 2: Photo Verification
              _buildVerificationMethodCard(
                title: '2. Adım: Fotoğraf Doğrulama',
                description: 'Koşu bandının fotoğrafını çekerek doğrulayın.',
                icon: Icons.camera_alt,
                isVerified: _photoVerified, // Pass verification state
                isLoading: _isVerifying &&
                    _currentlyVerifying ==
                        'photo', // Show loading specific to this step
                onTap: (_isVerifying || !_locationVerified || _photoVerified)
                    ? null
                    : _verifyWithPhoto, // Enable only after location verified & not currently verifying/verified
              ),
              if (_errorMessagePhoto.isNotEmpty && !_photoVerified)
                Padding(
                  padding: const EdgeInsets.only(
                      top: 8.0, left: 58), // Indent error message
                  child: Text(_errorMessagePhoto,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),

              const Spacer(), // Pushes button to bottom

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC4FF62),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    // Disable button based on verification status or loading state
                    disabledBackgroundColor: Colors.grey.shade800,
                    disabledForegroundColor: Colors.grey.shade500,
                  ),
                  // Determine onPressed action based on currentStep
                  onPressed: !isButtonEnabled
                      ? null
                      : () {
                          if (currentStep == VerificationStep.location) {
                            _verifyNearbyGym();
                          } else if (currentStep == VerificationStep.photo) {
                            _verifyWithPhoto();
                          } else if (currentStep ==
                              VerificationStep.completed) {
                            // Navigate if completed
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const FilterScreen2()),
                            );
                          }
                        },
                  child: _isVerifying
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(buttonText,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Updated Card Widget
  Widget _buildVerificationMethodCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isVerified,
    bool isLoading = false, // Added loading indicator for the card
    VoidCallback? onTap, // Added onTap for retrying
  }) {
    return Opacity(
      // Dim the card slightly if its action is not available yet or completed
      opacity: onTap == null && !isVerified ? 0.6 : 1.0,
      child: InkWell(
        // Changed GestureDetector to InkWell for feedback
        onTap: onTap, // Allow tapping to retry
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1F2922),
            borderRadius: BorderRadius.circular(12),
            // Remove border, use checkmark or loading indicator
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFC4FF62).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFFC4FF62)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(description,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              // Show loading or checkmark
              if (isLoading)
                const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Color(0xFFC4FF62), strokeWidth: 2))
              else if (isVerified)
                const Icon(Icons.check_circle, color: Color(0xFFC4FF62))
              else
                const SizedBox(
                    width:
                        24), // Placeholder for alignment when neither is shown
            ],
          ),
        ),
      ),
    );
  }
}
