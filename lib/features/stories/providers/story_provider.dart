import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/services/api_service.dart';
import '../models/story_model.dart';

class StoryProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<StoryGroupModel> _communityStoryGroups = [];
  StoryGroupModel? _currentUserStoryGroup;
  bool _isLoading = true;
  String? _errorMessage;

  List<StoryGroupModel> get communityStoryGroups => _communityStoryGroups;
  StoryGroupModel? get currentUserStoryGroup => _currentUserStoryGroup;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchStoryFeed() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get('/stories/feed');
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> rawGroups = [];
        if (decoded is List) {
          rawGroups = decoded;
        } else if (decoded is Map && decoded['stories'] is List) {
          rawGroups = decoded['stories'];
        }

        _communityStoryGroups = rawGroups.map((g) => StoryGroupModel.fromJson(g)).toList();
      } else {
        _errorMessage = "Failed to load stories";
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void markStoryGroupSeen(String authorId) {
    final index = _communityStoryGroups.indexWhere((g) => g.authorId == authorId);
    if (index != -1) {
      final old = _communityStoryGroups[index];
      _communityStoryGroups[index] = StoryGroupModel(
        authorId: old.authorId,
        authorPhoto: old.authorPhoto,
        hasCloseFriendsStory: old.hasCloseFriendsStory,
        hasUnseenStory: false,
        slides: old.slides,
      );
      notifyListeners();
    }
  }
}
