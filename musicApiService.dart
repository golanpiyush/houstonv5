import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:eventsource/eventsource.dart';
import 'package:flutter/material.dart';
import 'package:houstonv8/Services/RelatedSongsData.dart';
import 'package:houstonv8/Services/settings.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'SongDetails.dart';

class MusicApiService {
  String? _currentSessionId; // Track active SSE session
  bool _isSSEActive = false; // SSE connection state
  final String baseUrl;
  Timer? _processingResetTimer;
  static const int sseTimeout = 30; // Timeout in seconds
  bool _isProcessingSSE = false;
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

    // Get the current Streamer mode from the Settings singleton
    bool isStreamer = Settings().isStreamer;

    try {
      final response = await client
          .post(
            uri,
            body: jsonEncode({
              'song_name': songName,
              'username': username,
              'streamer_status': isStreamer
                  ? 'yeshoustonstreamer'
                  : 'nohoustonstreamer', // Adjusted key for streamer status
            }),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}');
      print('is Streamer: $isStreamer'); // Fixed print statement

      if (response.statusCode == 200 || response.statusCode == 202) {
        final Map<String, dynamic> data = json.decode(response.body);

        // If streamer mode is off, skip related songs fetching
        if (!isStreamer) {
          return SongDetails.fromJson(data['song_details']);
        }

        // Check if the server response contains song_details
        if (data.containsKey('song_details') && data['song_details'] != null) {
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

          // Start listening to related songs asynchronously if streamer mode is on
          if (isStreamer) {
            _listenToRelatedSongs(headers, songDetails, sessionId);
          }

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

  Future<void> fetchAndStreamRelatedSongs({
    required String title,
    required String artists,
    required RelatedSongsQueue queue,
    int maxRetries = 3,
    bool forceRefresh = false,
    void Function()? onComplete, // Optional callback
  }) async {
    if (_isSSEActive) {
      debugPrint('SSE already active for session $_currentSessionId');
      await Future.delayed(const Duration(seconds: 2));
      if (maxRetries > 0) {
        return fetchAndStreamRelatedSongs(
          title: title,
          artists: artists,
          queue: queue,
          maxRetries: maxRetries - 1,
        );
      }
      return;
    }

    queue.isFetchingRelated = true;
    _isProcessingSSE = true;
    onComplete?.call();

    // Auto-reset processing flag after 45 seconds to prevent deadlock
    _processingResetTimer?.cancel();
    _processingResetTimer = Timer(const Duration(seconds: 45), () {
      _isProcessingSSE = false;
    });

    try {
      if (forceRefresh) {
        queue.clear(); // Assuming you have a clear method
      }

      debugPrint('Fetching related songs for: $title by $artists');
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

      // Start the SSE stream (same as in _listenToRelatedSongs)
      final headers = {'Content-Type': 'application/json'};
      final songDetails = SongDetails(
        title: title, artists: artists,
        albumArt:
            'https://example.com/default_audio_url.mp3', // Default album art URL
        audioUrl:
            'https://example.com/default_audio_url.mp3', // Default audio URL
      ); // Assuming you have a SongDetails class

      // Listen to related songs stream using the same method as _listenToRelatedSongs
      await _listenToRelatedSongs(headers, songDetails, sessionId);
    } catch (e) {
      debugPrint('Error in fetchAndStreamRelatedSongs: $e');
      if (maxRetries > 0) {
        _isProcessingSSE = false;
        await Future.delayed(const Duration(seconds: 2));
        return fetchAndStreamRelatedSongs(
          title: title,
          artists: artists,
          queue: queue,
          maxRetries: maxRetries - 1,
        );
      }
    } finally {
      _processingResetTimer?.cancel();
      _isProcessingSSE = false;
    }
  }

  // ignore: unused_element
  Future<void> _processSSEStream(
      String sessionId, RelatedSongsQueue queue) async {
    final completer = Completer<void>();
    var receivedSongs = false;
    StreamSubscription<Event>? subscription;
    Timer? timeoutTimer;

    try {
      debugPrint('Connecting to SSE stream...');
      final eventSource = await EventSource.connect(
        Uri.parse('$baseUrl/stream_related_songs/$sessionId'),
      );

      // Set timeout timer
      timeoutTimer = Timer(Duration(seconds: sseTimeout), () {
        if (!completer.isCompleted) {
          if (!receivedSongs) {
            completer.completeError(
                TimeoutException('No songs received within timeout period'));
          } else {
            completer.complete();
          }
          subscription?.cancel();
        }
      });

      subscription = eventSource.listen(
        (Event event) async {
          try {
            debugPrint('Received SSE event: ${event.event}');
            if (event.event == 'related_song' && event.data != null) {
              debugPrint('Processing song data: ${event.data}');
              final songData = await _processSongData(event.data!);
              if (songData != null) {
                receivedSongs = true;
                queue.addSong(songData);
                debugPrint('Successfully added to queue: ${songData.title}');
              }
            } else if (event.event == 'complete') {
              debugPrint('SSE stream complete signal received');
              await _handleStreamComplete(completer, subscription);
            } else if (event.event == 'error') {
              _handleStreamError(
                  event.data ?? 'Unknown error', completer, subscription);
            }
          } catch (e, stackTrace) {
            debugPrint('Error processing event: $e');
            debugPrint('Stack trace: $stackTrace');
          }
        },
        onError: (error) {
          debugPrint('SSE connection error: $error');
          _handleStreamError(error.toString(), completer, subscription);
        },
        cancelOnError: true,
      );

      await completer.future;
    } catch (e) {
      debugPrint('Error in SSE stream processing: $e');
    } finally {
      timeoutTimer?.cancel();
      subscription?.cancel();
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<RelatedSongData?> _processSongData(String rawData) async {
    try {
      debugPrint('Raw song data: $rawData');
      final songData = json.decode(rawData) as Map<String, dynamic>;

      // Debug print all fields
      songData.forEach((key, value) {
        debugPrint('Field $key: $value');
      });

      // Process artists with more detailed logging
      String artistString = '';
      final artists = songData['artists'];
      debugPrint('Artists raw data: $artists');
      if (artists is List) {
        artistString = artists.join(', ');
      } else if (artists is String) {
        artistString = artists;
      }
      debugPrint('Processed artist string: $artistString');

      // Extract and validate required fields with logging
      final title = songData['title'] as String?;
      final audioUrl = songData['audio_url'] as String?;
      debugPrint('Extracted title: $title');
      debugPrint('Extracted audioUrl: $audioUrl');

      if (title == null || title.isEmpty) {
        debugPrint('Invalid song data: Missing or empty title');
        return null;
      }

      if (audioUrl == null || audioUrl.isEmpty) {
        debugPrint('Invalid song data: Missing or empty audioUrl');
        return null;
      }

      // Process album art
      String processedAlbumArt = '';
      final albumArt = songData['album_art_url'];
      debugPrint('Raw album art: $albumArt');
      if (albumArt != null && albumArt is String && albumArt.isNotEmpty) {
        processedAlbumArt = albumArt.startsWith('http')
            ? albumArt
            : 'https://yourdefaultcdnurl.com/$albumArt';
      }
      debugPrint('Processed album art: $processedAlbumArt');

      return RelatedSongData(
        title: title,
        artists: artistString,
        albumArt: processedAlbumArt,
        audioUrl: audioUrl,
      );
    } catch (e, stackTrace) {
      debugPrint('Error processing song data: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<void> _handleStreamComplete(
    Completer<void> completer,
    StreamSubscription<Event>? subscription,
  ) async {
    debugPrint('SSE stream complete');
    await subscription?.cancel();
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  void _handleStreamError(
    String? error,
    Completer<void> completer,
    StreamSubscription<Event>? subscription,
  ) {
    final errorMessage = error ?? 'Unknown error occurred';
    debugPrint('SSE error: $errorMessage');
    subscription?.cancel();
    if (!completer.isCompleted) {
      completer.completeError(errorMessage);
    }
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
          // debugPrint("Raw SSE data: $data");

          try {
            final json = jsonDecode(data);
            // Check if this is a song data message (has title field)
            if (json.containsKey('title')) {
              // debugPrint("Processing song data: $json");
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

// ask lyrics from the server if failed in app worker
  Future<Map<String, dynamic>> fetchLyrics(String title,
      {String? artist}) async {
    // Define the base URL of the Flask endpoint
    final uri = Uri.parse('$baseUrl/fetchlyrics');

    // Build query parameters
    final queryParams = {
      'title': title,
      if (artist != null) 'artist': artist,
    };

    // Build the complete URL with query parameters
    final completeUri = uri.replace(queryParameters: queryParams);

    try {
      // Make the GET request
      final response = await http.get(completeUri);

      // Check the status code
      if (response.statusCode == 200 || response.statusCode == 202) {
        // Parse the JSON response
        final data = json.decode(response.body);
        return {
          "lyrics": data["lyrics"] ?? "Lyrics not available.",
          "hasTimestamps": data["has_timestamps"] ?? false,
        };
      } else {
        // Handle errors based on status code
        return {
          "error": "Failed to fetch lyrics. Status code: ${response.statusCode}"
        };
      }
    } catch (e) {
      // Handle any exceptions
      return {"error": "An error occurred: $e"};
    }
  }

  Future<void> uploadProfilePicture(File imageFile, String userId) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://yourserver.com/upload-profile-pic'),
      );

      request.fields['user_id'] = userId;
      request.files
          .add(await http.MultipartFile.fromPath('file', imageFile.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        print("Profile picture uploaded successfully!");
      } else {
        print("Failed to upload profile picture: ${response.reasonPhrase}");
      }
    } catch (e) {
      print("Error uploading profile picture: $e");
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
