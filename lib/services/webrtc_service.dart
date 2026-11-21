import 'package:flutter/foundation.dart';
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
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ]
  };

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  Future<void> initWebRTC() async {
    try {
      localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
      });

      if (onLocalStream != null && localStream != null) {
        onLocalStream!(localStream!);
      }

      await _createPeerConnectionAndTracks();
      _setupSocketSignaling();
    } catch (_) {
      debugPrint("WebRTC initialization failed.");
    }
  }

  Future<void> _createPeerConnectionAndTracks() async {
    _peerConnection = await createPeerConnection(_iceServers, _config);

    if (localStream != null) {
      for (var track in localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, localStream!);
      }
    }

    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
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

    _peerConnection!.onConnectionState = (state) {
      debugPrint("Peer connection state: $state");
    };
  }

  void _setupSocketSignaling() {
    socketService.onOffer = (data) async {
      try {
        if (_peerConnection == null) return;
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(data['sdp'], data['type']),
        );
        RTCSessionDescription answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);
        socketService.sendAnswer({'sdp': answer.sdp, 'type': answer.type});
      } catch (_) {
        debugPrint("WebRTC offer handling failed.");
      }
    };

    socketService.onAnswer = (data) async {
      try {
        if (_peerConnection == null) return;
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(data['sdp'], data['type']),
        );
      } catch (_) {
        debugPrint("WebRTC answer handling failed.");
      }
    };

    socketService.onIceCandidate = (data) async {
      try {
        if (_peerConnection == null) return;
        await _peerConnection!.addCandidate(
          RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']),
        );
      } catch (_) {
        debugPrint("WebRTC ICE candidate handling failed.");
      }
    };
  }

  Future<void> resetPeerConnection() async {
    try {
      await _peerConnection?.close();
      await _peerConnection?.dispose();
    } catch (_) {
      debugPrint("WebRTC peer connection disposal failed.");
    }
    _peerConnection = null;
    remoteStream = null;

    // Create a fresh peer connection re-using camera stream
    await _createPeerConnectionAndTracks();
  }

  Future<void> createOffer() async {
    try {
      if (_peerConnection == null) return;
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      socketService.sendOffer({'sdp': offer.sdp, 'type': offer.type});
    } catch (_) {
      debugPrint("WebRTC offer creation failed.");
    }
  }

  Future<void> switchCamera() async {
    if (localStream != null && localStream!.getVideoTracks().isNotEmpty) {
      final track = localStream!.getVideoTracks().first;
      await Helper.switchCamera(track);
    }
  }

  void setMicrophoneEnabled(bool enabled) {
    if (localStream != null) {
      for (var track in localStream!.getAudioTracks()) {
        track.enabled = enabled;
      }
    }
  }

  void setCameraEnabled(bool enabled) {
    if (localStream != null) {
      for (var track in localStream!.getVideoTracks()) {
        track.enabled = enabled;
      }
    }
  }

  void dispose() {
    try {
      localStream?.getTracks().forEach((track) => track.stop());
      localStream?.dispose();
      remoteStream?.dispose();
      _peerConnection?.close();
      _peerConnection?.dispose();
    } catch (_) {
      debugPrint("WebRTC disposal failed.");
    }
    localStream = null;
    remoteStream = null;
    _peerConnection = null;
  }
}
