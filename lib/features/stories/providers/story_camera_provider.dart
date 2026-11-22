import 'package:flutter/material.dart';

enum CameraMode { normal, create, boomerang, layout, effects }

class StoryCameraProvider with ChangeNotifier {
  CameraMode _selectedMode = CameraMode.normal;
  bool _isFrontCamera = true;
  String _flashMode = "off"; // off, on, auto
  bool _isRecording = false;
  int _recordingSeconds = 0;
  double _zoomLevel = 1.0;
  String? _capturedMediaPath;
  bool _isMediaVideo = false;

  CameraMode get selectedMode => _selectedMode;
  bool get isFrontCamera => _isFrontCamera;
  String get flashMode => _flashMode;
  bool get isRecording => _isRecording;
  int get recordingSeconds => _recordingSeconds;
  double get zoomLevel => _zoomLevel;
  String? get capturedMediaPath => _capturedMediaPath;
  bool get isMediaVideo => _isMediaVideo;

  void setMode(CameraMode mode) {
    _selectedMode = mode;
    notifyListeners();
  }

  void toggleCamera() {
    _isFrontCamera = !_isFrontCamera;
    notifyListeners();
  }

  void cycleFlash() {
    if (_flashMode == "off") {
      _flashMode = "on";
    } else if (_flashMode == "on") {
      _flashMode = "auto";
    } else {
      _flashMode = "off";
    }
    notifyListeners();
  }

  void setZoom(double zoom) {
    _zoomLevel = zoom.clamp(1.0, 5.0);
    notifyListeners();
  }

  void startRecording() {
    _isRecording = true;
    _recordingSeconds = 0;
    notifyListeners();
  }

  void updateRecordingTime(int seconds) {
    _recordingSeconds = seconds;
    notifyListeners();
  }

  void stopRecording(String videoPath) {
    _isRecording = false;
    _capturedMediaPath = videoPath;
    _isMediaVideo = true;
    notifyListeners();
  }

  void setCapturedPhoto(String photoPath) {
    _capturedMediaPath = photoPath;
    _isMediaVideo = false;
    notifyListeners();
  }

  void clearCapturedMedia() {
    _capturedMediaPath = null;
    _isMediaVideo = false;
    _isRecording = false;
    _recordingSeconds = 0;
    notifyListeners();
  }
}
