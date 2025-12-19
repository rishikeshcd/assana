import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_page.dart';
import 'screens/main_shell.dart';
import 'services/session_manager.dart';
import 'services/api_service.dart';
import 'services/api_methods.dart';
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
    _initApp();
  }

  Future<void> _initApp() async {
    await _checkFirstRun();
    await _hydrateSession();
  }

  Future<void> _checkFirstRun() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isFirstRun = prefs.getBool('is_first_run') ?? true;

      if (isFirstRun) {
        print('🆕 Fresh install detected: Clearing previous session data');
        await SessionManager.instance.clearSession();
        await prefs.setBool('is_first_run', false);
      }
    } catch (e) {
      print('⚠️ Error checking first run: $e');
    }
  }

  Future<void> _hydrateSession() async {
    print('🔍 RootPage: Checking session...');
    final session = await SessionManager.instance.restoreSession();

    print('📋 Session state:');
    print('   - isLoggedIn: ${session.isLoggedIn}');
    print('   - userName: ${session.userName}');
    print(
      '   - token: ${session.token != null ? "Present (${session.token!.substring(0, 10)}...)" : "Missing"}',
    );

    // If no token or no logged in flag, definitely show login
    if (!session.isLoggedIn ||
        session.token == null ||
        session.token!.isEmpty) {
      print('❌ No valid session found, showing login page');
      if (!mounted) return;
      setState(() {
        _isLoggedIn = false;
        _userName = '';
        _isLoading = false;
      });
      return;
    }

    // Validate token by making an API call
    try {
      print('🔐 Validating token with API...');
      // Try to get bookings - this requires authentication
      // If token is invalid, it will throw a 401 error
      await ApiMethods.getAllBookings();

      // If we get here, token is valid
      print('✅ Token is valid, API call successful');
      if (!mounted) return;
      setState(() {
        _isLoggedIn = true;
        _userName = session.userName ?? '';
        _isLoading = false;
      });
    } on DioException catch (e) {
      // Check if it's an authentication error
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        print(
          '❌ Token validation failed: Authentication error (${e.response?.statusCode})',
        );
      } else {
        print('❌ Token validation failed: ${e.message}');
      }
      // Token is invalid or expired, clear session
      await SessionManager.instance.clearSession();
      if (!mounted) return;
      setState(() {
        _isLoggedIn = false;
        _userName = '';
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Token validation failed: $e');
      // Token is invalid or expired, clear session
      await SessionManager.instance.clearSession();
      if (!mounted) return;
      setState(() {
        _isLoggedIn = false;
        _userName = '';
        _isLoading = false;
      });
    }
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
