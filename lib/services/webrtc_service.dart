import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';

class WebRTCService {
  final SocketService socketService;
  RTCPeerConnection? _peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;

  WebRTCService({required this.socketService});

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  Future<void> initWebRTC() async {
    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {
        'facingMode': 'user',
      },
    });
    
    if (onLocalStream != null) onLocalStream!(localStream!);

    _peerConnection = await createPeerConnection(_iceServers, _config);

    localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, localStream!);
    });

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate != null) {
        socketService.sendIceCandidate({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        if (onRemoteStream != null) onRemoteStream!(remoteStream!);
      }
    };

    // Set up socket listeners
    socketService.onOffer = (data) async {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(data['sdp'], data['type']),
      );
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      socketService.sendAnswer({'sdp': answer.sdp, 'type': answer.type});
    };

    socketService.onAnswer = (data) async {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(data['sdp'], data['type']),
      );
    };

    socketService.onIceCandidate = (data) async {
      await _peerConnection!.addCandidate(
        RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']),
      );
    };
  }

  Future<void> createOffer() async {
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    socketService.sendOffer({'sdp': offer.sdp, 'type': offer.type});
  }

  void dispose() {
    localStream?.dispose();
    remoteStream?.dispose();
    _peerConnection?.dispose();
  }
}
