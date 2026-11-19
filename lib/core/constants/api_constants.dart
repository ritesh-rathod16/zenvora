import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class ApiConstants {
  // Toggle this to true if testing on a physical real phone over Wi-Fi
  static const bool isPhysicalPhone = true;
  static const String physicalPhoneWifiIp = "192.168.29.21";

  static String get baseUrl {
    // 🌐 Flutter Web
    if (kIsWeb) {
      return "http://localhost:8000";
    }

    // 🤖 Android Emulator vs Real Physical Device
    if (Platform.isAndroid) {
      if (isPhysicalPhone) {
        return "http://$physicalPhoneWifiIp:8000";
      }
      // 10.0.2.2 is the official Android Emulator loopback to host localhost:8000
      return "http://10.0.2.2:8000";
    }

    // 🍎 iOS Simulator
    if (Platform.isIOS) {
      return "http://localhost:8000";
    }

    // 💻 Other targets (Windows / Linux / macOS)
    return "http://localhost:8000";
  }

  static String get register => "$baseUrl/auth/register";
  static String get login => "$baseUrl/auth/login";
  static String get me => "$baseUrl/users/me";
}
