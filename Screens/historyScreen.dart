import 'package:flutter/material.dart';
import '../Services/musicApiService.dart';
import '../Services/SongDetails.dart';
import 'package:auto_size_text/auto_size_text.dart'; // Make sure you have this package for AutoSizeText
import 'playerScreen.dart'; // Import PlayerScreen

class HistoryScreen extends StatelessWidget {
  final MusicApiService musicApiService;

  HistoryScreen({required this.musicApiService});

  // Method to handle song tap and navigate to PlayerScreen
  void _playSong(Map<String, String> songData, BuildContext context) {
    final songDetails = SongDetails(
      title: songData['title'] ?? '',
      artists: songData['artist'] ?? '',
      albumArt: songData['albumArtPath'] ?? '',
      audioUrl: songData['audioPath'] ?? '',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(songDetails: songDetails),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the song history list from the service
    List<SongDetails> songHistory =
        musicApiService.songHistory; // Access the songHistory getter

    print('Song History Length: ${songHistory.length}');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        title: AutoSizeText(
          'Song History',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w500,
            fontSize: 24,
            color: Colors.white,
          ),
          maxLines: 1,
        ),
      ),
      body: Container(
        color: Colors.black,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SizedBox(height: 10),
                  AutoSizeText(
                    'History of Played Songs',
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.w400,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            FadingDividerBlue(),
            Expanded(
              child: songHistory.isEmpty
                  ? Center(
                      child: AutoSizeText(
                        'No song history available.',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.w400,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                      ),
                    )
                  : ListView.separated(
                      itemCount: songHistory.length,
                      separatorBuilder: (context, index) => FadingDivider(),
                      itemBuilder: (context, index) {
                        final song = songHistory[index];
                        final thumbnailUrl = song.albumArt;

                        // Prepare song data for the _playSong method
                        final songData = {
                          'title': song.title,
                          'artist': song.artists,
                          'albumArtPath': song.albumArt,
                          'audioPath': song.audioUrl,
                        };

                        return Container(
                          margin: EdgeInsets.symmetric(vertical: 5),
                          color: Colors.black,
                          child: ListTile(
                            contentPadding: EdgeInsets.all(8.0),
                            leading: SizedBox(
                              width: 50,
                              height: 50,
                              child: thumbnailUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Image.network(
                                        thumbnailUrl,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Icon(Icons.music_note, color: Colors.grey),
                            ),
                            title: AutoSizeText(
                              song.title,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                            ),
                            subtitle: AutoSizeText(
                              song.artists,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w400,
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                              maxLines: 1,
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Show the time left until the song expires
                                AutoSizeText(
                                  'Expires in: ${song.timeLeft}',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.w100,
                                    fontSize: 5,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              // Call the _playSong method when a song is tapped
                              _playSong(songData, context);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class FadingDividerBlue extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.0,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.blue, Colors.transparent],
          stops: [0.0, 0.5, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }
}

class FadingDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1.0,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Colors.amber, Colors.transparent],
          stops: [0.0, 0.5, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
    );
  }
}
