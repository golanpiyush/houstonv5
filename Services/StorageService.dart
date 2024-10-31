import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'dart:async'; // Import this for StreamController

class StorageService extends ChangeNotifier {
  final Dio _dio = Dio();
  bool _isDownloading = true;
  bool _isPlayerScreenVisible =
      false; // Track the visibility of the player screen

  // Getter to access the visibility property
  bool get isPlayerScreenVisible => _isPlayerScreenVisible;
  double _downloadProgress = 0.0;
  CancelToken? _cancelToken; // Add this line
  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  static const String _likedSongsKey = 'liked_songs';

  // Getters for download state
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  Stream<double> get progressStream => _progressController.stream;

  // Generate a unique ID for file names
  String get _uniqueId => DateTime.now().millisecondsSinceEpoch.toString();

  void setPlayerScreenVisible(bool isVisible) {
    _isPlayerScreenVisible = isVisible;
    notifyListeners();
  }

  void _updateProgress(double progress) {
    _downloadProgress = progress;
    _progressController.add(progress); // Emit the new progress

    debugPrint('Progress updated: $_downloadProgress');
    notifyListeners();
  }

  // Download file with progress tracking
  Future<String> downloadFile(
    String url,
    String filePath, {
    required Function(double) onProgress,
  }) async {
    if (await File(filePath).exists()) {
      return filePath;
    }

    try {
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
          }
        },
        cancelToken: _cancelToken, // Enable canceling
      );

      return filePath;
    } catch (e) {
      throw Exception('Failed to download file: $e');
    }
  }

  // Save song details to persistent storage
  Future<void> saveSongDetails({
    required String title,
    required String artist,
    required String albumArtPath,
    required String audioPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String songKey = '${title}_$artist';
    await prefs.setString(songKey, '$title|$artist|$albumArtPath|$audioPath');
  }

  // Add song to liked songs list
  Future<void> addToLikedSongs(String title, String artist) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> likedSongs = prefs.getStringList(_likedSongsKey) ?? [];
    String songIdentifier = '${title}_$artist';

    if (!likedSongs.contains(songIdentifier)) {
      likedSongs.add(songIdentifier);
      await prefs.setStringList(_likedSongsKey, likedSongs);
    }
  }

  // Check if song is already liked
  Future<bool> isSongLiked(String title, String artist) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> likedSongs = prefs.getStringList(_likedSongsKey) ?? [];
    return likedSongs.contains('${title}_$artist');
  }

  // Get all liked songs that have been downloaded
  Future<List<Map<String, String>>> getLikedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> likedSongs = prefs.getStringList(_likedSongsKey) ?? [];
    List<Map<String, String>> songDetails = [];

    for (String songId in likedSongs) {
      String? songData = prefs.getString(songId);
      if (songData != null) {
        List<String> parts = songData.split('|');
        if (parts.length == 4) {
          // Extract details from parts
          String title = parts[0];
          String artist = parts[1];
          String albumArtPath = parts[2];
          String audioPath = parts[3];

          // Check if both audio and album art files exist
          final File albumArtFile = File(albumArtPath);
          final File audioFile = File(audioPath);

          if (await albumArtFile.exists() && await audioFile.exists()) {
            songDetails.add({
              'title': title,
              'artist': artist,
              'albumArtPath': albumArtPath,
              'audioPath': audioPath,
            });
          }
        }
      }
    }

    return songDetails;
  }

  // Method to handle song like and download with progress
  Future<void> likeSong({
    required String title,
    required String artist,
    required String albumArtUrl,
    required String audioUrl,
  }) async {
    try {
      if (await isSongLiked(title, artist)) return;

      _cancelToken = CancelToken();
      _isDownloading = true;
      _downloadProgress = 0.0;
      notifyListeners();
      debugPrint('Download started, isDownloading: $_isDownloading');

      String sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '');
      String sanitizedArtist = artist.replaceAll(RegExp(r'[^\w\s]+'), '');
      String baseFileName = '${_uniqueId}_${sanitizedArtist}_$sanitizedTitle';

      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final Directory songDir = Directory('${appDocDir.path}/houston_songs');
      if (!await songDir.exists()) {
        await songDir.create(recursive: true);
      }

      // Download audio and album art concurrently with progress updates
      final downloadResults = await Future.wait([
        downloadFile(
          audioUrl,
          '${songDir.path}/$baseFileName.mp3',
          onProgress: _updateProgress,
        ),
        downloadFile(
          albumArtUrl,
          '${songDir.path}/$baseFileName.jpg',
          onProgress: _updateProgress,
        ),
      ]);

      await saveSongDetails(
        title: title,
        artist: artist,
        albumArtPath: downloadResults[1],
        audioPath: downloadResults[0],
      );

      await addToLikedSongs(title, artist);
    } catch (e) {
      debugPrint('Error downloading song: $e');
      rethrow;
    } finally {
      completeDownload();
      notifyListeners();
      debugPrint('Download ended, isDownloading: $_isDownloading');
    }
  }

  // Set initial state when starting a download
  void startDownload() {
    _isDownloading = true;
    _downloadProgress = 0.0;
    notifyListeners();
  }

  // Reset download state and notify listeners
  void completeDownload() {
    _isDownloading = false;
    _downloadProgress = 0.0;
    _cancelToken = null;
    notifyListeners();
  }

  // New method to cancel the download
  Future<void> cancelDownload() async {
    if (_cancelToken != null) {
      _cancelToken!.cancel("Download canceled");
      _cancelToken = null; // Reset the token after canceling
      _isDownloading = false;
      _downloadProgress = 0.0;
      notifyListeners();
    }
  }

  // Remove a song from liked songs
  Future<void> unlikeSong(String title, String artist) async {
    await cancelDownload(); // Cancel the download if it's in progress

    final prefs = await SharedPreferences.getInstance();
    String songIdentifier = '${title}_$artist';

    // Remove from liked songs list
    List<String> likedSongs = prefs.getStringList(_likedSongsKey) ?? [];
    likedSongs.remove(songIdentifier);
    await prefs.setStringList(_likedSongsKey, likedSongs);

    // Retrieve stored paths from SharedPreferences
    String? songData = prefs.getString(songIdentifier);
    if (songData != null) {
      List<String> parts = songData.split('|');
      if (parts.length == 4) {
        // Delete album art and audio files
        final albumArtFile = File(parts[2]);
        final audioFile = File(parts[3]);

        try {
          if (await albumArtFile.exists()) {
            await albumArtFile.delete();
            debugPrint('Album art file deleted: ${albumArtFile.path}');
          }
        } catch (error) {
          debugPrint('Error deleting album art file: $error');
        }

        try {
          if (await audioFile.exists()) {
            await audioFile.delete();
            debugPrint('Audio file deleted: ${audioFile.path}');
          }
        } catch (error) {
          debugPrint('Error deleting audio file: $error');
        }
      }
    }

    // Remove song details from SharedPreferences
    await prefs.remove(songIdentifier);
  }

  @override
  void dispose() {
    _progressController.close();
    super.dispose();
  }
}
