import 'dart:async';
import 'package:flutter/material.dart';
import 'package:houstonv8/Services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'managers/downloadManager.dart';
import 'managers/file_helper.dart';
import 'package:awesome_notifications/awesome_notifications.dart'; // Import Awesome Notifications

class StorageService extends ChangeNotifier {
  final DownloadManager _downloadManager = DownloadManager();
  final NotificationService _notificationService = NotificationService();
  StorageService() {
    _initializeNotifications(); // Initialize the notification channels here
  }

  Timer? _updateNotificationAfter1Second;
  int _currentStep = 0;
  static const int maxStep = 10;
  static const int fragmentation = 4;

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  final _progressController = StreamController<double>.broadcast();

  // Track current download session
  String? _currentDownloadId;
  String? _currentDownloadTitle;
  String? _currentDownloadArtist;

  static const String _likedSongsKey = 'liked_songs';
  // ignore: unused_field
  List<Map<String, String>> _likedSongs = [];

  Stream<double> get progressStream => _progressController.stream;
  double get downloadProgress => _downloadProgress;
  bool get isDownloading => _isDownloading;
  // Public getters for the current download title and artist
  String? get currentDownloadTitle => _currentDownloadTitle;
  String? get currentDownloadArtist => _currentDownloadArtist;

  void _updateProgress(double progress) {
    if (_isDownloading) {
      _downloadProgress = progress;
      _progressController.add(progress);
      notifyListeners();

      // Update notification with current progress
      _notificationService.showProgressNotification(
        progress: progress.toInt(),
        title: 'Downloading :-: ${_currentDownloadTitle ?? "File"}',
        body: 'Done: ${progress.toInt()}%',
      );
    }
  }

  Future<void> cancelCurrentDownload() async {
    if (_isDownloading && _currentDownloadId != null) {
      _downloadManager.cancelDownloadById(_currentDownloadId!);
      await _notificationService.cancelNotifications();
      debugPrint('@@@Downloading Cancelled by the user@@@');
      _resetDownloadState();
    }
  }

  Future<void> _initializeNotifications() async {
    AwesomeNotifications().initialize(
      'resource://drawable/res_app_icon',
      [
        NotificationChannel(
          channelKey: 'download_progress_channel', // Correct channel key
          channelName: 'Download Progress',
          channelDescription: 'Shows download progress',
          defaultColor: const Color.fromARGB(255, 139, 17, 240),
          ledColor: const Color.fromARGB(255, 226, 226, 226),
        ),
      ],
    );
  }

  // Method to simulate the task and update the progress
  Future<void> showProgressNotification(int id) async {
    for (var simulatedStep = 1;
        simulatedStep <= maxStep * fragmentation + 1;
        simulatedStep++) {
      _currentStep = simulatedStep;
      await Future.delayed(const Duration(milliseconds: 1000 ~/ fragmentation));
      if (_updateNotificationAfter1Second != null) continue;

      _updateNotificationAfter1Second = Timer(
        const Duration(seconds: 1),
        () {
          _updateCurrentProgressBar(
              id: id,
              simulatedStep: _currentStep,
              maxStep: maxStep * fragmentation);
          _updateNotificationAfter1Second?.cancel();
          _updateNotificationAfter1Second = null;
        },
      );
    }
  }

