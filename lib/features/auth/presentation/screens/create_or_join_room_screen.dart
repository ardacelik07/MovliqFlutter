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

  // Define colors for consistency
  static const Color _accentColor = Color(0xFFC4FF62);
  static const Color _darkBackgroundColor = Colors.black;
  static const Color _inputFillColor = Color(0xFF2A2A2A); // Darker input fill
  static const Color _lightTextColor = Colors.white;
  static const Color _hintTextColor = Colors.grey; // Softer hint text

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedRoomType = 'outdoor';
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
      final enteredRoomCode = _roomCodeController.text;
      final response = await HttpInterceptor.post(
        Uri.parse(ApiConfig.joinRoomWithCodeEndpoint),
        body: jsonEncode({'roomCode': enteredRoomCode}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final dynamic rawRoomId = responseData['roomId'];
        final String? roomIdString = rawRoomId?.toString();

        if (roomIdString == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Oda ID bilgisi yanıtta bulunamadı.')),
            );
          }
          setState(() => _isLoadingJoin = false);
          return;
        }

        final int? roomId = int.tryParse(roomIdString);
        if (roomId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Geçersiz oda ID formatı alındı.')),
            );
          }
          setState(() => _isLoadingJoin = false);
          return;
        }

        final String messageText = responseData['message']?.toString() ??
            'Odaya başarıyla katıldınız!';
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(messageText)));
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WaitingRoomScreen(
                roomId: roomId,
                roomCode: enteredRoomCode,
                isHost: false,
                activityType: _selectedRoomType, // Pass selected room type
                duration: _selectedDuration, // Pass selected duration
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
                    'Odaya katılırken bir hata oluştu. Kod: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Bir hata oluştu: $e')));
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
        'startTime': DateFormat("yyyy-MM-ddTHH:mm:ss.SSS'Z'", 'en_US')
            .format(DateTime.now().toUtc()),
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
        final dynamic rawRoomId = responseData['roomId'];
        final String? roomIdString = rawRoomId?.toString();

        if (roomCode == null || roomCode.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Oda kodu yanıtta bulunamadı.')),
            );
          }
          setState(() => _isLoadingCreate = false);
          return;
        }

        if (roomIdString == null || roomIdString.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Oda ID yanıtta bulunamadı.')),
            );
          }
          setState(() => _isLoadingCreate = false);
          return;
        }

        final int? roomId = int.tryParse(roomIdString);
        if (roomId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Geçersiz Oda ID formatı yanıtta alındı.')),
            );
          }
          setState(() => _isLoadingCreate = false);
          return;
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => WaitingRoomScreen(
                roomId: roomId,
                roomCode: roomCode,
                isHost: true,
                duration: _selectedDuration,
                activityType: _selectedRoomType,
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
                    'Oda oluşturulurken hata. Kod: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Bir hata oluştu: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCreate = false;
        });
      }
    }
  }

  // Helper for input decoration
  InputDecoration _buildInputDecoration(String label,
      {IconData? prefixIcon, String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle: const TextStyle(color: _hintTextColor),
      hintStyle: const TextStyle(color: _hintTextColor),
      prefixIcon:
          prefixIcon != null ? Icon(prefixIcon, color: _accentColor) : null,
      filled: true,
      fillColor: _inputFillColor,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey[700]!),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _accentColor, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  // Helper for elevated button style
  ButtonStyle _buildElevatedButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _accentColor,
      foregroundColor: _darkBackgroundColor,
      minimumSize: const Size(double.infinity, 50), // Full width, fixed height
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBackgroundColor,
      appBar: AppBar(
        title: const Text('Özel Oda',
            style:
                TextStyle(color: _lightTextColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey[900]?.withOpacity(0.8),
        elevation: 0, // Changed elevation to 0 to remove the line/shadow
        iconTheme: const IconThemeData(color: _lightTextColor),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _accentColor, // Selected tab text color
          unselectedLabelColor: _hintTextColor,
          indicatorColor: _accentColor,
          indicatorWeight: 3.0, // Make indicator thicker
          indicatorPadding: const EdgeInsets.symmetric(
              horizontal: 8.0), // Add padding to indicator
          tabs: const [
            Tab(
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.group_add_outlined),
                  SizedBox(width: 8),
                  Text('Odaya Katıl')
                ])),
            Tab(
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.add_box_outlined),
                  SizedBox(width: 8),
                  Text('Oda Oluştur')
                ])),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _JoinRoomTabWidget(
            roomCodeController: _roomCodeController,
            isLoadingJoin: _isLoadingJoin,
            onJoinRoomPressed: _joinRoom,
            buildInputDecoration: _buildInputDecoration,
            buildElevatedButtonStyle: _buildElevatedButtonStyle,
          ),
          _CreateRoomTabWidget(
            selectedRoomType: _selectedRoomType,
            selectedDuration: _selectedDuration,
            durationOptions: _durationOptions,
            entryCoinController: _entryCoinController,
            isLoadingCreate: _isLoadingCreate,
            onRoomTypeChanged: (value) {
              setState(() {
                _selectedRoomType = value;
              });
            },
            onDurationChanged: (value) {
              setState(() {
                _selectedDuration = value;
              });
            },
            onCreateRoomPressed: _createRoom,
            buildInputDecoration: _buildInputDecoration,
            buildElevatedButtonStyle: _buildElevatedButtonStyle,
          ),
        ],
      ),
    );
  }
}

