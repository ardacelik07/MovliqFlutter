import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // For date formatting

import '../../domain/models/user_data_model.dart';
import '../providers/user_data_provider.dart';

class UpdateUserInfoScreen extends ConsumerStatefulWidget {
  const UpdateUserInfoScreen({super.key});

  @override
  ConsumerState<UpdateUserInfoScreen> createState() =>
      _UpdateUserInfoScreenState();
}

class _UpdateUserInfoScreenState extends ConsumerState<UpdateUserInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers for form fields
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _coinsController;
  DateTime? _selectedBirthday;
  String? _selectedGender;
  int? _selectedActive;
  int? _selectedRunPrefer;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with current user data
    final currentUser = ref.read(userDataProvider).value;

    _nameController = TextEditingController(text: currentUser?.name ?? '');
    _usernameController =
        TextEditingController(text: currentUser?.userName ?? '');
    _ageController =
        TextEditingController(text: currentUser?.age?.toString() ?? '0');
    _heightController =
        TextEditingController(text: currentUser?.height?.toString() ?? '0.0');
    _weightController =
        TextEditingController(text: currentUser?.weight?.toString() ?? '0.0');
    _coinsController =
        TextEditingController(text: currentUser?.coins?.toString() ?? '0');
    _selectedBirthday = currentUser?.birthday;
    _selectedGender = currentUser?.gender;
    _selectedActive = currentUser?.active;
    _selectedRunPrefer = currentUser?.runprefer;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _coinsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthday) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final currentUser = ref.read(userDataProvider).value;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı verisi bulunamadı!')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Create updated UserDataModel from form values
      final updatedUserData = currentUser.copyWith(
        name: _nameController.text,
        userName: _usernameController.text,
        age: int.tryParse(_ageController.text) ?? currentUser.age,
        height: double.tryParse(_heightController.text) ?? currentUser.height,
        weight: double.tryParse(_weightController.text) ?? currentUser.weight,
        gender: _selectedGender,
        birthday: _selectedBirthday,
        active: _selectedActive,
        runprefer: _selectedRunPrefer,
        coins: int.tryParse(_coinsController.text) ?? currentUser.coins,
      );

      final success = await ref
          .read(userDataProvider.notifier)
          .updateUserProfile(updatedUserData);

      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil başarıyla güncellendi!')),
        );
        // Navigate back to the previous screen (ProfileScreen)
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        // Show error message from provider state
        final error = ref.read(userDataProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Güncelleme hatası: ${error ?? "Bilinmeyen hata"}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Profili Güncelle',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1F3C18),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildTextField(
                  _nameController, 'İsim', TextInputType.text, Icons.person),
              const SizedBox(height: 16),
              _buildTextField(_usernameController, 'Kullanıcı Adı',
                  TextInputType.text, Icons.account_circle),
              const SizedBox(height: 16),
              _buildTextField(
                  _ageController, 'Yaş', TextInputType.number, Icons.cake),
              const SizedBox(height: 16),
              _buildTextField(_heightController, 'Boy (cm)',
                  TextInputType.numberWithOptions(decimal: true), Icons.height),
              const SizedBox(height: 16),
              _buildTextField(
                  _weightController,
                  'Kilo (kg)',
                  TextInputType.numberWithOptions(decimal: true),
                  Icons.monitor_weight),
              const SizedBox(height: 16),
              _buildTextField(_coinsController, 'Coins', TextInputType.number,
                  Icons.monetization_on), // Added coins field
              const SizedBox(height: 16),
              _buildDropdownField<String>(
                value: _selectedGender,
                items: ['male', 'female', 'other'],
                onChanged: (value) => setState(() => _selectedGender = value),
                hint: 'Cinsiyet Seçin',
                icon: Icons.wc,
              ),
              const SizedBox(height: 16),
              _buildDropdownField<int>(
                value: _selectedActive,
                itemsMap: {
                  0: 'Başlangıç',
                  1: 'Aktif'
                }, // Assuming 0=Beginner, 1=Active
                onChanged: (value) => setState(() => _selectedActive = value),
                hint: 'Aktivite Seviyesi',
                icon: Icons.fitness_center,
              ),
              const SizedBox(height: 16),
              _buildDropdownField<int>(
                value: _selectedRunPrefer,
                itemsMap: {
                  0: 'Gym',
                  1: 'Outdoors'
                }, // Assuming 0=Gym, 1=Outdoors
                onChanged: (value) =>
                    setState(() => _selectedRunPrefer = value),
                hint: 'Koşu Tercihi',
                icon: Icons.directions_run,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.calendar_today, color: Color(0xFFC4FF62)),
                title: Text(
                  _selectedBirthday == null
                      ? 'Doğum Tarihi Seçin'
                      : 'Doğum Tarihi: ${DateFormat('dd/MM/yyyy').format(_selectedBirthday!)}',
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing:
                    const Icon(Icons.arrow_drop_down, color: Colors.white70),
                onTap: () => _selectDate(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  side: const BorderSide(color: Colors.white30),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC4FF62),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Güncelle', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to build text fields
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    TextInputType inputType,
    IconData icon, {
    bool isNumeric = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Color(0xFFC4FF62)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFFC4FF62)),
        ),
        filled: true,
        fillColor: Colors.grey[900]?.withOpacity(0.5),
      ),
      validator: validator ??
          (value) {
            if (value == null || value.isEmpty) {
              return '$label alanı boş bırakılamaz';
            }
            if ((inputType == TextInputType.number ||
                    inputType ==
                        TextInputType.numberWithOptions(decimal: true)) &&
                num.tryParse(value) == null) {
              return 'Lütfen geçerli bir sayı girin';
            }
            return null;
          },
    );
  }

  // Helper to build dropdown fields
  Widget _buildDropdownField<T>({
    required T? value,
    List<T>? items,
    Map<T, String>? itemsMap, // Use Map for value-label mapping
    required ValueChanged<T?> onChanged,
    required String hint,
    required IconData icon,
  }) {
    assert(items != null || itemsMap != null,
        'Either items or itemsMap must be provided');
    assert(items == null || itemsMap == null,
        'Cannot provide both items and itemsMap');

    List<DropdownMenuItem<T>> dropdownItems;
    if (itemsMap != null) {
      dropdownItems = itemsMap.entries.map((entry) {
        return DropdownMenuItem<T>(
          value: entry.key,
          child: Text(entry.value, style: const TextStyle(color: Colors.white)),
        );
      }).toList();
    } else {
      dropdownItems = items!.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(item.toString(),
              style: const TextStyle(color: Colors.white)),
        );
      }).toList();
    }

    return DropdownButtonFormField<T>(
      value: value,
      items: dropdownItems,
      onChanged: onChanged,
      dropdownColor: Colors.grey[850], // Darker dropdown background
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Color(0xFFC4FF62)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFFC4FF62)),
        ),
        filled: true,
        fillColor: Colors.grey[900]?.withOpacity(0.5),
      ),
      validator: (v) => v == null ? '$hint alanı boş bırakılamaz' : null,
    );
  }
}
