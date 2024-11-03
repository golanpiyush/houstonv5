import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Services/AudioProvider.dart';
import '../Screens/playerScreen.dart';
import '../Services/SongDetails.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final audioProvider = Provider.of<AudioProvider>(context);

    return GestureDetector(
      onTap: () {
        if (audioProvider.currentAudioUrl == audioProvider.currentAudioUrl) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerScreen(
                songDetails: SongDetails(
                  title: audioProvider.currentSongTitle ?? 'No Title',
                  artists: audioProvider.currentArtist ?? 'No Artist',
                  albumArt: audioProvider.currentAlbumArtUrl ?? '',
                  audioUrl: audioProvider.currentAudioUrl ?? '',
                  duration: '',
                ),
              ),
            ),
          ).then((_) {
            audioProvider.setPlayerScreenVisible(false);
          });
        } else {
          audioProvider.setPlayerScreenVisible(true);
          audioProvider.setCurrentSongDetails(SongDetails(
            title: audioProvider.currentSongTitle ?? 'No Title',
            artists: audioProvider.currentArtist ?? 'No Artist',
            albumArt: audioProvider.currentAlbumArtUrl ?? '',
            audioUrl: audioProvider.currentAudioUrl ?? '',
            duration: '',
          ));
          audioProvider.playSong(audioProvider.currentAudioUrl ?? '',
              audioProvider.currentAlbumArtUrl ?? '');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
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
                            print(
                                "Network image failed to load"); // Debug for image
                            return const Icon(Icons.music_note, size: 50);
                          },
                        )
                      : Image.file(
                          File(audioProvider.currentAlbumArtUrl!),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            print(
                                "File image failed to load"); // Debug for image
                            return const Icon(Icons.music_note, size: 50);
                          },
                        ))
                  : Image.asset(
                      'assets/images/default_album_art.jpg',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print("Asset image failed to load"); // Debug for image
                        return const Icon(Icons.music_note, size: 50);
                      },
                    ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ensure text decoration is set to none
                Text(
                  audioProvider.currentSongTitle ?? 'No Title',
                  style: const TextStyle(
                    fontFamily: 'Mosterrat',
                    color: Colors.white,
                    fontSize: 16,
                    decoration: TextDecoration.none, // No underline
                  ),
                ),
                Text(
                  audioProvider.currentArtist ?? 'No Artist',
                  style: const TextStyle(
                    fontFamily: 'Mosterrat',
                    color: Colors.grey,
                    fontSize: 14,
                    decoration: TextDecoration.none, // No underline
                  ),
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                audioProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
              onPressed: () {
                audioProvider.togglePlayPause();
              },
            ),
          ],
        ),
      ),
    );
  }
}
