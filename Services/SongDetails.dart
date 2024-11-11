// ignore: file_names
class SongDetails {
  final String title;
  final String artists; // Change this to List<String>?
  final String albumArt;
  final String audioUrl;

  SongDetails({
    required this.title,
    required this.artists,
    required this.albumArt,
    required this.audioUrl,
  });

  factory SongDetails.fromJson(Map<String, dynamic> json) {
    return SongDetails(
      title: json['title'] ?? '',
      artists: json['artists'] ?? '',
      albumArt: json['album_art'] ?? '',
      audioUrl: json['audio_url'] ?? '',
    );
  }
}
