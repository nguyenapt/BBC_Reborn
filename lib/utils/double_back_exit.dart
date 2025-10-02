import 'package:flutter/material.dart';

mixin DoubleBackExitMixin<T extends StatefulWidget> on State<T> {
  DateTime? _lastBackPressed;

  bool onWillPop() {
    final now = DateTime.now();
    
    if (_lastBackPressed == null || 
        now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      
      // Hiển thị snackbar thông báo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nhấn Back lần nữa để thoát'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      
      return false; // Không thoát app
    }
    
    return true; // Thoát app
  }
}

