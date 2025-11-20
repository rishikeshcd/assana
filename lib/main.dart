import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_page.dart';
import 'screens/main_shell.dart';
import 'services/session_manager.dart';
import 'services/api_service.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('🚀 App starting...');

  // Initialize API service with base URL
  ApiService().init(baseUrl: 'https://assana-test.vercel.app');
  print('✅ API Service initialized');

  runApp(const MyApp());
  print('✅ MyApp started');
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASSANA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
        textTheme: GoogleFonts.ralewayTextTheme(),
      ),
      home: const RootPage(),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _hydrateSession();
  }

  Future<void> _hydrateSession() async {
    final session = await SessionManager.instance.restoreSession();
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoggedIn = session.isLoggedIn;
      _userName = session.userName ?? '';
      _isLoading = false;
    });
  }

  Future<void> _handleLogin(String userName, String token) async {
    await SessionManager.instance.saveSession(userName, token);
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoggedIn = true;
      _userName = userName;
    });
  }

  Future<void> _handleLogout() async {
    await SessionManager.instance.clearSession();
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoggedIn = false;
      _userName = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      print('⏳ RootPage: Loading...');
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isLoggedIn) {
      print('✅ RootPage: User logged in, showing MainShell');
      return MainShell(userName: _userName, onLogout: _handleLogout);
    }

    print('🔐 RootPage: User not logged in, showing LoginPage');
    return LoginPage(onLogin: _handleLogin);
  }
}
