import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockService extends ChangeNotifier {
  static const _key = 'app_lock_enabled';

  final LocalAuthentication _auth = LocalAuthentication();

  bool _isEnabled = false;
  bool _isUnlocked = false;

  bool get isEnabled => _isEnabled;
  bool get isUnlocked => _isUnlocked;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_key) ?? false;
    _isUnlocked = !_isEnabled;
    notifyListeners();
  }

  Future<bool> isSupported() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final deviceSupported = await _auth.isDeviceSupported();
      return canCheck || deviceSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    if (enabled) {
      final authenticated = await authenticate();
      if (!authenticated) return false;
    }

    _isEnabled = enabled;
    _isUnlocked = !enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
    return true;
  }

  Future<bool> authenticate() async {
    try {
      final success = await _auth.authenticate(
        localizedReason: 'Authenticate to access your expenses',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      if (success) {
        _isUnlocked = true;
        notifyListeners();
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  void lock() {
    if (_isEnabled) {
      _isUnlocked = false;
      notifyListeners();
    }
  }
}
