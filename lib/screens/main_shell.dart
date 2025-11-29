import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_colors.dart';
import 'pages/home_page.dart';
import 'pages/surgeries_page.dart';
import 'pages/meet_page.dart';
import 'pages/settings_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.userName, required this.onLogout});

  final String userName;
  final Future<void> Function() onLogout;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    print('🏗️ MainShell initState called');
    print('   Creating pages with userName: ${widget.userName}');
    _pages = [
      HomePage(userName: widget.userName),
      const SurgeriesPage(),
      const MeetPage(),
      SettingsPage(onLogout: widget.onLogout),
    ];
    print('✅ MainShell pages created');
  }

  Widget _buildNavItem({
    IconData? icon,
    IconData? iconOutlined,
    String? svgPath,
    String? svgPathFilled,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              svgPath != null
                  ? SvgPicture.asset(
                      isSelected && svgPathFilled != null
                          ? svgPathFilled
                          : svgPath,
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(
                        isSelected ? AppColors.primary : Colors.grey.shade600,
                        BlendMode.srcIn,
                      ),
                    )
                  : Icon(
                      isSelected ? icon! : (iconOutlined ?? icon!),
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade600,
                      size: 24,
                    ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.primary : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(13),
            topRight: Radius.circular(13),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home,
                  iconOutlined: Icons.home_outlined,
                  label: 'Home',
                  index: 0,
                ),
                _buildNavItem(
                  svgPath: 'assets/images/surgery.svg',
                  svgPathFilled: 'assets/images/surgery-fill.svg',
                  label: 'Procedures',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.videocam,
                  iconOutlined: Icons.videocam_outlined,
                  label: 'Meet',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.settings,
                  iconOutlined: Icons.settings_outlined,
                  label: 'Settings',
                  index: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
