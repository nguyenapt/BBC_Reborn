import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service quản lý hearts (trái tim) cho AI features
class HeartService extends ChangeNotifier {
  static final HeartService _instance = HeartService._internal();
  factory HeartService() => _instance;
  HeartService._internal();

  static const String _heartsKey = 'ai_hearts_count';
  static const String _lastResetDateKey = 'ai_hearts_last_reset_date';
  static const int _maxHearts = 5;
  static const int _defaultHearts = 5;

  int _hearts = _defaultHearts;
  DateTime? _lastResetDate;

  int get hearts => _hearts;
  int get maxHearts => _maxHearts;
  bool get hasHearts => _hearts > 0;
  bool get canEarnMoreHearts => _hearts < _maxHearts;

  /// Khởi tạo service và load hearts từ SharedPreferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load hearts count
      _hearts = prefs.getInt(_heartsKey) ?? _defaultHearts;
      
      // Load last reset date
      final lastResetDateString = prefs.getString(_lastResetDateKey);
      if (lastResetDateString != null) {
        _lastResetDate = DateTime.parse(lastResetDateString);
      }
      
      // Check if need to reset (new day)
      _checkAndResetIfNeeded();
      
      notifyListeners();
      debugPrint('✅ HeartService initialized: $_hearts hearts');
    } catch (e) {
      debugPrint('❌ Error initializing HeartService: $e');
      _hearts = _defaultHearts;
    }
  }

  /// Check if it's a new day and reset hearts if needed
  void _checkAndResetIfNeeded() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (_lastResetDate == null) {
      // First time, set today as reset date
      _lastResetDate = today;
      _saveLastResetDate();
      return;
    }
    
    final lastReset = DateTime(
      _lastResetDate!.year,
      _lastResetDate!.month,
      _lastResetDate!.day,
    );
    
    // If it's a new day, reset hearts
    if (today.isAfter(lastReset)) {
      debugPrint('🔄 New day detected, resetting hearts to $_maxHearts');
      _hearts = _maxHearts;
      _lastResetDate = today;
      _saveHearts();
      _saveLastResetDate();
      notifyListeners();
    }
  }

  /// Use a heart (called when user uses AI feature)
  /// Returns true if heart was used successfully, false if no hearts available
  Future<bool> useHeart() async {
    _checkAndResetIfNeeded();
    
    if (_hearts <= 0) {
      debugPrint('❌ No hearts available');
      return false;
    }
    
    _hearts--;
    await _saveHearts();
    notifyListeners();
    debugPrint('❤️ Heart used. Remaining: $_hearts');
    return true;
  }

  /// Earn a heart (called after watching rewarded ad)
  /// Returns true if heart was earned successfully, false if already at max
  Future<bool> earnHeart() async {
    if (_hearts >= _maxHearts) {
      debugPrint('❌ Already at max hearts');
      return false;
    }
    
    _hearts++;
    await _saveHearts();
    notifyListeners();
    debugPrint('❤️ Heart earned. Total: $_hearts');
    return true;
  }

  /// Save hearts count to SharedPreferences
  Future<void> _saveHearts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_heartsKey, _hearts);
    } catch (e) {
      debugPrint('❌ Error saving hearts: $e');
    }
  }

  /// Save last reset date to SharedPreferences
  Future<void> _saveLastResetDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_lastResetDate != null) {
        await prefs.setString(_lastResetDateKey, _lastResetDate!.toIso8601String());
      }
    } catch (e) {
      debugPrint('❌ Error saving last reset date: $e');
    }
  }

  /// Get time until next reset (midnight)
  Duration getTimeUntilReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  /// Format time until reset as string (e.g., "2h 30m")
  String getTimeUntilResetString() {
    final duration = getTimeUntilReset();
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }
}