//############################################################################
// Join Room Tab Widget
//############################################################################
class _JoinRoomTabWidget extends ConsumerWidget {
  final TextEditingController roomCodeController;
  final bool isLoadingJoin;
  final Future<void> Function() onJoinRoomPressed;
  final InputDecoration Function(String,
      {IconData? prefixIcon, String? hintText}) buildInputDecoration;
  final ButtonStyle Function() buildElevatedButtonStyle;
  static const Color _accentColor = _CreateOrJoinRoomScreenState._accentColor;
  static const Color _lightTextColor =
      _CreateOrJoinRoomScreenState._lightTextColor;

  const _JoinRoomTabWidget({
    // super.key, // ConsumerWidget does not need a key in its constructor in this context if not passed down
    required this.roomCodeController,
    required this.isLoadingJoin,
    required this.onJoinRoomPressed,
    required this.buildInputDecoration,
    required this.buildElevatedButtonStyle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextFormField(
            controller: roomCodeController,
            style: const TextStyle(color: _lightTextColor),
            decoration: buildInputDecoration('Oda Kodu',
                prefixIcon: Icons.sensor_door_outlined, hintText: 'ABCXYZ'),
            enabled: !isLoadingJoin,
          ),
          const SizedBox(height: 24),
          isLoadingJoin
              ? const Center(
                  child: CircularProgressIndicator(color: _accentColor))
              : ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Odaya Katıl'),
                  onPressed: isLoadingJoin ? null : onJoinRoomPressed,
                  style: buildElevatedButtonStyle(),
                ),
        ],
      ),
    );
  }
}

//############################################################################
// Create Room Tab Widget
//############################################################################
class _CreateRoomTabWidget extends ConsumerStatefulWidget {
  final String? selectedRoomType;
  final int? selectedDuration;
  final List<int> durationOptions;
  final TextEditingController entryCoinController;
  final bool isLoadingCreate;
  final void Function(String?) onRoomTypeChanged;
  final void Function(int?) onDurationChanged;
  final Future<void> Function() onCreateRoomPressed;
  final InputDecoration Function(String,
      {IconData? prefixIcon, String? hintText}) buildInputDecoration;
  final ButtonStyle Function() buildElevatedButtonStyle;
  static const Color _accentColor = _CreateOrJoinRoomScreenState._accentColor;
  static const Color _lightTextColor =
      _CreateOrJoinRoomScreenState._lightTextColor;
  static const Color _darkBackgroundColor =
      _CreateOrJoinRoomScreenState._darkBackgroundColor;
  static const Color _inputFillColor =
      _CreateOrJoinRoomScreenState._inputFillColor;

  const _CreateRoomTabWidget({
    // super.key, // ConsumerStatefulWidget does not need a key in its constructor in this context
    required this.selectedRoomType,
    required this.selectedDuration,
    required this.durationOptions,
    required this.entryCoinController,
    required this.isLoadingCreate,
    required this.onRoomTypeChanged,
    required this.onDurationChanged,
    required this.onCreateRoomPressed,
    required this.buildInputDecoration,
    required this.buildElevatedButtonStyle,
  });

