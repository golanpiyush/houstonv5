import 'dart:convert';
import 'dart:async'; // For retry logic
import 'package:http/http.dart' as http;
import 'SongDetails.dart';

class MusicApiService {
  final String baseUrl;
  final int maxRetries = 3; // Max retry attempts for network requests
  final Duration timeoutDuration =
      const Duration(seconds: 5); // Request timeout

  // In-memory cache for song details
  // final Map<String, SongDetails> _cache = {};

  MusicApiService({required this.baseUrl});

  /// Fetches song details for a single song name and returns a SongDetails object.
  Future<SongDetails?> fetchSongDetails(String songName) async {
    final client = http.Client();
    final uri = Uri.parse('$baseUrl/get_song');

    try {
      final response = await client.post(
        uri,
        body: jsonEncode(
            {'song_name': songName}), // Use jsonEncode to send JSON data
        headers: {
          'Content-Type': 'application/json', // Set content type to JSON
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          return SongDetails.fromJson(data);
        }
      }
    } catch (e) {
      print("Error fetching song details: $e");
    } finally {
      client.close(); // Ensure the client is closed
    }
    return null;
  }
}
