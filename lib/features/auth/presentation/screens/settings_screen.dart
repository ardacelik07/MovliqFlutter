import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color.fromARGB(255, 0, 0, 0)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Notifications',
              [
                _buildSwitchTile(
                  'Race Alerts',
                  'Get notified about upcoming races',
                  true,
                ),
                _buildSwitchTile(
                  'Event Updates',
                  'Stay updated with event changes',
                  true,
                ),
                _buildSwitchTile(
                  'Training Tips',
                  'Receive personalized training advice',
                  true,
                ),
              ],
            ),
            _buildSection(
              'Account Integration',
              [
                _buildConnectedTile('Google', 'Connected', true),
                _buildConnectedTile('Facebook', 'Connected', true),
                _buildConnectedTile('Microsoft', 'Connect', false),
              ],
            ),
            _buildSection(
              'Privacy & Security',
              [
                _buildNavigationTile('Password & Security'),
                _buildNavigationTile('Location Services'),
                _buildNavigationTile('Data & Backup'),
              ],
            ),
            _buildSection(
              'Preferences',
              [
                _buildPreferenceTile('Language', 'English (US)'),
                _buildPreferenceTile('Units', 'Metric'),
              ],
            ),
            _buildSection(
              'Support & Help',
              [
                _buildNavigationTile('Help Center'),
                _buildNavigationTile('Contact Support'),
                _buildNavigationTile('Rate the App'),
              ],
            ),
            _buildSection(
              'Experimental Features',
              [
                _buildExperimentalFeaturesTile(),
                _buildSwitchTile(
                  'Challenge Mode',
                  '',
                  false,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Version 5.4.1 (241)',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'Terms of Service',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Text(
                        '•',
                        style: TextStyle(color: Colors.grey),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'Privacy Policy',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      // Show confirmation dialog
                      final shouldLogout = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Çıkış Yap'),
                          content: const Text(
                              'Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('İptal'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Çıkış Yap'),
                            ),
                          ],
                        ),
                      );

                      // If confirmed, logout and navigate to login screen
                      if (shouldLogout == true) {
                        await ref.read(authProvider.notifier).logout();
                        // Navigate to login screen and remove all previous routes
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (context) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      }
                    },
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool initialValue) {
    return StatefulBuilder(
      builder: (context, setState) {
        return ListTile(
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          subtitle: subtitle.isNotEmpty
              ? Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                )
              : null,
          trailing: Switch(
            value: initialValue,
            onChanged: (value) {
              setState(() {
                // Handle switch state change
              });
            },
            activeColor: Colors.blue,
          ),
        );
      },
    );
  }

  Widget _buildConnectedTile(String platform, String status, bool isConnected) {
    final String assetPath = 'assets/icons/${platform.toLowerCase()}.svg';
    print('Loading SVG: $assetPath'); // Debug için

    return ListTile(
      leading: SvgPicture.asset(
        assetPath,
        width: 24,
        height: 24,
        colorFilter: const ColorFilter.mode(Colors.black87, BlendMode.srcIn),
        placeholderBuilder: (BuildContext context) => Container(
          width: 24,
          height: 24,
          color: Colors.grey[300],
          child: const Icon(Icons.error, size: 20),
        ),
      ),
      title: Text(
        platform,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
        ),
      ),
      trailing: Text(
        status,
        style: TextStyle(
          fontSize: 13,
          color: isConnected ? Colors.green : Colors.blue,
        ),
      ),
    );
  }

  Widget _buildNavigationTile(String title) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildPreferenceTile(String title, String value) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
        ),
      ),
      trailing: Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildExperimentalFeaturesTile() {
    return ListTile(
      title: const Row(
        children: [
          Text(
            'Experimental Features',
            style: TextStyle(
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Beta',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white,
              backgroundColor: Colors.blue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      subtitle: const Text(
        'Try out new features before they\'re released',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey,
        ),
      ),
    );
  }
}
