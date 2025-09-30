import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  static const String _userIdKey = 'user_id';
  String? _userId;

  String get userId {
    _userId ??= _generateUserId();
    return _userId!;
  }

  String _generateUserId() {
    // Generate a simple user ID for demo purposes
    // In a real app, this would be handled by authentication
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNumber = random.nextInt(9999);
    return 'user_${timestamp}_$randomNumber';
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString(_userIdKey);
    
    if (_userId == null) {
      _userId = _generateUserId();
      await prefs.setString(_userIdKey, _userId!);
    }
  }

  Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    _userId = null;
  }
}



