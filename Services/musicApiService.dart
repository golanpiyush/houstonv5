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

  MusicApiService({required this.baseUrl});

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

  /// Fetches song details for a single song name and returns a SongDetails object.
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
          return SongDetails.fromJson(data);
        }
      }
    } catch (e) {
      print("Error fetching song details: $e");
    } finally {
      client.close();
    }
    return null;
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
        // Parse the response and handle the data
        final List<dynamic> data = json.decode(response.body);

        // Debugging: Log the decoded data to verify it matches expectations
        print("Decoded response data: $data");

        if (data.isNotEmpty) {
          _relatedSongsQueue =
              data.map((song) => SongDetails.fromJson(song)).toList();
          print(
              "Fetched related songs successfully: ${_relatedSongsQueue.length} songs");
          return _relatedSongsQueue;
        } else {
          print("No related songs found for song: $songName by $artistName");
          return [];
        }
      } else {
        print("Failed to fetch related songs: ${response.statusCode}");
        return [];
      }
    } catch (e) {
      print("Error fetching related songs: $e");
      return [];
    }
  }
}
