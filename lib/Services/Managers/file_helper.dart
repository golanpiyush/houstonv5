import 'dart:io';
import 'package:path_provider/path_provider.dart';

class FileHelper {
  static Future<Directory> getPlaylistsDirectory() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory playlistsDir = Directory('${appDir.path}/user_playlists');
    if (!await playlistsDir.exists()) {
      await playlistsDir.create(recursive: true);
    }
    return playlistsDir;
  }

  static Future<bool> fileExists(String path) async {
    final File file = File(path);
    return await file.exists();
  }

  static Future<void> deleteFile(String path) async {
    final File file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}


// Centralizes file operations, including directory creation, file checks, and deletion.