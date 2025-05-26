import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For date formatting

import '../../domain/models/user_data_model.dart';
import '../providers/user_data_provider.dart';

// Enum definitions matching the visual choices
// It's better practice to use enums for discrete choices.
// Assuming Gender: 0=Kadın, 1=Erkek, 2=Diğer (adjust if values differ)
enum GenderChoice { female, male, other }

// Assuming Activity Level: 0=Düşük, 1=Orta, 2=Yüksek
enum ActivityLevelChoice { low, medium, high }

// Assuming Location Preference: 0=Indoor, 1=Outdoor
enum LocationPreferenceChoice { indoor, outdoor }

class UpdateUserInfoScreen extends ConsumerStatefulWidget {
  const UpdateUserInfoScreen({super.key});

  @override
  ConsumerState<UpdateUserInfoScreen> createState() =>
      _UpdateUserInfoScreenState();
}

class _UpdateUserInfoScreenState extends ConsumerState<UpdateUserInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // --- Theme Colors ---
  final Color _backgroundColor = Colors.black;
  final Color _cardColor = Colors.grey[900]!;
  final Color _textColor = Colors.white;
  final Color _secondaryTextColor = Colors.grey[400]!;
  final Color _accentColor = const Color(0xFFB2FF59); // Light green accent
  final Color _textFieldFillColor = Colors.grey[850]!.withOpacity(0.5);
  final Color _labelColor = Colors.grey[500]!;

  // Controllers for form fields
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  DateTime? _selectedBirthday;
  GenderChoice? _selectedGender; // Using Enum
  ActivityLevelChoice? _selectedActivityLevel; // Using Enum
  LocationPreferenceChoice? _selectedLocationPreference; // Using Enum

  // Map database values to enums and vice-versa if needed
  // Example: Map integer values from UserDataModel to enums
  GenderChoice? _mapGenderFromString(String? genderString) {
    if (genderString == null) return null;
    final String lowerGenderString = genderString.toLowerCase();
    if (lowerGenderString == 'female' || lowerGenderString == 'kadın')
      return GenderChoice.female;
    if (lowerGenderString == 'male' || lowerGenderString == 'erkek')
      return GenderChoice.male;
    if (lowerGenderString == 'other' || lowerGenderString == 'diğer')
      return GenderChoice.other;
    return null;
  }

  String? _mapGenderToString(GenderChoice? choice) {
    switch (choice) {
      case GenderChoice.female:
        return 'Female'; // Save as English
      case GenderChoice.male:
        return 'Male'; // Save as English
      case GenderChoice.other:
        return 'Other'; // Save as English
      default:
        return null;
    }
  }

  // Add similar mapping functions for ActivityLevel and LocationPreference if their database values are integers
  ActivityLevelChoice? _mapActivityLevelFromInt(int? value) {
    if (value == 0) return ActivityLevelChoice.low;
    if (value == 1) return ActivityLevelChoice.medium;
    if (value == 2) return ActivityLevelChoice.high;
    return null;
  }

  int? _mapActivityLevelToInt(ActivityLevelChoice? choice) {
    switch (choice) {
      case ActivityLevelChoice.low:
        return 0;
      case ActivityLevelChoice.medium:
        return 1;
      case ActivityLevelChoice.high:
        return 2;
      default:
        return null;
    }
  }

  LocationPreferenceChoice? _mapLocationPreferenceFromInt(int? value) {
    if (value == 0) return LocationPreferenceChoice.indoor;
    if (value == 1) return LocationPreferenceChoice.outdoor;
    return null;
  }

  int? _mapLocationPreferenceToInt(LocationPreferenceChoice? choice) {
    switch (choice) {
      case LocationPreferenceChoice.indoor:
        return 0;
      case LocationPreferenceChoice.outdoor:
        return 1;
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    final currentUser = ref.read(userDataProvider).value;

    _nameController = TextEditingController(text: currentUser?.name ?? '');
    _usernameController =
        TextEditingController(text: currentUser?.userName ?? '');
    _heightController =
        TextEditingController(text: currentUser?.height?.toString() ?? '');
    _weightController =
        TextEditingController(text: currentUser?.weight?.toString() ?? '');
    _selectedBirthday = currentUser?.birthday;

    // Map initial values from user data to enums
    // Assuming `gender`, `active`, `runprefer` are stored as integers in UserDataModel
    _selectedGender = _mapGenderFromString(currentUser?.gender);
    _selectedActivityLevel = _mapActivityLevelFromInt(currentUser?.active);
    _selectedLocationPreference =
        _mapLocationPreferenceFromInt(currentUser?.runprefer);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: _accentColor, // header background color
              onPrimary: Colors.black, // header text color
              onSurface: _textColor, // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _accentColor, // button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedBirthday) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    setState(() => _isLoading = true);

    final currentUser = ref.read(userDataProvider).value;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kullanıcı verisi bulunamadı!',
                style: TextStyle(color: _backgroundColor)),
            backgroundColor: _accentColor,
          ),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    // Create updated UserDataModel from form values
    final updatedUserData = currentUser.copyWith(
      name: _nameController.text.trim(),
      userName: _usernameController.text.trim(),
      height: double.tryParse(_heightController.text.trim()),
      weight: double.tryParse(_weightController.text.trim()),
      gender: _mapGenderToString(_selectedGender),
      birthday: _selectedBirthday,
      active: _mapActivityLevelToInt(_selectedActivityLevel),
      runprefer: _mapLocationPreferenceToInt(_selectedLocationPreference),
    );

    final success = await ref
        .read(userDataProvider.notifier)
        .updateUserProfile(updatedUserData);

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil başarıyla güncellendi!',
              style: TextStyle(color: _backgroundColor)),
          backgroundColor: _accentColor,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      final error = ref.read(userDataProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Güncelleme hatası: ${error ?? "Bilinmeyen hata"}',
              style: TextStyle(color: _textColor)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Kişisel Bilgiler',
            style: TextStyle(color: _textColor, fontWeight: FontWeight.bold)),
        backgroundColor: _backgroundColor, // Match background
        elevation: 0, // No shadow
        iconTheme: IconThemeData(color: _accentColor), // Back button color
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: _accentColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0), // Increased padding
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start, // Align titles to the left
          children: <Widget>[
            _buildLabel('İsim Soyisim'),
            _buildTextField(_nameController,
                hintText: 'Mehmet Ali Çakır'), // Use hintText from image
            const SizedBox(height: 20),

            _buildLabel('Kullanıcı Adı'),
            _buildTextField(_usernameController, hintText: 'mehmet'),
            const SizedBox(height: 20),

            _buildLabel('Doğum Tarihi'),
            _buildDateField(),
            const SizedBox(height: 20),

            _buildLabel('Cinsiyet'),
            _buildToggleChipGroup<GenderChoice>(
              selectedValue: _selectedGender,
              options: {
                GenderChoice.female: 'Kadın',
                GenderChoice.male: 'Erkek',
                GenderChoice.other: 'Diğer',
              },
              onSelected: (selected) {
                setState(() => _selectedGender = selected);
              },
              expandToFill: true,
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Boy'),
                      _buildTextField(
                        _heightController,
                        hintText: '175', // Hint from image
                        suffixText: 'cm',
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Kilo'),
                      _buildTextField(
                        _weightController,
                        hintText: '80', // Hint from image
                        suffixText: 'kg',
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _buildLabel('Aktiflik Seviyesi'),
            _buildToggleChipGroup<ActivityLevelChoice>(
              selectedValue: _selectedActivityLevel,
              options: {
                ActivityLevelChoice.low: 'Düşük',
                ActivityLevelChoice.medium: 'Orta',
                ActivityLevelChoice.high: 'Yüksek',
              },
              icons: {
                // Optional icons
                ActivityLevelChoice.low: Icons.directions_walk,
                ActivityLevelChoice.medium: Icons.directions_run,
                ActivityLevelChoice.high: Icons.directions_bike, // Example icon
              },
              onSelected: (selected) {
                setState(() => _selectedActivityLevel = selected);
              },
              expandToFill: false,
            ),
            const SizedBox(height: 20),

            _buildLabel('Mekan Tercihi'),
            _buildToggleChipGroup<LocationPreferenceChoice>(
              selectedValue: _selectedLocationPreference,
              options: {
                LocationPreferenceChoice.indoor: 'Indoor',
                LocationPreferenceChoice.outdoor: 'Outdoor',
              },
              icons: {
                LocationPreferenceChoice.indoor: Icons.fitness_center,
                LocationPreferenceChoice.outdoor: Icons.terrain,
              },
              onSelected: (selected) {
                setState(() => _selectedLocationPreference = selected);
              },
              expandToFill: true,
            ),

            const SizedBox(height: 32), // Space before button
            ElevatedButton(
              onPressed: _isLoading ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor, // Green button
                foregroundColor: _backgroundColor, // Black text
                minimumSize:
                    const Size(double.infinity, 50), // Full width, fixed height
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12), // Slightly rounded corners
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 14), // Adjust padding
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: _backgroundColor), // Thicker stroke
                    )
                  : const Text(
                      'Değişiklikleri Kaydet',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold), // Bold text
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          color: _labelColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Updated TextField Builder
  Widget _buildTextField(
    TextEditingController controller, {
    String hintText = '',
    String? suffixText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      // Changed from TextFormField
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: _textColor, fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: _secondaryTextColor.withOpacity(0.7)),
        suffixText: suffixText,
        suffixStyle: TextStyle(color: _secondaryTextColor, fontSize: 14),
        filled: true,
        fillColor: _cardColor, // Use card color for background
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none, // No border
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
              color: _accentColor, width: 1.5), // Accent border on focus
        ),
        // Removed labelText and prefixIcon
      ),
    );
  }

  // Date Field Builder
  Widget _buildDateField() {
    return InkWell(
      // Make it tappable
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(12.0),
          border:
              Border.all(color: Colors.transparent), // Match TextField style
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedBirthday == null
                  ? 'gg.aa.yyyy' // Placeholder like in image
                  : DateFormat('dd.MM.yyyy')
                      .format(_selectedBirthday!), // Format like image
              style: TextStyle(
                color: _selectedBirthday == null
                    ? _secondaryTextColor.withOpacity(0.7)
                    : _textColor,
                fontSize: 15,
              ),
            ),
            Icon(Icons.calendar_today_outlined, color: _accentColor, size: 20),
          ],
        ),
      ),
    );
  }

  // Generic Toggle Chip Group Builder
  Widget _buildToggleChipGroup<T>({
    required T? selectedValue,
    required Map<T, String> options,
    required ValueChanged<T> onSelected,
    Map<T, IconData>? icons, // Optional icons map
    bool expandToFill = false,
  }) {
    Widget buildLayout(List<Widget> chips) {
      if (expandToFill) {
        return Row(
          children: chips
              .map((chip) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      // SizedBox ile ChoiceChip'i sarmalayarak genişlemeye zorla
                      child: SizedBox(
                        width: double.infinity,
                        child: chip,
                      ),
                    ),
                  ))
              .toList(),
        );
      } else {
        return LayoutBuilder(
          builder: (context, constraints) {
            final double spacing = constraints.maxWidth > 300 ? 12.0 : 8.0;
            return Wrap(
              spacing: spacing,
              runSpacing: 8.0,
              children: chips,
            );
          },
        );
      }
    }

    final List<Widget> chips = options.entries.map((entry) {
      final T value = entry.key;
      final String label = entry.value;
      final IconData? icon = icons?[value];
      final bool isSelected = selectedValue == value;

      return ChoiceChip(
        label: icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center, // İçeriği ortala
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? _backgroundColor : _textColor,
                  ),
                  const SizedBox(width: 6),
                  Text(label),
                ],
              )
            // Sadece metin varsa yine ortala
            : Center(child: Text(label, textAlign: TextAlign.center)),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            onSelected(value);
          }
        },
        backgroundColor: _cardColor,
        selectedColor: _accentColor,
        labelStyle: TextStyle(
          color: isSelected ? _backgroundColor : _textColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: BorderSide(
            color: isSelected ? _accentColor : _cardColor,
            width: 8.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        showCheckmark: false,
      );
    }).toList();

    return buildLayout(chips);
  }
}
