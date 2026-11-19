import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';

class SocialProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final Set<String> _followingUsernames = {};
  final Set<String> _pendingUsernames = {};
  bool _isInitialized = false;

  Set<String> get followingUsernames => _followingUsernames;
  Set<String> get pendingUsernames => _pendingUsernames;
  bool get isInitialized => _isInitialized;

  String _normalize(String username) {
    return username.trim().replaceAll('@', '').toLowerCase();
  }

  Future<void> initFollowingList() async {
    try {
      const storage = FlutterSecureStorage();
      final userJson = await storage.read(key: 'user');
      String? myUsername;
      if (userJson != null) {
        final u = jsonDecode(userJson);
        myUsername = u['username'] ?? u['anonymous_username'];
      }

      if (myUsername == null || myUsername.isEmpty) return;

      final response = await _apiService.get('/users/$myUsername/following');
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        _followingUsernames.clear();
        for (var item in list) {
          final un = item['username']?.toString();
          if (un != null) _followingUsernames.add(_normalize(un));
        }
        _isInitialized = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("SocialProvider init error: $e");
    }
  }

  bool isFollowing(String username) {
    if (username.isEmpty) return false;
    return _followingUsernames.contains(_normalize(username));
  }

  bool isPending(String username) {
    if (username.isEmpty) return false;
    return _pendingUsernames.contains(_normalize(username));
  }

  Future<bool> followUser(String username, {bool isPrivate = false}) async {
    final norm = _normalize(username);
    if (norm.isEmpty) return false;

    if (isPrivate) {
      _pendingUsernames.add(norm);
    } else {
      _followingUsernames.add(norm);
    }
    notifyListeners();

    try {
      final res = await _apiService.post('/social/follow/$norm', {});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'pending') {
          _followingUsernames.remove(norm);
          _pendingUsernames.add(norm);
        } else {
          _pendingUsernames.remove(norm);
          _followingUsernames.add(norm);
        }
        notifyListeners();
        return true;
      } else {
        // Rollback
        _followingUsernames.remove(norm);
        _pendingUsernames.remove(norm);
        notifyListeners();
        return false;
      }
    } catch (_) {
      // Rollback
      _followingUsernames.remove(norm);
      _pendingUsernames.remove(norm);
      notifyListeners();
      return false;
    }
  }

  Future<bool> unfollowUser(String username) async {
    final norm = _normalize(username);
    if (norm.isEmpty) return false;

    _followingUsernames.remove(norm);
    _pendingUsernames.remove(norm);
    notifyListeners();

    try {
      final res = await _apiService.post('/social/unfollow/$norm', {});
      if (res.statusCode == 200) {
        return true;
      } else {
        // Rollback
        _followingUsernames.add(norm);
        notifyListeners();
        return false;
      }
    } catch (_) {
      // Rollback
      _followingUsernames.add(norm);
      notifyListeners();
      return false;
    }
  }
}