  // Update the progress bar notification
  void _updateCurrentProgressBar({
    required int id,
    required int simulatedStep,
    required int maxStep,
  }) {
    if (simulatedStep < maxStep) {
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: 'download_progress_channel', // Correct channel key
          title: 'Task in Progress',
          body: 'Processing file...',
          category: NotificationCategory.Progress,
          notificationLayout: NotificationLayout.ProgressBar,
          locked: true, // Prevents the user from dismissing the notification
          progress:
              (simulatedStep / maxStep * 100).toDouble(), // Cast to double
        ),
      );
    } else {
      int progress = (simulatedStep / maxStep * 100).round();
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: 'download_progress_channel', // Correct channel key
          title: 'Download Finished',
          body: 'Processing completed successfully!',
          category: NotificationCategory.Progress,
          notificationLayout: NotificationLayout.ProgressBar,
          locked: false, // Allows the user to dismiss the notification
          progress: progress.toDouble(), // Cast to double
        ),
      );
    }
  }

  set isDownloading(bool value) {
    _isDownloading = value;
    notifyListeners();
  }

  void _resetDownloadState() {
    _isDownloading = false;
    _downloadProgress = 0.0;
    _currentDownloadId = null;
    _currentDownloadTitle = null;
    _currentDownloadArtist = null;
    notifyListeners();
  }

  /// Retrieves the list of liked songs and their details
  Future<List<Map<String, String>>> getLikedSongs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final likedSongs = prefs.getStringList(_likedSongsKey) ?? [];
      final List<Map<String, String>> songDetails = [];

      for (final songId in likedSongs) {
        final songData = prefs.getString(songId);
        if (songData != null) {
          final parts = songData.split('|');
          if (parts.length == 4) {
            final title = parts[0];
            final artist = parts[1];
            final albumArtPath = parts[2];
            final audioPath = parts[3];

            if (await FileHelper.fileExists(albumArtPath) &&
                await FileHelper.fileExists(audioPath)) {
              songDetails.add({
                'title': title,
                'artist': artist,
                'albumArtPath': albumArtPath,
                'audioPath': audioPath,
              });
              notifyListeners();
            }
            notifyListeners();
          }
        }
      }
      notifyListeners();

      return songDetails;
    } catch (e) {
      debugPrint("Error fetching liked songs: $e");
      return [];
    }
  }

  Future<void> unlikeSong(String title, String artist) async {
    try {
      // Cancel the download if it's for the song being unliked
      if (_isDownloading &&
          _currentDownloadTitle == title &&
          _currentDownloadArtist == artist) {
        await cancelCurrentDownload();

        // Reset download state
        _isDownloading = false;
        _currentDownloadTitle = null;
        _currentDownloadArtist = null;
      }

      final prefs = await SharedPreferences.getInstance();
      final songIdentifier = '${title}_$artist';
      final likedSongs = prefs.getStringList(_likedSongsKey) ?? [];

      // Get song data before removing
      final songData = prefs.getString(songIdentifier);

      // Remove from preferences
      likedSongs.remove(songIdentifier);
      await prefs.setStringList(_likedSongsKey, likedSongs);
      await prefs.remove(songIdentifier);

      // Delete files if they exist
      if (songData != null) {
        final parts = songData.split('|');
        if (parts.length == 4) {
          final albumArtPath = parts[2];
          final audioPath = parts[3];

          await Future.wait([
            _deleteFileIfExists(albumArtPath),
            _deleteFileIfExists(audioPath),
          ]);
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint("Error unliking song: $e");
      rethrow;
    }
  }

  Future<void> _deleteFileIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> likeSong({
    required String title,
    required String artist,
    required String albumArtUrl,
    required String audioUrl,
  }) async {
    try {
      _currentDownloadId = _downloadManager.getUniqueId();
      _currentDownloadTitle = title;
      _currentDownloadArtist = artist;
      _isDownloading = true;
      _downloadProgress = 0;
      notifyListeners();

      final baseFileName = _generateFileName(title, artist);
      final paths = await _createDownloadPaths(baseFileName);

      // Audio download (80% of total progress)
      await _downloadManager.downloadFile(
        audioUrl,
        paths.audioPath,
        onProgress: (progress) {
          _updateProgress(progress * 80); // 0-80%
        },
      );

      // Album art download (remaining 20% of progress)
      await _downloadManager.downloadFile(
        albumArtUrl,
        paths.albumArtPath,
        onProgress: (progress) {
          _updateProgress(80 + (progress * 20)); // 80-100%
        },
      );

      // Save song details
      await _saveSongDetails(
        title: title,
        artist: artist,
        albumArtPath: paths.albumArtPath,
        audioPath: paths.audioPath,
      );

      await _addToLikedSongs(title, artist);

      // Show completion notification
      await _notificationService.showDownloadComplete(
        title: '$title By $artist has been',
        body: 'Saved 😉',
      );

      _resetDownloadState();

      await refreshLikedSongs(); // New method to refresh the list
    } catch (e) {
      debugPrint('Error liking song: $e');
      await _notificationService.cancelNotifications();
      _resetDownloadState();
      rethrow;
    }
  }

  /// Checks if the given song is currently downloading
  bool isSongDownloading(String title, String artist) {
    return _isDownloading &&
        _currentDownloadTitle == title &&
        _currentDownloadArtist == artist;
  }

  Future<void> refreshLikedSongs() async {
    _likedSongs = await getLikedSongs(); // Fetch updated liked songs
    notifyListeners(); // Notify listeners to rebuild UI
  }

  String _generateFileName(String title, String artist) {
    final sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '');
    final sanitizedArtist = artist.replaceAll(RegExp(r'[^\w\s]+'), '');
    return '${_downloadManager.getUniqueId()}_${sanitizedArtist}_$sanitizedTitle';
  }

  Future<({String audioPath, String albumArtPath})> _createDownloadPaths(
      String baseFileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final audioPath = '${dir.path}/audio/$baseFileName.mp3';
    final albumArtPath = '${dir.path}/images/$baseFileName.jpg';
    return (audioPath: audioPath, albumArtPath: albumArtPath);
  }

  Future<void> _saveSongDetails({
    required String title,
    required String artist,
    required String albumArtPath,
    required String audioPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final songKey = '${title}_$artist';
    await prefs.setString(songKey, '$title|$artist|$albumArtPath|$audioPath');
  }

  Future<void> _addToLikedSongs(String title, String artist) async {
    final prefs = await SharedPreferences.getInstance();
    final likedSongs = prefs.getStringList(_likedSongsKey) ?? [];
    final songIdentifier = '${title}_$artist';

    if (!likedSongs.contains(songIdentifier)) {
      likedSongs.add(songIdentifier);
      await prefs.setStringList(_likedSongsKey, likedSongs);
    }
    notifyListeners();
  }

  Future<bool> isSongLiked(String title, String artist) async {
    final prefs = await SharedPreferences.getInstance();
    final likedSongs = prefs.getStringList(_likedSongsKey) ?? [];
    return likedSongs.contains('${title}_$artist');
  }

  @override
  void dispose() {
    _progressController.close();
    _downloadManager.dispose();
    super.dispose();
  }
}
