import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Services/AudioProvider.dart'; // Import your audio provider
import '../Screens/playerScreen.dart'; // Import your player screen
import '../Services/SongDetails.dart'; // Import your SongDetails class

class MiniPlayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final audioProvider = Provider.of<AudioProvider>(context);

    return GestureDetector(
      onTap: () {
        // Check if the song in the mini player is the same as the currently selected song
        if (audioProvider.currentAudioUrl == audioProvider.currentAudioUrl) {
          // Navigate to the player screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerScreen(
                songDetails: SongDetails(
                  title: audioProvider.currentSongTitle ?? 'No Title',
                  artists: audioProvider.currentArtist ?? 'No Artist',
                  albumArt: audioProvider.currentAlbumArtUrl ?? '',
                  audioUrl: audioProvider.currentAudioUrl ?? '',
                  duration: '', // Replace with actual duration if available
                ),
              ),
            ),
          ).then((_) {
            // Reset visibility when returning to the previous screen
            audioProvider.setPlayerScreenVisible(false);
          });
        } else {
          // If a different song is selected
          audioProvider.setPlayerScreenVisible(true);

          // Set current song details and initialize audio playback
          audioProvider.setCurrentSongDetails(SongDetails(
            title: audioProvider.currentSongTitle ?? 'No Title',
            artists: audioProvider.currentArtist ?? 'No Artist',
            albumArt: audioProvider.currentAlbumArtUrl ?? '',
            audioUrl: audioProvider.currentAudioUrl ?? '',
            duration: '', // Replace with actual duration if available
          ));

          // Call the playSong method to initialize playback
          audioProvider.playSong(audioProvider.currentAudioUrl ?? '',
              audioProvider.currentAlbumArtUrl ?? '');
        }
      },
      child: Container(
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Display album art
            ClipOval(
              child: audioProvider.currentAlbumArtUrl != null &&
                      audioProvider.currentAlbumArtUrl!.isNotEmpty
                  ? (Uri.tryParse(audioProvider.currentAlbumArtUrl!)
                              ?.hasScheme ??
                          false
                      ? Image.network(
                          audioProvider.currentAlbumArtUrl!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.music_note, size: 50);
                          },
                        )
                      : Image.file(
                          File(audioProvider.currentAlbumArtUrl!),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.music_note, size: 50);
                          },
                        ))
                  : Image.asset(
                      'assets/images/default_album_art.jpg',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.music_note, size: 50);
                      },
                    ),
            ),
            SizedBox(width: 10),
            // Display song title and artist
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  audioProvider.currentSongTitle ?? 'No Title',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                Text(
                  audioProvider.currentArtist ?? 'No Artist',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
            Spacer(),
            // Optionally, add a play/pause button here
            IconButton(
              icon: Icon(
                audioProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
              onPressed: () {
                // Handle play/pause functionality here
                audioProvider.togglePlayPause();
              },
            ),
          ],
        ),
      ),
    );
  }
}
