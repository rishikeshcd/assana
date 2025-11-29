import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../theme/app_colors.dart';
import '../../services/api_methods.dart';
import '../../services/profile_manager.dart';
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

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool showCurrentPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: Text(
                'Change Password',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Password
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: !showCurrentPassword,
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          hintText: 'Enter current password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          suffixIcon: IconButton(
                            icon: Icon(
                              showCurrentPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                showCurrentPassword = !showCurrentPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter current password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // New Password
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: !showNewPassword,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          hintText: 'Enter new password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          suffixIcon: IconButton(
                            icon: Icon(
                              showNewPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                showNewPassword = !showNewPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter new password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Confirm Password
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: !showConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          hintText: 'Confirm new password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          filled: true,
                          fillColor: AppColors.cardBackground,
                          suffixIcon: IconButton(
                            icon: Icon(
                              showConfirmPassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () {
                              setDialogState(() {
                                showConfirmPassword = !showConfirmPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm new password';
                          }
                          if (value != newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() {
                              isLoading = true;
                            });

                            try {
                              // Get user email from profile
                              final profile = await ProfileManager.instance
                                  .getProfile();
                              final userEmail = profile.email;

                              if (userEmail == null || userEmail.isEmpty) {
                                throw Exception(
                                  'User email not found. Please login again.',
                                );
                              }

                              final response = await ApiMethods.changePassword(
                                email: userEmail,
                                oldPassword: currentPasswordController.text,
                                newPassword: newPasswordController.text,
                              );

                              if (response.statusCode == 200 &&
                                  response.data['status'] == true) {
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        response.data['message'] ??
                                            'Password updated successfully',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } else {
                                // Handle API error response
                                final errorMessage =
                                    response.data['message'] ??
                                    response.data['error'] ??
                                    'Failed to change password';
                                throw Exception(errorMessage);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setDialogState(() {
                                  isLoading = false;
                                });

                                String errorMessage =
                                    'Failed to change password';
                                if (e is DioException) {
                                  // Handle Dio errors
                                  if (e.response != null) {
                                    final responseData = e.response!.data;
                                    if (responseData is Map) {
                                      errorMessage =
                                          responseData['message'] ??
                                          responseData['error'] ??
                                          responseData['errors']?.toString() ??
                                          'Request validation failed';
                                    } else {
                                      errorMessage = responseData.toString();
                                    }
                                  } else {
                                    errorMessage =
                                        e.message ?? 'Network error occurred';
                                  }
                                } else {
                                  errorMessage = e.toString().replaceFirst(
                                    'Exception: ',
                                    '',
                                  );
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorMessage),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Change Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogoutConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'Confirm Logout',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await widget.onLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

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
                  SizedBox(height: 30),
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
                    icon: Icons.lock,
                    title: 'Change Password',
                    subtitle: 'Update your password',
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    onTap: () {
                      _showChangePasswordDialog(context);
                    },
                  ),
                  const SizedBox(height: 12),
                  _SettingsItem(
                    icon: Icons.logout,
                    title: 'Logout',
                    subtitle: 'Signed out of your account',
                    onTap: () {
                      _showLogoutConfirmationDialog(context);
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
