import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import '../../../core/services/api_service.dart';
import '../models/music_track_model.dart';

class MusicProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<MusicTrackModel> _trendingTracks = [];
  List<MusicTrackModel> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;
  MusicTrackModel? _playingTrack;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _debounceTimer;

  List<MusicTrackModel> get trendingTracks => _trendingTracks;
  List<MusicTrackModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  MusicTrackModel? get playingTrack => _playingTrack;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;

  MusicProvider() {
    _audioPlayer.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });
    _audioPlayer.durationStream.listen((d) {
      if (d != null) {
        _duration = d;
        notifyListeners();
      }
    });
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _isPlaying = false;
        _position = Duration.zero;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchTrendingTracks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.get('/stories/music/trending');
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        _trendingTracks = data.map((j) => MusicTrackModel.fromJson(j)).toList();
      } else {
        _errorMessage = "Failed to load trending music";
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void searchTracks(String query) {
    _debounceTimer?.cancel();
    final clean = query.trim();
    if (clean.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      try {
        final res = await _apiService.get('/stories/music/search?q=$clean');
        if (res.statusCode == 200) {
          final List data = jsonDecode(res.body);
          _searchResults = data.map((j) => MusicTrackModel.fromJson(j)).toList();
        } else {
          _errorMessage = "Search failed";
        }
      } catch (e) {
        _errorMessage = e.toString();
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  Future<void> previewTrack(MusicTrackModel track) async {
    try {
      if (_playingTrack?.id == track.id && _isPlaying) {
        await _audioPlayer.pause();
        return;
      }

      _playingTrack = track;
      if (track.previewUrl.isNotEmpty) {
        await _audioPlayer.setUrl(track.previewUrl);
        await _audioPlayer.play();
      }
    } catch (e) {
      _errorMessage = "Playback error: $e";
      notifyListeners();
    }
  }

  Future<void> stopPreview() async {
    try {
      await _audioPlayer.stop();
      _playingTrack = null;
      _isPlaying = false;
      _position = Duration.zero;
      notifyListeners();
    } catch (_) {}
  }
}
