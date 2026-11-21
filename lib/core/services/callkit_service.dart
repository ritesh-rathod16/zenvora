import 'package:flutter/foundation.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:uuid/uuid.dart';

class CallKitService {
  static final CallKitService _instance = CallKitService._internal();
  factory CallKitService() => _instance;
  CallKitService._internal();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    FlutterCallkitIncoming.onEvent.listen((event) {
      if (event == null) return;
      final evtString = event.event.toString();
      if (evtString.contains('actionCallAccept') || evtString.contains('ACTION_CALL_ACCEPT')) {
        debugPrint("CallKit call accepted.");
      } else if (evtString.contains('actionCallDecline') || evtString.contains('ACTION_CALL_DECLINE')) {
        debugPrint("CallKit call declined.");
        FlutterCallkitIncoming.endAllCalls();
      }
    });
  }

  Future<void> showIncomingCall({
    required String callerName,
    required String callerHandle,
    String? avatarUrl,
    bool isVideo = true,
  }) async {
    final params = CallKitParams(
      id: const Uuid().v4(),
      nameCaller: callerName,
      appName: 'Zenvora',
      avatar: avatarUrl ?? 'https://api.dicebear.com/7.x/avataaars/png?seed=$callerName',
      handle: callerHandle,
      type: isVideo ? 1 : 0,
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      extra: <String, dynamic>{'userId': callerHandle},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'ringtone_default',
        backgroundColor: '#0F0F1A',
        backgroundUrl: '',
        actionColor: '#6C63FF',
        incomingCallNotificationChannelName: 'Zenvora Calls',
      ),
      ios: const IOSParams(
        iconName: 'AppIcon',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: true,
        supportsUngrouping: true,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  Future<void> endAllCalls() async {
    await FlutterCallkitIncoming.endAllCalls();
  }
}
