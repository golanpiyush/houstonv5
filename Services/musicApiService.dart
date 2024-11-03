import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'SongDetails.dart';

class MusicApiService {
  final String baseUrl;
  final int maxRetries = 3;
  final Duration timeoutDuration = const Duration(seconds: 5);

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
}
