import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform, SocketException;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';

class ApiService {
  // Use dynamic baseUrl from ApiConstants
  static String get baseUrl => ApiConstants.baseUrl;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Duration _timeout = const Duration(seconds: 15);

  Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _handleRequest(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_timeout);
    } on TimeoutException {
      throw "Server not reachable. Please check your network.";
    } on SocketException {
      throw "Cannot connect to Zenvora server. Ensure your backend is running and you are on the same WiFi.";
    } catch (e) {
      throw "An unexpected error occurred: $e";
    }
  }

  Future<http.Response> get(String endpoint) async {
    final url = Uri.parse("$baseUrl$endpoint");
    final headers = await _getHeaders();
    return _handleRequest(() => http.get(url, headers: headers));
  }

  Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse("$baseUrl$endpoint");
    final headers = await _getHeaders();
    return _handleRequest(() => http.post(url, headers: headers, body: jsonEncode(body)));
  }

  Future<http.Response> patch(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse("$baseUrl$endpoint");
    final headers = await _getHeaders();
    return _handleRequest(() => http.patch(url, headers: headers, body: jsonEncode(body)));
  }

  Future<http.Response> delete(String endpoint) async {
    final url = Uri.parse("$baseUrl$endpoint");
    final headers = await _getHeaders();
    return _handleRequest(() => http.delete(url, headers: headers));
  }

  Future<bool> pingServer() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/")).timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<http.Response> uploadFile(String endpoint, String filePath) async {
    final url = Uri.parse("$baseUrl$endpoint");
    final token = await _storage.read(key: 'token');

    var request = http.MultipartRequest('POST', url);
    request.headers.addAll({
      if (token != null) 'Authorization': 'Bearer $token',
    });

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    try {
      var streamedResponse = await request.send().timeout(_timeout);
      return await http.Response.fromStream(streamedResponse);
    } catch (e) {
      throw "Upload failed: $e";
    }
  }
}
