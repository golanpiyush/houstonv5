// ignore: file_names
class SongDetails {
  final String title;
  final String artists;
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

// Function to extract expiration timestamp from the audio URL
int? extractExpireTimestamp(String audioUrl) {
  final uri = Uri.parse(audioUrl);
  final expireParam = uri.queryParameters['expire'];
  if (expireParam != null) {
    return int.tryParse(expireParam);
  }
  return null;
}

// Function to convert the expiration timestamp to a readable format
String convertTimestampToTimeRemaining(int expireTimestamp) {
  DateTime currentTime = DateTime.now();
  DateTime expireTime =
      DateTime.fromMillisecondsSinceEpoch(expireTimestamp * 1000);

  Duration timeDiff = expireTime.difference(currentTime);

  int days = timeDiff.inDays;
  int hours = timeDiff.inHours % 24;
  int minutes = timeDiff.inMinutes % 60;

  return '$days days, $hours hours, $minutes minutes';
}
