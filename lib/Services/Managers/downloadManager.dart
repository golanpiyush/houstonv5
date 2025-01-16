import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Handles file download operations
class DownloadManager {
  final Dio _dio = Dio();
  final Map<String, StreamSubscription> _activeDownloads = {};

  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  final Map<String, CancelToken> _cancelTokens =
      {}; // Store cancel tokens for active downloads
  final Map<String, bool> _isDownloadingMap = {}; // Track download states

  Stream<double> get progressStream => _progressController.stream;

  DownloadManager() {
    // Optional: Add logging for debugging purposes
    _dio.interceptors
        .add(LogInterceptor(responseBody: true, requestBody: true));
  }

  /// Generates a unique ID for each download
  String getUniqueId() => DateTime.now().millisecondsSinceEpoch.toString();

  void cancelDownloadById(String downloadId) {
    if (_activeDownloads.containsKey(downloadId)) {
      _activeDownloads[downloadId]?.cancel();
      _activeDownloads.remove(downloadId);
      debugPrint(
          'DownloadManager - Canceled and removed download for ID: $downloadId');
    } else {
      debugPrint(
          'DownloadManager - No active download found for ID: $downloadId');
    }
  }

  /// Downloads a file from [url] to [filePath].
  /// Updates progress using [onProgress] callback.
  Future<String> downloadFile(
    String url,
    String filePath, {
    required void Function(double) onProgress,
  }) async {
    final downloadId = getUniqueId();
    _cancelTokens[downloadId] = CancelToken();
    _isDownloadingMap[downloadId] = true;

    try {
      // Ensure the directory exists
      final directory = Directory(filePath).parent;
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }

      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            onProgress(progress);
            _progressController.add(progress);
          }
        },
        cancelToken: _cancelTokens[downloadId],
      );

      return filePath;
    } catch (e) {
      debugPrint('Download failed: $e');
      rethrow;
    } finally {
      _isDownloadingMap[downloadId] = false;
      _cancelTokens.remove(downloadId);
      _progressController.add(0.0); // Reset progress
    }
  }

  /// Clean up resources
  void dispose() {
    _progressController.close();
    _cancelTokens.clear();
  }
}
