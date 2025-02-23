import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'weight_screen.dart';
import '../providers/user_profile_provider.dart';

class HeightScreen extends ConsumerStatefulWidget {
  const HeightScreen({super.key});

  @override
  ConsumerState<HeightScreen> createState() => _HeightScreenState();
}

class _HeightScreenState extends ConsumerState<HeightScreen> {
  final TextEditingController _ftController = TextEditingController();
  final TextEditingController _inController = TextEditingController();
  bool _isFtIn = true; // true for ft/in, false for cm
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _ftController.dispose();
    _inController.dispose();
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
                  'assets/images/height.jpg',
                  height: 300,
                ),
                const SizedBox(height: 40),
                const Text(
                  "What's your height?",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_isFtIn) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ftController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'ft',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _inController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'in',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.black),
                            ),
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  TextFormField(
                    controller: _ftController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'cm',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black),
                      ),
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) {
                        return 'Required';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('ft/in'),
                      selected: _isFtIn,
                      onSelected: (bool selected) {
                        setState(() {
                          _isFtIn = selected;
                        });
                      },
                    ),
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text('cm'),
                      selected: !_isFtIn,
                      onSelected: (bool selected) {
                        setState(() {
                          _isFtIn = !selected;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    if (_formKey.currentState?.validate() ?? false) {
                      double heightInCm;

                      if (_isFtIn) {
                        // ft/in'den cm'ye dönüşüm
                        final feet = double.parse(_ftController.text);
                        final inches = double.parse(_inController.text);
                        final totalInches = (feet * 12) + inches;
                        heightInCm = totalInches * 2.54; // inch to cm
                      } else {
                        // Zaten cm olarak girilmiş
                        heightInCm = double.parse(_ftController.text);
                      }

                      ref.read(userProfileProvider.notifier).updateProfile(
                            height: heightInCm,
                          );

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const WeightScreen()),
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
