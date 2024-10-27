import 'package:flutter/material.dart';

class DownloadProgressNotifier extends ChangeNotifier {
  double _progress = 0.0;
  bool _isDownloading = false;

  double get progress => _progress;
  bool get isDownloading => _isDownloading;

  void startDownload() {
    _isDownloading = true;
    _progress = 0.0;
    notifyListeners();
  }

  void updateProgress(double newProgress) {
    _progress = newProgress;
    notifyListeners();
  }

  void completeDownload() {
    _isDownloading = false;
    _progress = 100.0; // Optional: Set to 100% when complete
    notifyListeners();
  }
}
