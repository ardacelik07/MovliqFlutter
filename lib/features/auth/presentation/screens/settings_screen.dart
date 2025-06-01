import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import 'package:flutter_svg/flutter_svg.dart'; // İkonlar için SVG importu
import 'update_user_info_screen.dart';
import 'change_password_screen.dart';
import 'help_screen.dart';
import 'privacy_policy_screen.dart';

import '../widgets/font_widget.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Bildirim ayarları için state değişkenleri
  bool _raceNotifications = true;
  bool _motivationMessages = false;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = Colors.black; // Arka plan rengi
    final Color cardColor = Colors.grey[900]!; // Kart rengi
    final Color textColor = Colors.white; // Ana metin rengi
    final Color secondaryTextColor = Colors.grey[400]!; // İkincil metin rengi
    final Color iconColor = const Color(0xFFB2FF59); // İkon rengi (açık yeşil)
    final Color activeSwitchColor =
        const Color(0xFFB2FF59); // Aktif switch rengi

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: iconColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: FontWidget(
          text: 'Ayarlar',
          styleType: TextStyleType.titleLarge,
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: iconColor), // Çıkış ikonu
            onPressed: () async {
              // Show confirmation dialog (Mevcut çıkış kodunu buraya taşıyalım)
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: cardColor,
                  title: FontWidget(
                    text: 'Çıkış Yap',
                    styleType: TextStyleType.bodyLarge,
                    color: textColor,
                  ),
                  content: FontWidget(
                    text:
                        'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
                    styleType: TextStyleType.bodyLarge,
                    color: secondaryTextColor,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: FontWidget(
                        text: 'İptal',
                        styleType: TextStyleType.bodyLarge,
                        color: iconColor,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: FontWidget(
                        text: 'Çıkış Yap',
                        styleType: TextStyleType.bodyLarge,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              );

              // If confirmed, logout and navigate to login screen
              if (shouldLogout == true) {
                await ref.read(authProvider.notifier).logout();
                // Navigate to login screen and remove all previous routes
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Hesap', textColor),
            _buildSettingsCard(
              cardColor: cardColor,
              children: [
                _buildDivider(secondaryTextColor),
                _buildNavigationTile(
                  icon: Icons.lock_outline,
                  iconColor: iconColor,
                  title: 'Şifre Değiştir',
                  textColor: textColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(secondaryTextColor),
                _buildNavigationTile(
                  icon: Icons.info_outline,
                  iconColor: iconColor,
                  title: 'Profili Düzenle',
                  textColor: textColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UpdateUserInfoScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(secondaryTextColor),
                _buildNavigationTile(
                  icon: Icons.delete,
                  iconColor: iconColor,
                  title: 'Hesabı Sil',
                  textColor: textColor,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSettingsCard(
              cardColor: cardColor,
              children: [
                _buildNavigationTile(
                  icon: Icons.star, // Gizlilik ikonu
                  iconColor: iconColor,
                  title: 'Movliqi Puanla',
                  textColor: textColor,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Gİzlİlİk ve Destek', textColor),
            _buildSettingsCard(
              cardColor: cardColor,
              children: [
                _buildNavigationTile(
                  icon: Icons.description_outlined, // Gizlilik ikonu
                  iconColor: iconColor,
                  title: 'Gizlilik Politikası',
                  textColor: textColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyScreen(),
                      ),
                    );
                  },
                ),
                _buildDivider(secondaryTextColor),
                _buildNavigationTile(
                  icon: Icons.help_outline, // Yardım ikonu
                  iconColor: iconColor,
                  title: 'Yardım Merkezi',
                  textColor: textColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HelpScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 32), // Alt boşluk
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: FontWidget(
        text: title,
        styleType: TextStyleType.titleSmall,
        fontWeight: FontWeight.w600,
        color: textColor.withOpacity(0.8),
      ),
    );
  }

  Widget _buildSettingsCard(
      {required Color cardColor, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color textColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      leading: Icon(icon, color: iconColor, size: 24),
      title: FontWidget(
        text: title,
        styleType: TextStyleType.bodyLarge,
        color: textColor,
        fontWeight: FontWeight.w500,
      ),
      trailing:
          Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 16),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color textColor,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color activeColor,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      leading: Icon(icon, color: iconColor, size: 24),
      title: FontWidget(
        text: title,
        styleType: TextStyleType.titleMedium,
        color: textColor,
        fontWeight: FontWeight.w500,
      ),
      trailing: CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeColor: activeColor,
        trackColor: Colors.grey[700],
      ),
    );
  }

  Widget _buildConnectedTile({
    required IconData platformIcon, // SVG yerine IconData
    required String platformName,
    required String status,
    required bool isConnected,
    required Color textColor,
    required Color secondaryTextColor,
    required Color iconColor, // İkon rengini de alalım
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      leading: Icon(platformIcon, color: iconColor, size: 24), // Icon widget'ı
      title: FontWidget(
        text: platformName,
        styleType: TextStyleType.bodyMedium,
        color: textColor,
        fontWeight: FontWeight.w500,
      ),

      trailing: FontWidget(
        text: status,
        styleType: TextStyleType.bodyMedium,
        color: isConnected
            ? const Color(0xFFB2FF59)
            : secondaryTextColor, // Bağlı ise yeşil, değilse gri
        fontWeight: FontWeight.w500,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider(Color color) {
    return Divider(
      height: 1,
      thickness: 1,
      color: color.withOpacity(0.2),
      indent: 56, // İkon genişliği + padding kadar içeriden başlat
    );
  }

  // --- Eski Kullanılmayan Widgetlar ---
  // Bu fonksiyonlar artık yeni tasarıma uymadığı için kaldırılabilir
  // veya referans için yorum satırı olarak bırakılabilir.
  /*
   Widget _buildSection(String title, List<Widget> children) {
     // ... eski kod ...
   }

   Widget _buildSwitchTileEski(String title, String subtitle, bool initialValue) {
     // ... eski kod ...
   }

  Widget _buildConnectedTileEski(String platform, String status, bool isConnected) {
     // ... eski kod ...
   }

   Widget _buildNavigationTileEski(String title) {
     // ... eski kod ...
   }

   Widget _buildPreferenceTile(String title, String value) {
    // ... eski kod ...
   }

   Widget _buildExperimentalFeaturesTile() {
    // ... eski kod ...
   }
   */
}
