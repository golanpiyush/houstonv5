import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'SongDetails.dart';

class MusicApiService {
  final String baseUrl;
  final Duration timeoutDuration = const Duration(seconds: 5);
  List<SongDetails> _relatedSongsQueue = [];
  final List<SongDetails> _songHistory =
      []; // Song history list to display on the history screen
  final Map<String, Timer> _expireTimers =
      {}; // Timer for each song to track expiration

  MusicApiService({required this.baseUrl}) {
    _restoreSongHistory(); // Restore song history and timers on initialization
  }

  // Getter for song history
  List<SongDetails> get songHistory => _songHistory;

  Future<String?> _getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  Future<Map<String, String>> _getHeaders() async {
    final username = await _getUsername();
    return {
      'Content-Type': 'application/json',
      if (username != null) 'Username': username,
    };
  }

  Future<bool> checkHealth() async {
    final client = http.Client();
    final uri = Uri.parse(
        '$baseUrl/checkhealth'); // Replace with the correct URL for health check

    try {
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 5)); // Timeout after 5 seconds
      print("Server response: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['status'] ==
            'healthy'; // Assuming the response contains a 'status' field
      } else {
        print("Unexpected status code: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error checking server health: $e");
      return false;
    } finally {
      client.close(); // Don't forget to close the client after the request
    }
  }

  Future<SongDetails?> fetchSongDetails(String songName) async {
    final client = http.Client();
    final uri = Uri.parse('$baseUrl/get_song');
    final headers = await _getHeaders();
    try {
      final response = await client
          .post(
            uri,
            body: jsonEncode({'song_name': songName}),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final songDetails = SongDetails.fromJson(data);

          // If the song has an expireTime, update it
          int? expireTime = extractExpireTimeFromUrl(songDetails.audioUrl);
          if (expireTime != null) {
            songDetails.expireTime = expireTime;

            // Check if the song is already in the history and update its timer if necessary
            bool isSongInHistory = _songHistory.any((song) =>
                song.title == songDetails.title &&
                song.artists == songDetails.artists);

            if (isSongInHistory) {
              // Find the existing song and update its timer
              final existingSong = _songHistory.firstWhere((song) =>
                  song.title == songDetails.title &&
                  song.artists == songDetails.artists);
              _setExpirationTimer(existingSong, expireTime);
            } else {
              // If the song is not in history, add it and set the timer
              _songHistory.add(songDetails);
              _setExpirationTimer(songDetails, expireTime);
            }

            await _saveSongHistory(); // Save the song details to history
            return songDetails;
          }
        }
      }
    } catch (e) {
      print("Error fetching song details: $e");
    } finally {
      client.close();
    }
    return null;
  }

  // Save the expiration time for a song
  Future<void> _saveExpireTimeForSong(SongDetails songDetails) async {
    final prefs = await SharedPreferences.getInstance();
    if (songDetails.expireTime != null) {
      await prefs.setInt(
          'expire_${songDetails.audioUrl}', songDetails.expireTime!);
    }
  }
  // manual history song remover fucntion

  // void _removeExpiredSong(SongDetails song) {
  //   if (_songHistory.contains(song)) {
  //     _songHistory.remove(song); // Remove the expired song from history
  //     _saveSongHistory(); // Save the updated history
  //     print('Expired song removed from history');
  //   }
  // }

  int? extractExpireTimeFromUrl(String audioUrl) {
    final regex = RegExp(r"expire=(\d+)");
    final match = regex.firstMatch(audioUrl);
    return match != null ? int.tryParse(match.group(1) ?? "") : null;
  }

  // Set an expiration timer for each song, and update the timer if expireTime changes
  void _setExpirationTimer(SongDetails song, int expireTime) {
    // Cancel any existing timer for the song if it's already set
    _expireTimers[song.audioUrl]?.cancel();

    // Update the expireTime in the song if it's different
    if (song.expireTime != expireTime) {
      song.expireTime = expireTime;
    }

    // Calculate the time difference between now and the expiration time
    final expireDateTime =
        DateTime.fromMillisecondsSinceEpoch(expireTime * 1000);
    final duration = expireDateTime.difference(DateTime.now());

    // Create a new expiration timer
    _expireTimers[song.audioUrl] = Timer(duration, () {
      // Remove the song from history after the timer expires
      _songHistory.remove(song);
      _expireTimers.remove(song.audioUrl);
      _saveSongHistory(); // Save the updated history to SharedPreferences
      print("Song expired and removed from history: ${song.title}");
    });

    print(
        "Timer set for song: ${song.title}, expires in: ${duration.inSeconds} seconds");
  }

  // Save song history to SharedPreferences
  Future<void> _saveSongHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final songList = _songHistory.map((song) => song.toJson()).toList();
    await prefs.setString('songHistory', jsonEncode(songList));

    // Save each song's expiration time
    for (var song in _songHistory) {
      int? expireTime = extractExpireTimeFromUrl(song.audioUrl);
      if (expireTime != null) {
        await prefs.setInt('expire_${song.audioUrl}', expireTime);
      }
    }
  }

  // Restore song history and expiration timers
  Future<void> _restoreSongHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? songHistoryData = prefs.getString('songHistory');
    if (songHistoryData != null) {
      List<dynamic> decodedSongs = jsonDecode(songHistoryData);
      _songHistory.clear();
      _songHistory.addAll(
          decodedSongs.map((song) => SongDetails.fromJson(song)).toList());

      // Restore expiration timers for each song
      for (var song in _songHistory) {
        int? expireTime = prefs.getInt('expire_${song.audioUrl}');
        if (expireTime != null) {
          _setExpirationTimer(song, expireTime);
        }
      }
    }
  }

  // Fetch related songs
  Future<List<SongDetails>> fetchRelatedSongs(
      String songName, String artistName) async {
    final uri = Uri.parse('$baseUrl/relatedsongs');
    final headers = await _getHeaders();
    final body = jsonEncode({'song_name': songName, 'artist_name': artistName});

    try {
      final response = await http
          .post(
            uri,
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 50));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isEmpty) return [];
        _relatedSongsQueue =
            data.map((song) => SongDetails.fromJson(song)).toList();
        return _relatedSongsQueue;
      }
    } catch (e) {
      print("Error fetching related songs: $e");
    }
    return [];
  }

  // Cancel all timers when the service is disposed
  void cancelAllTimers() {
    for (var timer in _expireTimers.values) {
      timer.cancel();
    }
    _expireTimers.clear();
    print("All expiration timers cancelled.");
  }
}
