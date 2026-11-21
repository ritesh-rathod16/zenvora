import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/api_constants.dart';

class SocketService with ChangeNotifier {
  late socket_io.Socket socket;
  bool isConnected = false;
  bool isSearching = false;
  String? matchmakingError;
  Timer? _queueHeartbeat;
  String? partnerId;
  String? role; // 'caller' or 'receiver'
  String? partnerUsername;
  String? partnerCountry;
  List<String> commonInterests = [];

  bool get isCaller => role == 'caller';

  // Callbacks for WebRTC signaling & Live Chat Activity
  Function(Map<String, dynamic>)? onOffer;
  Function(Map<String, dynamic>)? onAnswer;
  Function(Map<String, dynamic>)? onIceCandidate;
  Function(Map<String, dynamic>)? onMatchFound;
  Function(Map<String, dynamic>)? onPartnerDisconnected;
  Function(Map<String, dynamic>)? onChatMessage;
  Function(bool)? onPartnerTyping;
  Function(Map<String, dynamic>)? onPartnerMediaState;
  Function(Map<String, dynamic>)? onPartnerActivity;
  Function(String)? onReportConfirmed;
  Function()? onSearching;

  void initSocket() {
    Future.microtask(() {
      try {
        socket = socket_io.io(
            ApiConstants.baseUrl,
            socket_io.OptionBuilder()
                .setTransports(['websocket'])
                .enableAutoConnect()
                .enableReconnection()
                .setReconnectionAttempts(5)
                .setReconnectionDelay(2000)
                .build());

        socket.connect();

        socket.onConnect((_) {
          debugPrint('Connected to Signaling Server');
          isConnected = true;
          notifyListeners();
        });

        socket.onDisconnect((_) {
          debugPrint('Disconnected from Signaling Server');
          isConnected = false;
          _queueHeartbeat?.cancel();
          isSearching = false;
          notifyListeners();
        });

        socket.on('match_found', (data) {
          final map = Map<String, dynamic>.from(data);
          partnerId = map['partner_id'];
          role = map['role'];
          partnerUsername = map['partner_username'] ?? 'Stranger';
          partnerCountry = map['partner_country'] ?? 'Global';
          if (map['common_interests'] is List) {
            commonInterests = List<String>.from(map['common_interests']);
          } else {
            commonInterests = [];
          }
          isSearching = false;
          matchmakingError = null;
          _queueHeartbeat?.cancel();
          notifyListeners();
          if (onMatchFound != null) {
            onMatchFound!(map);
          }
        });

        socket.on('searching', (_) {
          isSearching = true;
          matchmakingError = null;
          partnerId = null;
          role = null;
          notifyListeners();
          if (onSearching != null) onSearching!();
        });

        socket.on('matchmaking_error', (data) {
          isSearching = false;
          _queueHeartbeat?.cancel();
          matchmakingError = data is Map
              ? data['message']?.toString()
              : 'Could not start matchmaking.';
          notifyListeners();
        });

        socket.on('offer', (data) {
          if (onOffer != null) onOffer!(Map<String, dynamic>.from(data));
        });

        socket.on('answer', (data) {
          if (onAnswer != null) onAnswer!(Map<String, dynamic>.from(data));
        });

        socket.on('ice_candidate', (data) {
          if (onIceCandidate != null) {
            onIceCandidate!(Map<String, dynamic>.from(data));
          }
        });

        socket.on('chat_message', (data) {
          if (onChatMessage != null) {
            onChatMessage!(Map<String, dynamic>.from(data));
          }
        });

        socket.on('partner_typing', (data) {
          final isTyping = data['is_typing'] == true;
          if (onPartnerTyping != null) onPartnerTyping!(isTyping);
        });

        socket.on('partner_activity', (data) {
          if (onPartnerActivity != null) {
            onPartnerActivity!(Map<String, dynamic>.from(data));
          }
        });

        socket.on('partner_media_state', (data) {
          if (onPartnerMediaState != null) {
            onPartnerMediaState!(Map<String, dynamic>.from(data));
          }
        });

        socket.on('report_confirmed', (data) {
          final msg = data is Map
              ? (data['message'] ?? 'Report received')
              : 'Report received';
          if (onReportConfirmed != null) onReportConfirmed!(msg.toString());
        });

        socket.on('partner_disconnected', (data) {
          debugPrint('Video chat partner disconnected.');
          partnerId = null;
          role = null;
          partnerUsername = null;
          commonInterests = [];
          final map = data is Map
              ? Map<String, dynamic>.from(data)
              : <String, dynamic>{};
          if (onPartnerDisconnected != null) onPartnerDisconnected!(map);
          notifyListeners();
        });
      } catch (e) {
        debugPrint("Socket initialization failed.");
      }
    });
  }

  void disconnect() {
    _queueHeartbeat?.cancel();
    try {
      socket.disconnect();
      socket.dispose();
      debugPrint("Socket disconnected and disposed");
    } catch (_) {
      debugPrint("Socket disconnection failed.");
    }
  }

  Future<void> joinQueue({Map<String, dynamic>? metadata}) async {
    final token = await const FlutterSecureStorage().read(key: 'token');
    if (token == null || token.isEmpty) return;
    _queueHeartbeat?.cancel();
    matchmakingError = null;
    isSearching = true;
    final payload = {...?metadata, 'token': token};
    socket.emit('join_queue', payload);
    if (payload['match_mode'] == 'vibe') {
      _queueHeartbeat = Timer.periodic(const Duration(seconds: 25), (_) {
        if (isConnected && isSearching) socket.emit('queue_heartbeat');
      });
    }
    notifyListeners();
  }

  void leaveQueue() {
    _queueHeartbeat?.cancel();
    isSearching = false;
    partnerId = null;
    role = null;
    socket.emit('leave_queue');
    notifyListeners();
  }

  void skip() {
    isSearching = true;
    partnerId = null;
    role = null;
    socket.emit('skip');
    notifyListeners();
  }

  void sendChatMessage(String text) {
    if (text.trim().isEmpty) return;
    socket.emit('chat_message', {
      'text': text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void sendTyping(bool isTyping) {
    socket.emit('partner_typing', {'is_typing': isTyping});
  }

  void sendChatActivity(
      {required String status, bool inChat = false, bool inCamera = false}) {
    socket.emit('chat_activity', {
      'status': status,
      'in_chat': inChat,
      'in_camera': inCamera,
    });
  }

  void sendMediaState({required bool isMuted, required bool isVideoOff}) {
    socket.emit('media_state', {
      'is_muted': isMuted,
      'is_video_off': isVideoOff,
    });
  }

  void reportPartner({required String reason, String details = ''}) {
    socket.emit('report_partner', {
      'reason': reason,
      'details': details,
    });
  }

  void sendOffer(Map<String, dynamic> offer) {
    socket.emit('offer', offer);
  }

  void sendAnswer(Map<String, dynamic> answer) {
    socket.emit('answer', answer);
  }

  void sendIceCandidate(Map<String, dynamic> candidate) {
    socket.emit('ice_candidate', candidate);
  }

  void sendEndCall() {
    socket.emit('end_call');
    partnerId = null;
    role = null;
    partnerUsername = null;
    commonInterests = [];
    isSearching = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _queueHeartbeat?.cancel();
    disconnect();
    super.dispose();
  }
}
