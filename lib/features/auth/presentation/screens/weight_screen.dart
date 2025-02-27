import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'active_screen.dart';
import '../providers/user_profile_provider.dart';

class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  final TextEditingController _weightController = TextEditingController();
  bool _isLbs = true; // true for lbs, false for kg
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Image.asset(
                  'assets/images/weight.jpg',
                  height: 300,
                ),
                const SizedBox(height: 40),
                const Text(
                  "What's your weight?",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _weightController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _isLbs ? 'lbs' : 'kg',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter your weight';
                    }
                    final weight = double.tryParse(value!);
                    if (weight == null || weight <= 0) {
                      return 'Please enter a valid weight';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('lbs'),
                      selectedColor: Color(0xFFC4FF62),
                      selected: _isLbs,
                      onSelected: (bool selected) {
                        setState(() {
                          _isLbs = selected;
                        });
                      },
                    ),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text('kg'),
                      selectedColor: Color(0xFFC4FF62),
                      selected: !_isLbs,
                      onSelected: (bool selected) {
                        setState(() {
                          _isLbs = !selected;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFC4FF62),
                    foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    if (_formKey.currentState?.validate() ?? false) {
                      double weightInKg;

                      if (_isLbs) {
                        // lbs'den kg'ye dönüşüm
                        final lbs = double.parse(_weightController.text);
                        weightInKg = lbs * 0.453592; // 1 lbs = 0.453592 kg
                      } else {
                        // Zaten kg olarak girilmiş
                        weightInKg = double.parse(_weightController.text);
                      }

                      ref.read(userProfileProvider.notifier).updateProfile(
                            weight: weightInKg,
                          );

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ActiveScreen()),
                      );
                    }
                  },
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
