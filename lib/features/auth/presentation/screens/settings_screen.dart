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
import 'package:google_fonts/google_fonts.dart';

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
        title: Text(
          'Ayarlar',
          style: GoogleFonts.bangers(
              color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
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
                  title: Text('Çıkış Yap',
                      style: GoogleFonts.bangers(color: textColor)),
                  content: Text(
                    'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
                    style: GoogleFonts.bangers(color: secondaryTextColor),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text('İptal',
                          style: GoogleFonts.bangers(color: iconColor)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text('Çıkış Yap',
                          style: GoogleFonts.bangers(color: Colors.red)),
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
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Bildirimler', textColor),
            _buildSettingsCard(
              cardColor: cardColor,
              children: [
                _buildSwitchTile(
                  icon: Icons.grid_view, // Görseldeki ikon
                  iconColor: iconColor,
                  title: 'Yarış bildirimleri',
                  textColor: textColor,
                  value: _raceNotifications,
                  onChanged: (value) {
                    setState(() => _raceNotifications = value);
                  },
                  activeColor: activeSwitchColor,
                ),
                _buildDivider(secondaryTextColor),
                _buildSwitchTile(
                  icon: Icons.grid_view, // Görseldeki ikon
                  iconColor: iconColor,
                  title: 'Motivasyon Mesajı',
                  textColor: textColor,
                  value: _motivationMessages,
                  onChanged: (value) {
                    setState(() => _motivationMessages = value);
                  },
                  activeColor: activeSwitchColor,
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Hesap Bağlantıları', textColor),
            _buildSettingsCard(
              cardColor: cardColor,
              children: [
                _buildConnectedTile(
                  // SVG yerine Icon kullanıyoruz, gerekirse SVG eklenebilir
                  platformIcon: Icons.facebook,
                  platformName: 'Facebook ile Bağlan',
                  status: 'Bağlı Değil',
                  isConnected: false,
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                  iconColor: iconColor, // Facebook için varsayılan ikon
                  onTap: () {},
                ),
                _buildDivider(secondaryTextColor),
                _buildConnectedTile(
                  platformIcon: Icons.g_mobiledata, // Google ikonu
                  platformName: 'Google ile Bağlan',
                  status: 'Bağlı',
                  isConnected: true,
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                  iconColor: iconColor,
                  onTap: () {},
                ),
                _buildDivider(secondaryTextColor),
                _buildConnectedTile(
                  platformIcon: Icons.apple, // Apple ikonu
                  platformName: 'Apple ile Bağlan',
                  status: 'Bağlı Değil',
                  isConnected: false,
                  textColor: textColor,
                  secondaryTextColor: secondaryTextColor,
                  iconColor: iconColor,
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 24),
            _buildSectionTitle('Gizlilik ve Destek', textColor),
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
      child: Text(
        title,
        style: GoogleFonts.bangers(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor.withOpacity(0.8),
        ),
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
      title: Text(
        title,
        style: GoogleFonts.bangers(
          fontSize: 15,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
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
      title: Text(
        title,
        style: GoogleFonts.bangers(
          fontSize: 15,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
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
      title: Text(
        platformName,
        style: GoogleFonts.bangers(
          fontSize: 15,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Text(
        status,
        style: GoogleFonts.bangers(
          fontSize: 14,
          color: isConnected
              ? const Color(0xFFB2FF59)
              : secondaryTextColor, // Bağlı ise yeşil, değilse gri
          fontWeight: FontWeight.w500,
        ),
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
