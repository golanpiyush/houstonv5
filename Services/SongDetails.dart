class SongDetails {
  final String title;
  final String artists;
  final String albumArt;
  final String audioUrl;
  int? expireTime;

  SongDetails({
    required this.title,
    required this.artists,
    required this.albumArt,
    required this.audioUrl,
    this.expireTime,
  });

  // Convert the SongDetails instance to a JSON object
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artists': artists,
      'album_art': albumArt,
      'audio_url': audioUrl,
      'expireTime': expireTime,
    };
  }

  // Factory constructor to create a SongDetails object from JSON data
  factory SongDetails.fromJson(Map<String, dynamic> json) {
    return SongDetails(
      title: json['title'] ?? 'Unknown Title',
      artists: json['artists'] ?? 'Unknown Artists',
      albumArt: json['album_art'] ?? '',
      audioUrl: json['audio_url'] ?? '',
      expireTime: json['expireTime'] as int?,
    );
  }

  // Getter for time left in a human-readable format
  String get timeLeft {
    if (expireTime == null) return 'soon';

    final expireDate = DateTime.fromMillisecondsSinceEpoch(expireTime! * 1000);
    final currentDate = DateTime.now();
    final difference = expireDate.difference(currentDate);

    if (difference.isNegative) return 'Expired';

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    String timeLeft = '';
    if (days > 0) timeLeft += '$days d ';
    if (hours > 0) timeLeft += '$hours h ';
    if (minutes > 0) timeLeft += '$minutes m';
    return timeLeft.trim();
  }
}
