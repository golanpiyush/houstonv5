import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'SongDetails.dart';

class MusicApiService {
  final String baseUrl;
  final int maxRetries = 3;
  final Duration timeoutDuration = const Duration(seconds: 5);
  List<SongDetails> _relatedSongsQueue = []; // Queue for related songs
  int? _expireTime; // Store the expire time
  Timer? _expireCheckTimer; // Timer to periodically check expiration

  final List<SongDetails> _songHistory = []; // Define _songHistory here

  MusicApiService({required this.baseUrl}) {
    // Start the timer when the service is initialized
    _startExpireCheck();
    _restoreExpireTime(); // Restore expire time on service initialization
  }

  // Getter for song history
  List<SongDetails> get songHistory => _songHistory;

  // Retrieve the username from SharedPreferences
  Future<String?> _getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  // Include the username in headers if available
  Future<Map<String, String>> _getHeaders() async {
    final username = await _getUsername();
    return {
      'Content-Type': 'application/json',
      if (username != null) 'Username': username, // Add username to headers
    };
  }

  Future<bool> checkHealth() async {
    final client = http.Client();
    final uri = Uri.parse('$baseUrl/checkhealth');

    try {
      final response = await client.get(uri).timeout(timeoutDuration);
      print("Server response: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['status'] == 'healthy';
      } else {
        print("Unexpected status code: ${response.statusCode}");
      }
    } catch (e) {
      print("Error checking server health: $e");
    } finally {
      client.close();
    }
    return false;
  }

  // Save expiration time persistently
  Future<void> _saveExpireTime(int expireTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('expireTime', expireTime);
  }

  // Retrieve expiration time from SharedPreferences
  Future<int?> _getExpireTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('expireTime');
  }

  Future<void> _restoreExpireTime() async {
    final storedExpireTime = await _getExpireTime();
    if (storedExpireTime != null) {
      _expireTime = storedExpireTime; // Set the stored expire time
      print('Expire time restored: $_expireTime');
    }
  }

  Future<SongDetails?> fetchSongDetails(String songName) async {
    final client = http.Client();
    final uri = Uri.parse('$baseUrl/get_song');
    final headers = await _getHeaders(); // Fetch headers with username

    try {
      final response = await client
          .post(
            uri,
            body: jsonEncode({'song_name': songName}),
            headers: headers, // Use headers with username
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final songDetails = SongDetails.fromJson(data);

          // Store the song in the history list
          _songHistory.add(songDetails);

          // Assuming the SongDetails object contains a property 'audioUrl'
          String expireAudioToken = songDetails.audioUrl;

          // Extract expire time from the audio URL
          int? expireTime = extractExpireTimeFromUrl(expireAudioToken);

          // Store the expire time if it's found
          if (expireTime != null) {
            _expireTime = expireTime;
            await _saveExpireTime(
                _expireTime!); // Save expire time to SharedPreferences
          }

          // Print time left
          print('Time left: ${timeLeft}'); // Use the timeLeft getter to print

          return songDetails;
        }
      }
    } catch (e) {
      print("Error fetching song details: $e");
    } finally {
      client.close();
    }
    return null;
  }

  // EXPIRE TIME CALCULATOR (single method)
  int? extractExpireTimeFromUrl(String audioUrl) {
    if (audioUrl.isEmpty) return null; // Guard clause to check empty audioUrl

    final regex = RegExp(r"expire=(\d+)");
    final match = regex.firstMatch(audioUrl);

    return match != null && match.groupCount > 0
        ? int.tryParse(match.group(1) ?? "")
        : null;
  }

  // Getter for timeLeft that converts expireTime to a human-readable format
  String get timeLeft {
    if (_expireTime == null) {
      return 'Expire time not set';
    }

    DateTime expireDate =
        DateTime.fromMillisecondsSinceEpoch(_expireTime! * 1000);
    DateTime currentDate = DateTime.now();
    Duration difference = expireDate.difference(currentDate);

    if (difference.isNegative) {
      // If expired, remove the song from history
      _removeExpiredSong();
      return 'Expired';
    } else {
      int days = difference.inDays;
      int hours = difference.inHours % 24;
      int minutes = difference.inMinutes % 60;

      String timeLeft = '';
      if (days > 0) timeLeft += '$days Days ';
      if (hours > 0) timeLeft += '$hours Hrs ';
      if (minutes > 0) timeLeft += '$minutes Min';
      return timeLeft.trim();
    }
  }

  // Method to remove expired song from history
  void _removeExpiredSong() {
    if (_songHistory.isNotEmpty) {
      // Assuming the first song in the history list is the one being checked
      _songHistory.removeAt(0); // Remove the expired song
      print('Song removed from history due to expiration');
    }
  }

  // Start a timer to periodically check song expiration
  void _startExpireCheck() {
    _expireCheckTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      print('Checking for expired songs...');

      // Check each song in the history for expiration
      List<SongDetails> expiredSongs = [];
      for (var song in _songHistory) {
        final expireTime = extractExpireTimeFromUrl(song.audioUrl);
        if (expireTime != null &&
            DateTime.now().isAfter(
                DateTime.fromMillisecondsSinceEpoch(expireTime * 1000))) {
          // If the song has expired, mark it for removal
          expiredSongs.add(song);
        }
      }

      // Remove expired songs
      if (expiredSongs.isNotEmpty) {
        _songHistory.removeWhere((song) => expiredSongs.contains(song));
        print('Removed expired songs from history.');
      }
    });
  }

  // Method to cancel the timer (if needed)
  void cancelExpireCheck() {
    _expireCheckTimer?.cancel();
    print('Expire check timer cancelled.');
  }

  Future<List<SongDetails>> fetchRelatedSongs(
      String songName, String artistName) async {
    final uri = Uri.parse('$baseUrl/relatedsongs');
    final headers = await _getHeaders();
    final body = jsonEncode({'song_name': songName, 'artist_name': artistName});

    try {
      // Debugging: Log the song name and artist name being passed to the API
      print("Fetching related songs for: $songName by $artistName");
      print("API Request body: $body");

      final response = await http
          .post(
            uri,
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 50));

      // Debugging: Log the raw response body from the API
      print("Raw response body: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isEmpty) {
          print("No related songs found.");
          return []; // Return empty list if no related songs are found
        }
        _relatedSongsQueue =
            data.map((song) => SongDetails.fromJson(song)).toList();
        return _relatedSongsQueue;
      } else {
        print("Failed to fetch related songs: ${response.statusCode}");
        return []; // Return empty list if the request fails
      }
    } catch (e) {
      print("Error fetching related songs: $e");
      return [];
    }
  }
}
