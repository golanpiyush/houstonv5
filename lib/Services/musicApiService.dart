import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'SongDetails.dart';

class RelatedSongs {
  final List<SongDetails> songs;
  final Map<String, dynamic>? currentSong;

  RelatedSongs(this.songs, {this.currentSong});

  // Get a list of song titles
  List<String> getSongTitles() {
    return songs.map((song) => song.title).toList();
  }

  // Get the entire list of song details
  List<SongDetails> getAllSongs() {
    return songs;
  }

  // Get the next song based on the current index
  SongDetails? getNextSong(int currentIndex) {
    if (currentIndex >= 0 && currentIndex < songs.length - 1) {
      return songs[currentIndex + 1]; // Get the next song
    }
    return null;
  }

  // Add a song to the queue
  void addSong(SongDetails song) {
    songs.add(song);
  }

  // Remove a song from the queue
  void removeSong(SongDetails song) {
    songs.remove(song);
  }

  // Clear the song queue
  void clear() {
    songs.clear();
  }

  // Factory method to create RelatedSongs from the API response data
  factory RelatedSongs.fromJson(Map<String, dynamic> jsonData) {
    List<SongDetails> songList = [];
    for (var songData in jsonData['related_songs']) {
      songList.add(SongDetails.fromJson(songData));
    }
    return RelatedSongs(
      songList,
      currentSong:
          jsonData['current_song'], // Store current song data if available
    );
  }
}

class MusicApiService {
  final String baseUrl;
  final Duration timeoutDuration = const Duration(seconds: 5);
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

  Future<SongDetails?> fetchSongDetails(
      String songName, String username) async {
    final client = http.Client();
    final uri = Uri.parse('$baseUrl/get_song');
    final headers = await _getHeaders();
    try {
      final response = await client
          .post(
            uri,
            body: jsonEncode({'song_name': songName, 'username': username}),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Check if the server response contains `song_details`
        if (data.containsKey('song_details') && data['song_details'] != null) {
          print('Parsing song_details: ${data['song_details']}');

          // Parse the main song details
          final songDetails = SongDetails.fromJson(data['song_details']);

          // Handle expireTime logic if necessary
          int? expireTime = extractExpireTimeFromUrl(songDetails.audioUrl);
          if (expireTime != null) {
            songDetails.expireTime = expireTime;

            // Check and update history
            bool isSongInHistory = _songHistory.any((song) =>
                song.title == songDetails.title &&
                song.artists == songDetails.artists);

            if (isSongInHistory) {
              // Update timer for existing song
              final existingSong = _songHistory.firstWhere((song) =>
                  song.title == songDetails.title &&
                  song.artists == songDetails.artists);
              _setExpirationTimer(existingSong, expireTime);
            } else {
              // Add new song to history and set timer
              _songHistory.add(songDetails);
              _setExpirationTimer(songDetails, expireTime);
            }

            await _saveSongHistory(); // Save song details to history
          }

          return songDetails;
        } else {
          print('No song_details found in the response.');
        }
      }
    } catch (e) {
      print("Error fetching song details: $e");
    } finally {
      client.close();
    }
    return null;
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

  Future<List<RelatedSong>> fetchRelatedSongs() async {
    final uri = Uri.parse('$baseUrl/related_tracks');
    final headers = await _getHeaders();

    // List to hold related songs
    List<RelatedSong> allSongs = [];

    try {
      final response = await http
          .get(
            uri,
            headers: headers,
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        // Debug raw JSON response
        print("Raw server response:");
        print(response.body);

        // Decode JSON
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

        if (jsonResponse.containsKey('related_songs')) {
          final List<dynamic> songsJson = jsonResponse['related_songs'];

          // Add new songs to the existing list incrementally
          for (var song in songsJson) {
            RelatedSong newSong = RelatedSong.fromJson(song);
            allSongs.add(newSong);

            // Debug print each new song as it's added
            print("Added song: $newSong");
          }

          print("Total related songs: ${allSongs.length}");
          return allSongs;
        } else {
          print("Error: 'related_songs' key not found in response.");
        }
      } else {
        print(
            "Failed to fetch related songs. Status code: ${response.statusCode}");
        print("Response body: ${response.body}");
      }
    } catch (e, stackTrace) {
      print("Error fetching related songs: $e");
      print("Stack trace: $stackTrace");
    }

    return allSongs;
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
