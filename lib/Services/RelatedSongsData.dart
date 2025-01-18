import 'package:flutter/material.dart';

/// Represents a single related song.
class RelatedSongData {
  final String title;
  final String artists;
  final String albumArt;
  final String audioUrl;

  RelatedSongData({
    required this.title,
    required this.artists,
    required this.albumArt,
    required this.audioUrl,
  });

  /// Factory method to create a RelatedSongData object from a JSON object.
  factory RelatedSongData.fromJson(Map<String, dynamic> json) {
    try {
      final artists = json['artists'] is List
          ? (json['artists'] as List<dynamic>).join(', ')
          : json['artists'] ?? 'Unknown Artist';

      // Update these keys to match the incoming data structure
      return RelatedSongData(
        title: json['title'] ?? 'Unknown Title',
        artists: artists,
        albumArt: json['album_art_url'] ?? '', // Changed from albumArt
        audioUrl: json['audio_url'] ?? '', // Changed from audioUrl
      );
    } catch (e) {
      debugPrint('Error parsing JSON to RelatedSongData: $e');
      debugPrint('Received JSON: $json'); // Add this for debugging
      throw FormatException('Invalid JSON format for RelatedSongData');
    }
  }

  /// Converts a RelatedSongData object to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artists': artists,
      'albumArt': albumArt,
      'audioUrl': audioUrl,
    };
  }

  @override
  String toString() {
    return 'RelatedSongData(title: $title, artists: $artists, albumArt: $albumArt, audioUrl: $audioUrl)';
  }
}

class RelatedSongsQueue {
  static final RelatedSongsQueue _instance = RelatedSongsQueue._internal();

  final List<RelatedSongData> _songs = [];

  factory RelatedSongsQueue() {
    return _instance;
  }

  RelatedSongsQueue._internal();

  void addSong(RelatedSongData song) {
    if (!containsSong(song)) {
      debugPrint('Queue size before add: ${_songs.length}');
      _songs.add(song);
      debugPrint('Queue size after add: ${_songs.length}');
      debugPrint('Added song: ${song.title}');
    } else {
      debugPrint('Song already exists in the queue: ${song.title}');
    }
  }

  RelatedSongData? getNextSong() {
    if (_songs.isEmpty) {
      debugPrint('Queue is empty. Cannot get next song.');
      return null;
    }
    final song = _songs.removeAt(0);
    debugPrint(
        'Returning next song: ${song.title}. Remaining queue size: ${_songs.length}');
    return song;
  }

  void clear() {
    debugPrint('Clearing queue. Previous size: ${_songs.length}');
    _songs.clear();
  }

  /// Resets the queue by clearing all songs and reinitializing if needed
  void reset() {
    debugPrint('Resetting queue. Current size: ${_songs.length}');
    _songs.clear();
    debugPrint('Queue reset complete. New size: ${_songs.length}');
  }

  bool get isEmpty => _songs.isEmpty;
  bool get isNotEmpty => _songs.isNotEmpty;
  int get length => _songs.length;

  bool containsSong(RelatedSongData song) {
    return _songs.any((existingSong) =>
        existingSong.title == song.title &&
        existingSong.artists == song.artists);
  }

  List<RelatedSongData> get songs => List.unmodifiable(_songs);

  @override
  String toString() {
    return 'RelatedSongsQueue(length: $length, songs: ${_songs.map((song) => song.title).toList()})';
  }
}
