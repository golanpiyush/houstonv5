import 'dart:convert';
import 'dart:io';
import 'package:houstonv8/Services/Managers/downloadManager.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart';

import 'file_helper.dart';

class PlaylistManager {
  final DownloadManager _downloadManager = DownloadManager();

  // Create a new playlist directory
  Future<void> createPlaylist(
    String playlistName,
    Map<String, dynamic> songDetails,
  ) async {
    try {
      // Create the playlist directory if it doesn't exist
      final Directory playlistsDir = await FileHelper.getPlaylistsDirectory();
      final Directory newPlaylistDir =
          Directory('${playlistsDir.path}/$playlistName');

      if (!await newPlaylistDir.exists()) {
        await newPlaylistDir.create(recursive: true);
        print('Playlist "$playlistName" created.');
      }

      // Add the song details to the new playlist
      await addSongToPlaylist(
        playlistName: playlistName,
        songDetails: songDetails,
        basePath: '${newPlaylistDir.path}/${songDetails['title']}',
      );

      print('Song added to playlist "$playlistName".');
      await downloadSongData(songDetails);
    } catch (e) {
      print('Error creating playlist or adding song: $e');
    }
  }

  // Get songs of a specific playlist
  Future<List<Map<String, dynamic>>> getPlaylistDetails(
      String playlistName) async {
    final Directory playlistsDir = await FileHelper.getPlaylistsDirectory();
    final Directory playlistDir =
        Directory('${playlistsDir.path}/$playlistName');
    if (!await playlistDir.exists()) return [];

    List<Map<String, dynamic>> songDetails = [];
    final List<FileSystemEntity> files = await playlistDir
        .list()
        .where((entity) => entity.path.endsWith('.json'))
        .toList();

    for (var file in files) {
      if (file is File) {
        final String content = await file.readAsString();
        final Map<String, dynamic> song = jsonDecode(content);
        songDetails.add(song);
      }
    }
    return songDetails;
  }

  String sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[^\w\s\-]'),
        '_'); // Replaces invalid characters with underscores
  }

  Future<void> addSongToPlaylist({
    required String playlistName,
    required Map<String, dynamic> songDetails,
    required String basePath,
  }) async {
    final Directory playlistsDir = await FileHelper.getPlaylistsDirectory();
    final Directory playlistDir =
        Directory('${playlistsDir.path}/$playlistName');
    if (!await playlistDir.exists()) {
      await playlistDir.create(recursive: true);
    }

    final String sanitizedBasePath = sanitizeFileName(basePath);
    final File songFile = File('${playlistDir.path}/$sanitizedBasePath.json');

    await songFile.writeAsString(jsonEncode(songDetails));
  }

  // Get all user-created playlists
  Future<List<String>> getPlaylists() async {
    final Directory playlistsDir = await FileHelper.getPlaylistsDirectory();
    final List<FileSystemEntity> playlistDirs = await playlistsDir
        .list()
        .where((entity) => entity is Directory)
        .toList();

    if (playlistDirs.isEmpty) {
      return ['none']; // Return 'none' if no playlists exist
    }

    // Extract playlist names from directories
    List<String> playlists = playlistDirs
        .map((dir) => dir.path.split(Platform.pathSeparator).last)
        .toList();

    return playlists;
  }

  // Helper method to fetch or create a directory
  Future<Directory> _getDirectory(String folderName) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory directory = Directory('${appDir.path}/$folderName');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  // Method to download song data (audio and album art)

  Future<void> downloadSongData(Map<String, dynamic> songDetails) async {
    try {
      print('downloading songsss');
      final String audioUrl = songDetails['audioUrl'];
      final String albumArtUrl = songDetails['albumArtUrl'];
      final String songTitle = sanitizeFileName(songDetails['title']);

      // Use getApplicationDocumentsDirectory for consistent file access
      final Directory appDocDir = await getApplicationDocumentsDirectory();

      // Create specific subdirectories for audio and album art
      final Directory audioDir = Directory('${appDocDir.path}/audio');
      final Directory albumArtDir = Directory('${appDocDir.path}/album_art');

      // Ensure directories exist
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }
      if (!await albumArtDir.exists()) {
        await albumArtDir.create(recursive: true);
      }

      // File paths for audio and album art
      final String audioFilePath = '${audioDir.path}/$songTitle.mp3';
      final String albumArtFilePath = '${albumArtDir.path}/$songTitle.jpg';

      // Download Audio File
      await _downloadManager.downloadFile(
        audioUrl,
        audioFilePath,
        onProgress: (progress) {
          print(
              "Audio Download Progress: ${(progress * 100).toStringAsFixed(2)}%");
        },
      );

      // Download Album Art
      await _downloadManager.downloadFile(
        albumArtUrl,
        albumArtFilePath,
        onProgress: (progress) {
          print(
              "Album Art Download Progress: ${(progress * 100).toStringAsFixed(2)}%");
        },
      );

      // Update songDetails with local file paths
      songDetails['audioPath'] = audioFilePath;
      songDetails['albumArtPath'] = albumArtFilePath;

      print('Downloads completed for audio and album art.');
      print('Audio file saved at: $audioFilePath');
      print('Album art saved at: $albumArtFilePath');
    } catch (e) {
      print('Error downloading data: $e');
    }
  }

  // Deletes playlists
  Future<void> deletePlaylist(String playlistName) async {
    try {
      final Directory playlistsDir = await FileHelper.getPlaylistsDirectory();
      final Directory playlistDir =
          Directory('${playlistsDir.path}/$playlistName');

      if (await playlistDir.exists()) {
        // Delete all files in the playlist directory
        await playlistDir.delete(recursive: true);
        print('Playlist "$playlistName" and its data have been deleted.');
      } else {
        print('Playlist "$playlistName" not found.');
      }
    } catch (e) {
      print('Error deleting playlist: $e');
    }
  }

  // Deletes songs from playlist
  Future<void> deleteSongFromPlaylist(
      String playlistName, String songTitle) async {
    try {
      final Directory playlistsDir = await FileHelper.getPlaylistsDirectory();
      final Directory playlistDir =
          Directory('${playlistsDir.path}/$playlistName');

      if (!await playlistDir.exists()) {
        print('Playlist "$playlistName" not found.');
        return;
      }

      // Find the song file by the song title (assuming song title is the filename)
      final List<FileSystemEntity> files = await playlistDir
          .list()
          .where((entity) => entity.path.endsWith('.json'))
          .toList();

      bool songFound = false;
      for (var file in files) {
        if (file is File) {
          final String fileName =
              file.uri.pathSegments.last.replaceAll('.json', '');

          // Check if the file name matches the song title
          if (fileName == songTitle) {
            await file.delete(); // Delete the song file
            print('Song "$songTitle" deleted from playlist "$playlistName".');
            songFound = true;
            break;
          }
        }
      }

      if (!songFound) {
        print('Song "$songTitle" not found in playlist "$playlistName".');
      }
    } catch (e) {
      print('Error deleting song from playlist: $e');
    }
  }
}

// Handles playlist creation, retrieval, and deletion, with files persisted in JSON format.
