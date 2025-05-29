import 'dart:convert'; // Added for jsonEncode/Decode
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_flutter_project/core/config/api_config.dart'; // Added for ApiConfig
import 'package:my_flutter_project/core/services/http_interceptor.dart'; // Added for HttpInterceptor
import 'package:my_flutter_project/features/auth/presentation/screens/waitingRoom_screen.dart'; // Added for WaitingRoomScreen
import 'package:intl/intl.dart'; // For DateTime formatting
import 'package:google_fonts/google_fonts.dart';

// Define colors for consistency at file level
const Color _kAccentColor = Color(0xFFC4FF62);
const Color _kDarkBackgroundColor = Colors.black;
const Color _kInputFillColor = Color(0xFF2A2A2A);
const Color _kLightTextColor = Colors.white;
const Color _kHintTextColor = Colors.grey;
final Color _kUnselectedTabIconColor = Colors.grey[400]!;

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
    // Add listener to rebuild tabs on swipe for selection style
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _selectedRoomType = 'outdoor';
    _selectedDuration = _durationOptions.first;
  }

  @override
  void dispose() {
    _tabController.removeListener(() {}); // Remove listener
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

        // API'den gelen roomType ve roomDuration değerlerini al
        final String? apiRoomType = responseData['roomType']?.toString();
        final dynamic apiRawRoomDuration = responseData['roomDuration'];
        final int? apiRoomDuration = apiRawRoomDuration is int
            ? apiRawRoomDuration
            : (apiRawRoomDuration is String
                ? int.tryParse(apiRawRoomDuration)
                : null);

        if (roomIdString == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Oda ID bilgisi yanıtta bulunamadı.')),
            );
          }
          if (mounted)
            setState(() => _isLoadingJoin = false); // Ensure mounted check
          return;
        }

        final int? roomId = int.tryParse(roomIdString);
        if (roomId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Geçersiz oda ID formatı alındı.')),
            );
          }
          if (mounted)
            setState(() => _isLoadingJoin = false); // Ensure mounted check
          return;
        }

        // roomType ve roomDuration kontrolü
        if (apiRoomType == null || apiRoomType.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Oda tipi bilgisi yanıtta bulunamadı veya geçersiz.')),
            );
          }
          if (mounted) setState(() => _isLoadingJoin = false);
          return;
        }

        if (apiRoomDuration == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Oda süresi bilgisi yanıtta bulunamadı veya geçersiz.')),
            );
          }
          if (mounted) setState(() => _isLoadingJoin = false);
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
                activityType: apiRoomType, // API'den gelen roomType'ı kullan
                duration:
                    apiRoomDuration, // API'den gelen roomDuration'ı kullan
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
          if (mounted)
            setState(() => _isLoadingCreate = false); // Ensure mounted check
          return;
        }

        if (roomIdString == null || roomIdString.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Oda ID yanıtta bulunamadı.')),
            );
          }
          if (mounted)
            setState(() => _isLoadingCreate = false); // Ensure mounted check
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
          if (mounted)
            setState(() => _isLoadingCreate = false); // Ensure mounted check
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
      {Widget? prefixIcon, String? hintText}) {
    // Changed IconData to Widget
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle: GoogleFonts.bangers(color: _kHintTextColor),
      hintStyle: GoogleFonts.bangers(color: _kHintTextColor),
      prefixIcon: prefixIcon, // Use Widget directly
      filled: true,
      fillColor: _kInputFillColor,
      contentPadding: const EdgeInsets.symmetric(
          vertical: 18.0, horizontal: 16.0), // Added content padding
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
            color: Colors.white.withOpacity(0.5), width: 1.5), // Updated border
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _kAccentColor, width: 2),
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
      backgroundColor: _kAccentColor,
      foregroundColor: _kDarkBackgroundColor,
      minimumSize:
          const Size(double.infinity, 60), // Increased height from 50 to 60
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: GoogleFonts.bangers(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  // Helper to build tab content for the TabBar
  Widget _buildTabContent(String imagePath, String text, int tabIndex) {
    bool isSelected = _tabController.index == tabIndex;
    return Container(
      height: 45, // Fixed height for tab buttons
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? _kAccentColor.withOpacity(0.15)
            : _kDarkBackgroundColor,
        borderRadius: BorderRadius.circular(30), // Fully rounded corners
        border: Border.all(
          color: isSelected ? _kAccentColor : Colors.grey[700]!,
          width: isSelected ? 2.0 : 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.bangers(
              color: isSelected ? _kAccentColor : _kUnselectedTabIconColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDarkBackgroundColor,
      appBar: AppBar(
        title: Text('Özel Oda',
            style: GoogleFonts.bangers(
                color: _kLightTextColor, fontWeight: FontWeight.bold)),
        backgroundColor: _kDarkBackgroundColor, // Match screen background
        elevation: 0,
        iconTheme: const IconThemeData(color: _kLightTextColor),
        bottom: PreferredSize(
          // Use PreferredSize for custom height
          preferredSize: const Size.fromHeight(60.0), // Adjust height as needed
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.transparent, // Hide default indicator line
              indicatorPadding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(
                  horizontal: 4.0), // spacing between tabs
              dividerColor: Colors.transparent, // Hide default divider
              onTap: (index) {
                // setState is called by the listener
              },
              tabs: [
                Tab(
                    child: _buildTabContent(
                        'assets/icons/add.png', 'Odaya Katıl', 0)),
                Tab(
                    child: _buildTabContent(
                        'assets/icons/create.png', 'Oda Oluştur', 1)),
              ],
            ),
          ),
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
  final InputDecoration Function(String, {Widget? prefixIcon, String? hintText})
      buildInputDecoration; // Updated to Widget
  final ButtonStyle Function() buildElevatedButtonStyle;

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
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center, // Center content vertically
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Placeholder for the character image.
            // TODO: User, please add your character image to 'assets/images/team_characters.png'
            // and uncomment the line below, or replace with your actual asset.
            // Image.asset('assets/images/team_characters.png', height: 200, fit: BoxFit.contain),
            // Using a container as a placeholder for now
            Container(
              height: 400,
              margin: const EdgeInsets.only(bottom: 10),
              // decoration: BoxDecoration(
              //   border: Border.all(color: Colors.grey),
              //   borderRadius: BorderRadius.circular(12),
              // ),
              // child: const Center(child: Text('Your Image Here', style: TextStyle(color: _lightTextColor))),
              // Temporary: Using one of the provided assets as a placeholder visually
              child: Image.asset('assets/images/createroom.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Center(
                      child: Text('Error loading image',
                          style: GoogleFonts.bangers(color: Colors.red)))),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: roomCodeController,
              style: GoogleFonts.bangers(color: _kLightTextColor),
              decoration: buildInputDecoration(
                'Oda Kodu Giriniz',
                hintText: 'Oda Kodu Giriniz',
                prefixIcon: Padding(
                  // Add padding to the icon if needed
                  padding: const EdgeInsets.all(12.0),
                  child: Image.asset(
                    'assets/icons/getin.png', // Reverted to getin.png as roomcode.png does not exist
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
              textAlign: TextAlign.center,
              enabled: !isLoadingJoin,
            ),
            const SizedBox(height: 24),
            isLoadingJoin
                ? const Center(
                    child: CircularProgressIndicator(color: _kAccentColor))
                : ElevatedButton.icon(
                    icon: Image.asset(
                      'assets/icons/join.png', // As per image, this is the open locker icon
                      width: 24,
                      height: 24,
                    ),
                    label: const Text('Odaya Katıl'),
                    onPressed: isLoadingJoin ? null : onJoinRoomPressed,
                    style: buildElevatedButtonStyle(),
                  ),
          ],
        ),
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
  final InputDecoration Function(String, {Widget? prefixIcon, String? hintText})
      buildInputDecoration;
  final ButtonStyle Function() buildElevatedButtonStyle;

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
            const SizedBox(
                height: 16), // Adjusted from 24, as image was removed
            Text('Oda Tipi:',
                style: GoogleFonts.bangers(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _kLightTextColor)),
            const SizedBox(height: 16), // Increased from 12
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
              selectedBorderColor: _kAccentColor,
              selectedColor: _kDarkBackgroundColor,
              color: _kLightTextColor,
              fillColor: _kAccentColor,
              borderRadius: BorderRadius.circular(12),
              constraints: BoxConstraints(
                  minHeight: 55,
                  minWidth: (MediaQuery.of(context).size.width - 48 - 12) / 2),
              children: <Widget>[
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(children: [
                      Image.asset('assets/icons/indoor.png',
                          width: 25, height: 25),
                      const SizedBox(width: 8),
                      Text('İç Mekan',
                          style: GoogleFonts.bangers(
                              fontSize: 15.0)) // Increased font size
                    ])),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(children: [
                      Image.asset('assets/icons/outdoor.png',
                          width: 25, height: 25),
                      const SizedBox(width: 8),
                      Text('Dış Mekan',
                          style: GoogleFonts.bangers(
                              fontSize: 15.0)) // Increased font size
                    ])),
              ],
            ),
            const SizedBox(height: 30), // Increased from 24
            Text('Süre (dakika):',
                style: GoogleFonts.bangers(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _kLightTextColor)),
            const SizedBox(height: 16), // Increased from 12
            // --- DURATION PICKER ---
            GestureDetector(
              onTap: () {
                _showDurationPicker(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 18.0, horizontal: 16.0),
                decoration: BoxDecoration(
                  color: _kInputFillColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.5), width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _internalSelectedDuration != null
                          ? '$_internalSelectedDuration dakika'
                          : 'Süre Seçin',
                      style: GoogleFonts.bangers(
                          color: _kLightTextColor, fontSize: 16),
                    ),
                    const Icon(Icons.arrow_drop_down, color: _kLightTextColor),
                  ],
                ),
              ),
            ),
            // --- END DURATION PICKER ---
            const SizedBox(height: 30), // Increased from 24
            Text('Giriş Coini:',
                style: GoogleFonts.bangers(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _kLightTextColor)),
            const SizedBox(height: 16), // Increased from 12
            TextFormField(
              controller: widget.entryCoinController,
              style: GoogleFonts.bangers(color: _kLightTextColor),
              decoration: widget.buildInputDecoration('Coin Miktarı',
                  prefixIcon: Image.asset('assets/images/mCoin.png',
                      width: 24,
                      height: 24), // Increased icon size from 10x10 to 24x24
                  hintText: 'Örn: 100'),
              keyboardType: TextInputType.number,
              enabled: !widget.isLoadingCreate,
            ),
            const SizedBox(height: 40), // Increased from 32
            widget.isLoadingCreate
                ? const Center(
                    child: CircularProgressIndicator(color: _kAccentColor))
                : ElevatedButton.icon(
                    icon: Image.asset(
                      'assets/icons/createroom1.png', // Using add icon for create button
                      width: 24,
                      height: 24,
                    ),
                    label: const Text('Oda Oluştur'),
                    onPressed: widget.isLoadingCreate
                        ? null
                        : widget.onCreateRoomPressed,
                    style: widget.buildElevatedButtonStyle(),
                  ),
            const SizedBox(height: 24), // Increased from 16
          ],
        ),
      ),
    );
  }

  // --- CUSTOM DURATION PICKER METHOD ---
  void _showDurationPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E), // Dark background for the sheet
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (BuildContext bottomSheetContext) {
        // Changed context variable name
        return StatefulBuilder(
          // To update selection within the sheet
          builder: (BuildContext modalContext, StateSetter modalSetState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sürenizi Seçiniz',
                        style: GoogleFonts.bangers(
                          color: _kLightTextColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: _kLightTextColor),
                        onPressed: () => Navigator.pop(
                            bottomSheetContext), // Use bottomSheetContext
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: _kAccentColor, thickness: 1),
                  const SizedBox(height: 10),
                  ...widget.durationOptions.map((duration) {
                    final bool isSelected =
                        _internalSelectedDuration == duration;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          modalSetState(() {
                            // Update selection in sheet
                            _internalSelectedDuration = duration;
                          });
                          // Update parent widget's state
                          setState(() {
                            _internalSelectedDuration = duration;
                          });
                          widget.onDurationChanged(duration);
                          Navigator.pop(
                              bottomSheetContext); // Use bottomSheetContext
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 15.0),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _kAccentColor.withOpacity(0.3)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              bottom: BorderSide(
                                color: isSelected
                                    ? _kAccentColor
                                    : Colors.grey[700]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$duration Dakika',
                              style: GoogleFonts.bangers(
                                color: isSelected
                                    ? _kAccentColor
                                    : _kLightTextColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }
  // --- END CUSTOM DURATION PICKER METHOD ---
}