  @override
  ConsumerState<_CreateRoomTabWidget> createState() =>
      _CreateRoomTabWidgetState();
}

class _CreateRoomTabWidgetState extends ConsumerState<_CreateRoomTabWidget> {
  String? _internalSelectedRoomType;
  int? _internalSelectedDuration;

  @override
  void initState() {
    super.initState();
    _internalSelectedRoomType = widget.selectedRoomType;
    _internalSelectedDuration = widget.selectedDuration;
  }

  // When parent state changes, update internal state if widget is rebuilt with new values
  @override
  void didUpdateWidget(covariant _CreateRoomTabWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedRoomType != oldWidget.selectedRoomType) {
      _internalSelectedRoomType = widget.selectedRoomType;
    }
    if (widget.selectedDuration != oldWidget.selectedDuration) {
      _internalSelectedDuration = widget.selectedDuration;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Oda Tipi:',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _CreateRoomTabWidget._lightTextColor)),
            const SizedBox(height: 12),
            ToggleButtons(
              isSelected: [
                _internalSelectedRoomType == 'indoor',
                _internalSelectedRoomType == 'outdoor'
              ],
              onPressed: (int index) {
                final newRoomType = index == 0 ? 'indoor' : 'outdoor';
                setState(() {
                  _internalSelectedRoomType = newRoomType;
                });
                widget.onRoomTypeChanged(newRoomType);
              },
              borderColor: Colors.grey[700],
              selectedBorderColor: _CreateRoomTabWidget._accentColor,
              selectedColor: _CreateRoomTabWidget._darkBackgroundColor,
              color: _CreateRoomTabWidget._lightTextColor,
              fillColor: _CreateRoomTabWidget._accentColor,
              borderRadius: BorderRadius.circular(12),
              constraints: BoxConstraints(
                  minHeight: 45,
                  minWidth: (MediaQuery.of(context).size.width - 48 - 12) / 2),
              children: const <Widget>[
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(children: [
                      Icon(Icons.home_work_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('İç Mekan')
                    ])),
                Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(children: [
                      Icon(Icons.nature_people_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Dış Mekan')
                    ])),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Süre (dakika):',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _CreateRoomTabWidget._lightTextColor)),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _internalSelectedDuration,
              style:
                  const TextStyle(color: _CreateRoomTabWidget._lightTextColor),
              decoration: widget.buildInputDecoration('Süre Seçin',
                  prefixIcon: Icons.timer_outlined),
              dropdownColor: _CreateRoomTabWidget._inputFillColor,
              iconEnabledColor: _CreateRoomTabWidget._accentColor,
              items: widget.durationOptions
                  .map<DropdownMenuItem<int>>((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text('$value dakika',
                      style: const TextStyle(
                          color: _CreateRoomTabWidget._lightTextColor)),
                );
              }).toList(),
              onChanged: widget.isLoadingCreate
                  ? null
                  : (int? newValue) {
                      setState(() {
                        _internalSelectedDuration = newValue;
                      });
                      widget.onDurationChanged(newValue);
                    },
            ),
            const SizedBox(height: 24),
            const Text('Giriş Coini:',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _CreateRoomTabWidget._lightTextColor)),
            const SizedBox(height: 12),
            TextFormField(
              controller: widget.entryCoinController,
              style:
                  const TextStyle(color: _CreateRoomTabWidget._lightTextColor),
              decoration: widget.buildInputDecoration('Coin Miktarı',
                  prefixIcon: Icons.monetization_on_outlined,
                  hintText: 'Örn: 100'),
              keyboardType: TextInputType.number,
              enabled: !widget.isLoadingCreate,
            ),
            const SizedBox(height: 32),
            widget.isLoadingCreate
                ? const Center(
                    child: CircularProgressIndicator(
                        color: _CreateRoomTabWidget._accentColor))
                : ElevatedButton.icon(
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Oda Oluştur'),
                    onPressed: widget.isLoadingCreate
                        ? null
                        : widget.onCreateRoomPressed,
                    style: widget.buildElevatedButtonStyle(),
                  ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
