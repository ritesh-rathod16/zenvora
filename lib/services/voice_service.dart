import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import '../core/services/api_service.dart';

class VoiceService with ChangeNotifier {
  Room? _room;
  bool _isMuted = false;
  bool _isConnected = false;
  bool _isPushToTalkActive = false;
  bool _noiseSuppressionEnabled = true;
  List<Participant> _participants = [];
  
  Room? get room => _room;
  bool get isMuted => _isMuted;
  bool get isConnected => _isConnected;
  bool get isPushToTalkActive => _isPushToTalkActive;
  bool get noiseSuppressionEnabled => _noiseSuppressionEnabled;
  List<Participant> get participants => _participants;

  Future<void> joinRoom(String roomId, String token, String url) async {
    _room = Room();
    
    // Listen to events
    final listener = _room!.createListener();
    
    listener.on<RoomDisconnectedEvent>((event) {
      _isConnected = false;
      _room = null;
      notifyListeners();
    });

    listener.on<ParticipantConnectedEvent>((event) {
      _updateParticipants();
    });

    listener.on<ParticipantDisconnectedEvent>((event) {
      _updateParticipants();
    });

    listener.on<TrackMutedEvent>((event) {
       _updateParticipants();
    });

    listener.on<TrackUnmutedEvent>((event) {
       _updateParticipants();
    });

    try {
      await _room!.connect(url, token);
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      
      // Apply noise suppression if possible (LiveKit handles it via constraints)
      _isConnected = true;
      _updateParticipants();
      notifyListeners();
    } catch (e) {
      debugPrint("Failed to connect to LiveKit: $e");
    }
  }

  void _updateParticipants() {
    if (_room == null) return;
    _participants = _room!.remoteParticipants.values.toList();
    notifyListeners();
  }

  Future<void> toggleMute() async {
    if (_room?.localParticipant == null) return;
    _isMuted = !_isMuted;
    await _room!.localParticipant!.setMicrophoneEnabled(!_isMuted);
    notifyListeners();
  }

  Future<void> setPushToTalk(bool active) async {
    if (_room?.localParticipant == null) return;
    _isPushToTalkActive = active;
    await _room!.localParticipant!.setMicrophoneEnabled(active);
    notifyListeners();
  }

  Future<void> toggleNoiseSuppression() async {
    _noiseSuppressionEnabled = !_noiseSuppressionEnabled;
    // In a real SFU, we would re-publish the track with new constraints
    notifyListeners();
  }

  Future<void> leaveRoom() async {
    await _room?.disconnect();
    _room = null;
    _isConnected = false;
    notifyListeners();
  }
}
