class SongDetails {
  final String title;
  final String artists;
  final String album;
  final String duration;
  final String albumArt;
  final String audioUrl;

  SongDetails({
    required this.title,
    required this.artists,
    required this.album,
    required this.duration,
    required this.albumArt,
    required this.audioUrl,
  });

  factory SongDetails.fromJson(Map<String, dynamic> json) {
    return SongDetails(
      title: json['title'] ?? '',
      artists: json['artists'] ?? '',
      album: json['album'] ?? '',
      duration: json['duration'] ?? '',
      albumArt: json['album_art'] ?? '',
      audioUrl: json['audio_url'] ?? '',
    );
  }
}
