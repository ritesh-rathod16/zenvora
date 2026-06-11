import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class SocketService with ChangeNotifier {
  late IO.Socket socket;
  bool isConnected = false;
  bool isSearching = false;
  String? partnerId;
  String? role; // 'caller' or 'receiver'

  // Getter for convenience in UI and WebRTC logic
  bool get isCaller => role == 'caller';

  // Callbacks for WebRTC signaling
  Function(Map<String, dynamic>)? onOffer;
  Function(Map<String, dynamic>)? onAnswer;
  Function(Map<String, dynamic>)? onIceCandidate;
  Function()? onMatchFound;
  Function()? onPartnerDisconnected;

  void initSocket() {
    // UPDATED to use the provided IPv4 for real device testing
    socket = IO.io('http://192.168.29.118:8000',
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build()
    );

    socket.connect();

    socket.onConnect((_) {
      print('Connected to Signaling Server');
      isConnected = true;
      notifyListeners();
    });

    socket.onDisconnect((_) {
      print('Disconnected from Signaling Server');
      isConnected = false;
      notifyListeners();
    });

    socket.on('match_found', (data) {
      print('MATCH EVENT RECEIVED: $data');
      partnerId = data['partner_id'];
      role = data['role'];
      isSearching = false;
      notifyListeners();
      if (onMatchFound != null) {
        onMatchFound!();
      }
    });

    socket.on('offer', (data) {
      if (onOffer != null) onOffer!(data);
    });

    socket.on('answer', (data) {
      if (onAnswer != null) onAnswer!(data);
    });

    socket.on('ice_candidate', (data) {
      if (onIceCandidate != null) onIceCandidate!(data);
    });

    socket.on('partner_disconnected', (_) {
      print('Partner disconnected');
      partnerId = null;
      role = null;
      if (onPartnerDisconnected != null) onPartnerDisconnected!();
      notifyListeners();
    });
  }

  void disconnect() {
    try {
      socket.disconnect();
      socket.dispose();
      print("Socket disconnected and disposed");
    } catch (e) {
      print("Socket disconnect error: $e");
    }
  }

  void joinQueue() {
    isSearching = true;
    socket.emit('join_queue');
    notifyListeners();
  }

  void leaveQueue() {
    isSearching = false;
    socket.emit('leave_queue');
    notifyListeners();
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
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
