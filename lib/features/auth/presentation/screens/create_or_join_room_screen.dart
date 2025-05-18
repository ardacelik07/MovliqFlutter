import 'dart:convert'; // Added for jsonEncode/Decode
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/core/config/api_config.dart'; // Added for ApiConfig
import 'package:my_flutter_project/core/services/http_interceptor.dart'; // Added for HttpInterceptor
import 'package:my_flutter_project/features/auth/presentation/screens/waitingRoom_screen.dart'; // Added for WaitingRoomScreen
import 'package:intl/intl.dart'; // For DateTime formatting

class CreateOrJoinRoomScreen extends ConsumerStatefulWidget {
  const CreateOrJoinRoomScreen({super.key});

  @override
  ConsumerState<CreateOrJoinRoomScreen> createState() =>
      _CreateOrJoinRoomScreenState();
}

class _CreateOrJoinRoomScreenState extends ConsumerState<CreateOrJoinRoomScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _roomCodeController = TextEditingController();
  final _entryCoinController = TextEditingController();

  String? _selectedRoomType; // 'indoor' or 'outdoor'
  int? _selectedDuration; // 1, 5, 10, 20

  final List<int> _durationOptions = [1, 5, 10, 20];
  bool _isLoadingJoin = false; // Loading state for joining room
  bool _isLoadingCreate = false; // Loading state for creating room

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedRoomType = 'outdoor'; // Default selection changed to outdoor
    _selectedDuration = _durationOptions.first;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _roomCodeController.dispose();
    _entryCoinController.dispose();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    if (_roomCodeController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen bir oda kodu girin.')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingJoin = true;
      });
    }

    try {
      final enteredRoomCode =
          _roomCodeController.text; // Store before clearing or changing
      final response = await HttpInterceptor.post(
        Uri.parse(ApiConfig.joinRoomWithCodeEndpoint),
        body: jsonEncode({'roomCode': enteredRoomCode}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Handle roomId robustly (can be String or int from API)
        final dynamic rawRoomId = responseData['roomId'];
        final String? roomIdString = rawRoomId?.toString();

        if (roomIdString == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Oda ID bilgisi yanıtta bulunamadı.')),
            );
          }
          setState(() {
            _isLoadingJoin = false;
          }); // Reset loading state
          return;
        }

        final int? roomId = int.tryParse(roomIdString);
        // final String roomName = responseData['roomName']?.toString(); // Keep for future reference if needed

        if (roomId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Geçersiz oda ID formatı alındı.')),
            );
          }
          setState(() {
            _isLoadingJoin = false;
          }); // Reset loading state
          return;
        }

        // Handle message robustly for SnackBar
        final String messageText = responseData['message']?.toString() ??
            'Odaya başarıyla katıldınız!';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(messageText)),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WaitingRoomScreen(
                roomId: roomId,
                roomCode: enteredRoomCode, // Pass the entered room code
                isHost: false, // User joining is not the host
                // TODO: Check if WaitingRoomScreen needs roomName etc.
              ),
            ),
          );
        }
      } else {
        final responseData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(responseData['message'] ??
                    'Odaya katılırken bir hata oluştu. Kod: ${response.statusCode}')), // Corrected SnackBar message
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bir hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingJoin = false;
        });
      }
    }
  }

  Future<void> _createRoom() async {
    final String entryCoinText = _entryCoinController.text;
    if (entryCoinText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Lütfen giriş için coin miktarı girin.')),
        );
      }
      return;
    }

    final int? entryCoin = int.tryParse(entryCoinText);
    if (entryCoin == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Lütfen geçerli bir coin miktarı girin.')),
        );
      }
      return;
    }

    if (_selectedDuration == null || _selectedRoomType == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen oda tipi ve süresini seçin.')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingCreate = true;
      });
    }

    try {
      final requestBody = {
        'roomName': 'createdroom',
        'startTime': DateFormat("yyyy-MM-ddTHH:mm:ss.SSS'Z'", 'en_US').format(
            DateTime.now()
                .toUtc()), // Ensure correct ISO8601 format with milliseconds and Z
        'duration': _selectedDuration,
        'roomType': _selectedRoomType,
        'entryCoin': entryCoin,
        'minParticipants': 2,
        'maxParticipants': 8,
      };
      final response = await HttpInterceptor.post(
        Uri.parse(ApiConfig.createRaceRoomEndpoint),
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final String? roomCode = responseData['roomCode']?.toString();
        final dynamic rawRoomId = responseData['roomId']; // Get the new roomId
        final String? roomIdString = rawRoomId?.toString();

        if (roomCode == null || roomCode.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Room code not found in response.')),
            );
          }
          return;
        }

        if (roomIdString == null || roomIdString.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Room ID not found in response.')),
            );
          }
          return;
        }

        final int? roomId = int.tryParse(roomIdString);
        if (roomId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Invalid Room ID format in response.')),
            );
          }
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Room successfully created! Code: $roomCode. Joining room...')),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WaitingRoomScreen(
                roomId: roomId,
                roomCode: roomCode, // Pass the created room code
                isHost: true, // User creating the room is the host
                duration: _selectedDuration, // Pass the selected duration
                // TODO: Check if WaitingRoomScreen needs other params like roomName etc.
              ),
            ),
          );
        }
      } else {
        final responseData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(responseData['message']?.toString() ??
                    'Error creating room. Code: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCreate = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode =
        theme.brightness == Brightness.dark; // Helper for text colors if needed

    return Scaffold(
      backgroundColor: Colors.black, // Set background to black
      appBar: AppBar(
        title: const Text('Özel Oda',
            style: TextStyle(color: Colors.white)), // Ensure title is visible
        backgroundColor: Colors.grey[900], // Darker appbar
        iconTheme: const IconThemeData(
            color: Colors.white), // Ensure back button is visible
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white, // Selected tab text color
          unselectedLabelColor: Colors.grey[400], // Unselected tab text color
          indicatorColor: const Color(0xFFC4FF62), // Accent color for indicator
          tabs: const [
            Tab(text: 'Odaya Katıl'),
            Tab(text: 'Oda Oluştur'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildJoinRoomTab(),
          _buildCreateRoomTab(),
        ],
      ),
    );
  }

  Widget _buildJoinRoomTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          TextFormField(
            controller: _roomCodeController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Oda Kodu',
              labelStyle: TextStyle(color: Colors.grey[400]),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFC4FF62)),
              ),
              border: const OutlineInputBorder(),
            ),
            enabled: !_isLoadingJoin, // Disable when loading
          ),
          const SizedBox(height: 20),
          _isLoadingJoin
              ? const CircularProgressIndicator(color: Color(0xFFC4FF62))
              : ElevatedButton(
                  onPressed: _joinRoom,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC4FF62),
                      foregroundColor: Colors.black),
                  child: const Text('Odaya Katıl'),
                ),
        ],
      ),
    );
  }

  Widget _buildCreateRoomTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Oda Tipi:',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 8),
            ToggleButtons(
              isSelected: [
                _selectedRoomType == 'indoor',
                _selectedRoomType == 'outdoor'
              ],
              onPressed: (int index) {
                setState(() {
                  _selectedRoomType = index == 0 ? 'indoor' : 'outdoor';
                });
              },
              borderColor: Colors.grey[600],
              selectedBorderColor: const Color(0xFFC4FF62),
              selectedColor: Colors.black, // Text color when selected
              color: Colors.white, // Text color when not selected
              fillColor:
                  const Color(0xFFC4FF62), // Background color when selected
              borderRadius: BorderRadius.circular(8),
              children: const <Widget>[
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('İç Mekan')),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('Dış Mekan')),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Süre (dakika):',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _selectedDuration,
              style: const TextStyle(
                  color:
                      Colors.black), // Text color for selected item in dropdown
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white, // Background of dropdown
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none),
              ),
              items: _durationOptions.map<DropdownMenuItem<int>>((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text('$value dakika',
                      style: const TextStyle(
                          color: Colors.black)), // Ensure item text is visible
                );
              }).toList(),
              onChanged: (int? newValue) {
                setState(() {
                  _selectedDuration = newValue;
                });
              },
              dropdownColor: Colors.white, // Background of dropdown menu
            ),
            const SizedBox(height: 20),
            const Text('Giriş Coini:',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _entryCoinController,
              style: const TextStyle(color: Colors.white), // Input text color
              decoration: InputDecoration(
                labelText: 'Coin Miktarı',
                labelStyle: TextStyle(color: Colors.grey[400]),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFC4FF62)),
                ),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 30),
            Center(
              child: _isLoadingCreate
                  ? const CircularProgressIndicator(color: Color(0xFFC4FF62))
                  : ElevatedButton(
                      onPressed: _createRoom,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC4FF62),
                          foregroundColor: Colors.black),
                      child: const Text('Oda Oluştur'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
