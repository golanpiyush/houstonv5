import 'package:flutter/material.dart';
import 'package:houstonv8/Screens/playerScreen.dart';
import 'package:houstonv8/Services/AudioProvider.dart';
import 'package:houstonv8/Services/SongDetails.dart';
import 'package:provider/provider.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'dart:io';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  ImageProvider _getAlbumArtImage(String? url) {
    if (url != null && url.isNotEmpty) {
      if (Uri.tryParse(url)?.hasScheme ?? false) {
        return NetworkImage(url);
      }
      if (url.startsWith('file://')) {
        return FileImage(File(url.replaceFirst('file://', '')));
      }
      return FileImage(File(url));
    }
    return const AssetImage('assets/images/default_album_art.jpg');
  }

  @override
  Widget build(BuildContext context) {
    final audioProvider = Provider.of<AudioProvider>(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: () {
          // Construct SongDetails and navigate to PlayerScreen
          final songDetails = SongDetails(
              audioUrl: audioProvider.currentAudioUrl ?? '',
              title: audioProvider.currentSongTitle ?? '',
              artists: audioProvider.currentArtist ?? '',
              albumArt: audioProvider.currentAlbumArtUrl ?? '');

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerScreen(
                songDetails: songDetails,
                isMiniplayer: false,
              ),
            ),
          );
        },
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < 0) {
              audioProvider.nextSong();
            } else if (details.primaryVelocity! > 0) {
              audioProvider.previousSong();
            }
          }
        },
        child: Container(
          height: 80,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 17, 6, 6).withOpacity(0.4),
                offset: const Offset(0, -2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Row(
            children: [
              // Album art
              audioProvider.currentAlbumArtUrl != null
                  ? Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            offset: const Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image(
                          image: _getAlbumArtImage(
                              audioProvider.currentAlbumArtUrl),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.music_note, color: Colors.white),
                    ),
              const SizedBox(width: 10),
              // Song details
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoSizeText(
                      audioProvider.currentSongTitle ?? 'Unknown Song',
                      style: const TextStyle(
                        fontFamily: 'Jost',
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      minFontSize: 12,
                    ),
                    AutoSizeText(
                      audioProvider.currentArtist ?? 'Unknown Artist',
                      style: const TextStyle(
                        fontFamily: 'Jost',
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      minFontSize: 10,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  audioProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () {
                  audioProvider.togglePlayPause();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
