import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Profile Settings',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileItem('Name', 'John Doe'),
          _buildProfileItem('Username', '@johndoe'),
          _buildProfileItem('Birthday', '01/01/1990'),
          _buildProfileItem('Gender', 'Male'),
          _buildProfileItem('Height', '180 cm'),
          _buildProfileItem('Weight', '75 kg'),
          _buildProfileItem('Activity Level', 'Intermediate'),
          _buildProfileItem('Running Preference', 'Outdoor'),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
