import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:houstonv8/Services/RelatedSongsData.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'SongDetails.dart';

class MusicApiService {
  final String baseUrl;
  final Duration timeoutDuration = const Duration(seconds: 5);
  final List<SongDetails> _songHistory =
      []; // Song history list to display on the history screen
  final Map<String, Timer> _expireTimers =
      {}; // Timer for each song to track expiration
  final StreamController<RelatedSongData> _relatedSongsController =
      StreamController<
          RelatedSongData>.broadcast(); // Controller to stream related songs

  MusicApiService({required this.baseUrl}) {
    _restoreSongHistory(); // Restore song history and timers on initialization
  }

  // Getter for song history
  List<SongDetails> get songHistory => _songHistory;

  // Getter for related songs stream
  Stream<RelatedSongData> get relatedSongsStream =>
      _relatedSongsController.stream;
  final RelatedSongsQueue _relatedSongsQueue = RelatedSongsQueue(); // Add this

  // Add a getter for the queue
  RelatedSongsQueue get relatedSongsQueue => _relatedSongsQueue;

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
    // Reset the related songs queue at the start of fetching a new song
    RelatedSongsQueue().reset();

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
      // print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Check if the server response contains song_details
        if (data.containsKey('song_details') && data['song_details'] != null) {
          // print('Parsing song_details: ${data['song_details']}');

          // Parse the main song details
          final songDetails = SongDetails.fromJson(data['song_details']);

          // Extract session_id from the response if available
          final String sessionId = data['session_id'] ?? '';

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

          // Start listening to related songs asynchronously
          _listenToRelatedSongs(headers, songDetails, sessionId);

          return songDetails; // Return the song details immediately
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

  // The method to listen to related songs via SSE
  Future<void> _listenToRelatedSongs(Map<String, String> headers,
      SongDetails songDetails, String sessionId) async {
    final uri = Uri.parse('$baseUrl/stream_related_songs/$sessionId');
    final request = http.Request('GET', uri)..headers.addAll(headers);

    try {
      final response = await request.send();

      response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((String line) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          debugPrint("Raw SSE data: $data");

          try {
            final json = jsonDecode(data);
            // Check if this is a song data message (has title field)
            if (json.containsKey('title')) {
              debugPrint("Processing song data: $json");
              final relatedSong = RelatedSongData.fromJson(json);

              // Prevent duplicates by checking if the song with the same title and artist already exists in the queue
              if (!_relatedSongsQueue.songs.any((song) =>
                  song.title == relatedSong.title &&
                  song.artists == relatedSong.artists)) {
                // Add to both stream and queue
                _relatedSongsController.add(relatedSong);
                _relatedSongsQueue.addSong(relatedSong);

                debugPrint(
                    "Added song to queue: ${relatedSong.title}. Queue size: ${_relatedSongsQueue.length}");
              } else {
                debugPrint(
                    "Duplicate song detected: ${relatedSong.title} by ${relatedSong.artists}");
              }
            } else if (json['message'] == "Related songs processing complete") {
              debugPrint(
                  "Related songs processing complete. Final queue size: ${_relatedSongsQueue.length}");
            }
          } catch (e, stackTrace) {
            debugPrint("Error parsing SSE data: $e");
            debugPrint("Stack trace: $stackTrace");
          }
        }
      }, onError: (error) {
        debugPrint("SSE Error: $error");
      }, onDone: () {
        debugPrint(
            "SSE stream closed. Final queue size: ${_relatedSongsQueue.length}");
        debugPrint(
            "Queue size after processing complete: ${_relatedSongsQueue.length}");
      });
    } catch (error) {
      debugPrint("Request failed: $error");
    }
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

  // Cancel all timers when the service is disposed
  void cancelAllTimers() {
    for (var timer in _expireTimers.values) {
      timer.cancel();
    }
    _expireTimers.clear();
    print("All expiration timers cancelled.");
  }

  // Extract expiration time from the audio URL
  int? extractExpireTimeFromUrl(String audioUrl) {
    final regex = RegExp(r"expire=(\d+)");
    final match = regex.firstMatch(audioUrl);
    return match != null ? int.tryParse(match.group(1) ?? "") : null;
  }
}
