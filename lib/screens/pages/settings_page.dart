import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'edit_profile_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // bool _lightModeEnabled = true; // Commented out - theme functionality not available yet
  // bool _notificationsEnabled = true; // Commented out - notification functionality not available yet

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header section with pink background
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(30, 40, 20, 30),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Manage Your Preferences',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          // Content sections
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Theme section
                  // const Text(
                  //   'Theme',
                  //   style: TextStyle(
                  //     fontSize: 18,
                  //     fontWeight: FontWeight.bold,
                  //     color: Color(0xFF333333),
                  //   ),
                  // ),
                  // const SizedBox(height: 16),
                  // _SettingsItem(
                  //   icon: Icons.brightness_6,
                  //   title: 'Light Mode',
                  //   subtitle: 'Bright and clear',
                  //   trailing: _CustomToggle(
                  //     value: _lightModeEnabled,
                  //     onChanged: (value) {
                  //       setState(() {
                  //         _lightModeEnabled = value;
                  //       });
                  //     },
                  //   ),
                  // ),
                  const SizedBox(height: 32),
                  // Account section
                  const Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsItem(
                    icon: Icons.person,
                    title: 'Edit Profile',
                    subtitle: 'Update your information',
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const EditProfilePage(),
                        ),
                      );
                    },
                  ),
                  // const SizedBox(height: 12),
                  // _SettingsItem(
                  //   icon: Icons.notifications,
                  //   title: 'Notifications',
                  //   subtitle: 'Enabled',
                  //   trailing: _CustomToggle(
                  //     value: _notificationsEnabled,
                  //     onChanged: (value) {
                  //       setState(() {
                  //         _notificationsEnabled = value;
                  //       });
                  //     },
                  //   ),
                  // ),
                  const SizedBox(height: 12),
                  _SettingsItem(
                    icon: Icons.logout,
                    title: 'Logout',
                    subtitle: 'Signed out of your account',
                    onTap: () async {
                      await widget.onLogout();
                    },
                    textColor: AppColors.primary,
                    iconColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.textColor,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? textColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final defaultColor = const Color(0xFF333333);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFCE3E3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Title and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor ?? defaultColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            // Trailing widget (switch or arrow)
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// Commented out - not used since notification functionality is not available yet
// class _CustomToggle extends StatelessWidget {
//   const _CustomToggle({required this.value, required this.onChanged});

//   final bool value;
//   final ValueChanged<bool> onChanged;

//   @override
//   Widget build(BuildContext context) {
//     const double trackHeight = 18.0; // Track height (smaller)
//     const double thumbSize = 26.0; // Thumb size (bigger than track)
//     const double trackWidth = 48.0;
//     const double borderWidth = 1.5;

//     return GestureDetector(
//       onTap: () => onChanged(!value),
//       child: SizedBox(
//         width: trackWidth,
//         height: thumbSize, // Container height matches thumb to allow overflow
//         child: Stack(
//           clipBehavior: Clip.none,
//           alignment: Alignment.center,
//           children: [
//             // Track (line)
//             Positioned(
//               top: (thumbSize - trackHeight) / 2,
//               child: Container(
//                 width: trackWidth,
//                 height: trackHeight,
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(trackHeight / 2),
//                   border: Border.all(
//                     color: AppColors.primary,
//                     width: borderWidth,
//                   ),
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//             // Thumb
//             AnimatedPositioned(
//               duration: const Duration(milliseconds: 200),
//               curve: Curves.easeInOut,
//               left: value ? trackWidth - thumbSize - 2 : 2,
//               child: Container(
//                 width: thumbSize,
//                 height: thumbSize,
//                 decoration: BoxDecoration(
//                   color: value ? AppColors.primary : Colors.white,
//                   shape: BoxShape.circle,
//                   border: value
//                       ? null
//                       : Border.all(
//                           color: AppColors.primary,
//                           width: borderWidth,
//                         ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
