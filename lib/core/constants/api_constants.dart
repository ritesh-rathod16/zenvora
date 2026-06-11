import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl {
    // 🌐 Flutter Web
    if (kIsWeb) {
      return "http://localhost:8000";
    }

    // 🤖 Android Emulator
    if (Platform.isAndroid) {
      return "http://10.0.2.2:8000";
    }

    // 🍎 iOS Simulator
    if (Platform.isIOS) {
      return "http://localhost:8000";
    }

    // 📱 Real Device (same WiFi)
    // 🔥 CHANGE THIS ONLY ONCE if IP changes
    return "http://192.168.29.118:8000";
  }

  static String get register => "$baseUrl/auth/register";
  static String get login => "$baseUrl/auth/login";
  static String get me => "$baseUrl/users/me";
}
