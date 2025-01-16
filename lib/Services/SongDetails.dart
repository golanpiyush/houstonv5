// song_details.dart

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
      'albumArt': albumArt,
      'audioUrl': audioUrl,
      'expireTime': expireTime,
    };
  }

  // Factory constructor to create a SongDetails object from JSON data
  factory SongDetails.fromJson(Map<String, dynamic> json) {
    return SongDetails(
      title: json['title'] ?? 'Unknown Title',
      artists: json['artists'] ?? 'Unknown Artists',
      albumArt: json['albumArt'] ?? '',
      audioUrl: json['audioUrl'] ?? '',
      expireTime: json['expireTime'] as int?,
    );
  }

  // A factory constructor to create a default song
  factory SongDetails.defaultSong() {
    return SongDetails(
      title: 'Unknown Title',
      artists: 'Unknown Artist',
      albumArt: 'assets/images/default_album_art.jpg',
      audioUrl: '',
      expireTime: null,
    );
  }

  // Getter for time left in a human-readable format
  String get timeLeft {
    if (expireTime == null) return 'No expiration info';

    final expireDate = DateTime.fromMillisecondsSinceEpoch(expireTime! * 1000);
    final currentDate = DateTime.now();
    final difference = expireDate.difference(currentDate);

    if (difference.isNegative) return 'Expired';

    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;

    return [
      if (days > 0) '$days d',
      if (hours > 0) '$hours h',
      if (minutes > 0) '$minutes m',
    ].join(' ').trim();
  }
}

class RelatedSong {
  final String title;
  final String artists;
  final String album_art;
  final String audio_url;

  RelatedSong({
    required this.title,
    required this.artists,
    required this.album_art,
    required this.audio_url,
  });

  factory RelatedSong.fromJson(Map<String, dynamic> json) {
    return RelatedSong(
      title: json['title'] ?? 'Unknown Title',
      artists: json['artists'] ?? 'Unknown Artists',
      album_art: json['album_art'] ?? 'No Album Art',
      audio_url: json['audio_url'] ?? 'No Audio URL',
    );
  }

  @override
  String toString() {
    return '''
Song Title: $title
Artist: $artists
Album: $album_art
Audio URL: $audio_url
-----------------------------''';
  }
}
