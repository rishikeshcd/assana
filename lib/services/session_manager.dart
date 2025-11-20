import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'profile_manager.dart';

class SessionState {
  const SessionState({required this.isLoggedIn, this.userName, this.token});

  final bool isLoggedIn;
  final String? userName;
  final String? token;
}

class SessionManager {
  SessionManager._();

  static const _keyLoggedIn = 'isLoggedIn';
  static const _keyUserName = 'userName';
  static const _keyToken = 'authToken';

  static final SessionManager instance = SessionManager._();

  Future<SessionState> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_keyLoggedIn) ?? false;
    final userName = prefs.getString(_keyUserName);
    final token = prefs.getString(_keyToken);

    // Restore token to API service
    if (token != null) {
      ApiService().setToken(token);
    }

    return SessionState(
      isLoggedIn: isLoggedIn,
      userName: userName,
      token: token,
    );
  }

  Future<void> saveSession(String userName, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLoggedIn, true);
    await prefs.setString(_keyUserName, userName);
    await prefs.setString(_keyToken, token);

    // Set token in API service
    ApiService().setToken(token);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLoggedIn);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyToken);

    // Clear token from API service
    ApiService().clearToken();

    // Clear profile data
    await ProfileManager.instance.clearProfile();
  }
}
