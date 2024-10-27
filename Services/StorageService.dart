import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class StorageService {
  final Dio _dio = Dio();
  static const String _likedSongsKey = 'liked_songs';

  // Method to handle song like and download
  Future<void> likeSong({
    required String title,
    required String artist,
    required String albumArtUrl,
    required String audioUrl,
  }) async {
    try {
      // First, check if the song is already liked
      if (await isSongLiked(title, artist)) {
        return; // Song already liked and downloaded
      }

      // Create unique filenames for the downloads
      String sanitizedTitle = title.replaceAll(RegExp(r'[^\w\s]+'), '');
      String sanitizedArtist = artist.replaceAll(RegExp(r'[^\w\s]+'), '');
      String baseFileName = '${sanitizedArtist}_$sanitizedTitle';

      // Download both files concurrently
      final futures = await Future.wait([
        downloadFile(
          audioUrl,
          '$baseFileName.mp3',
          onProgress: (received, total) {
            if (total != -1) {
              final progress = (received / total * 100).toStringAsFixed(1);
              print('Audio Download Progress: $progress%');
            }
          },
        ),
        downloadFile(
          albumArtUrl,
          '$baseFileName.jpg',
          onProgress: (received, total) {
            if (total != -1) {
              final progress = (received / total * 100).toStringAsFixed(1);
              print('Album Art Download Progress: $progress%');
            }
          },
        ),
      ]);

      String audioFilePath = futures[0];
      String albumArtFilePath = futures[1];

      // Save the song details with local file paths
      await saveSongDetails(
        title: title,
        artist: artist,
        albumArtPath: albumArtFilePath,
        audioPath: audioFilePath,
      );

      // Mark the song as liked
      await addToLikedSongs(title, artist);
    } catch (e) {
      throw Exception('Failed to process liked song: $e');
    }
  }

  // Download file with progress tracking
  Future<String> downloadFile(
    String url,
    String fileName, {
    ProgressCallback? onProgress,
  }) async {
    try {
      // Get the application documents directory for permanent storage
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String filePath = '${appDocDir.path}/$fileName';

      // Check if file already exists
      if (await File(filePath).exists()) {
        return filePath;
      }

      // Download the file with progress tracking
      await _dio.download(
        url,
        filePath,
        onReceiveProgress: onProgress,
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

  // Get all liked songs
  Future<List<Map<String, String>>> getLikedSongs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> likedSongs = prefs.getStringList(_likedSongsKey) ?? [];
    List<Map<String, String>> songDetails = [];

    for (String songId in likedSongs) {
      String? songData = prefs.getString(songId);
      if (songData != null) {
        List<String> parts = songData.split('|');
        if (parts.length == 4) {
          songDetails.add({
            'title': parts[0],
            'artist': parts[1],
            'albumArtPath': parts[2],
            'audioPath': parts[3],
          });
        }
      }
    }

    return songDetails;
  }

  // Remove a song from liked songs
  Future<void> unlikeSong(String title, String artist) async {
    final prefs = await SharedPreferences.getInstance();
    String songIdentifier = '${title}_$artist';

    // Remove from liked songs list
    List<String> likedSongs = prefs.getStringList(_likedSongsKey) ?? [];
    likedSongs.remove(songIdentifier);
    await prefs.setStringList(_likedSongsKey, likedSongs);

    // Get stored paths
    String? songData = prefs.getString(songIdentifier);
    if (songData != null) {
      List<String> parts = songData.split('|');
      if (parts.length == 4) {
        // Delete the files with proper error handling
        await File(parts[2])
            .delete()
            .catchError((error) => File(parts[2])); // Album art
        await File(parts[3])
            .delete()
            .catchError((error) => File(parts[3])); // Audio
      }
    }

    // Remove song details
    await prefs.remove(songIdentifier);
  }
}
