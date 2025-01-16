// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:houstonv8/Services/AudioProvider.dart';
// import 'package:provider/provider.dart';
// import '../Screens/playerScreen.dart';
// import '../Services/SongDetails.dart';
// import 'package:auto_size_text/auto_size_text.dart';

// class MiniPlayer extends StatelessWidget {
//   const MiniPlayer({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final audioProvider = Provider.of<AudioProvider>(context);

//     // Helper function to truncate text if it's too long
//     String truncateText(String text, int wordLimit) {
//       List<String> words = text.split(' ');
//       if (words.length > wordLimit) {
//         return '${words.sublist(0, wordLimit).join(' ')}...';
//       }
//       return text;
//     }

//     return GestureDetector(
//       onTap: () {
//         // Check if the song is the same or not
//         bool isSameSong =
//             audioProvider.currentSongTitle == audioProvider.previousSongTitle &&
//                 audioProvider.currentArtist == audioProvider.previousArtist &&
//                 audioProvider.currentAudioUrl == audioProvider.previousAudioUrl;

//         if (isSameSong) {
//           // The song is the same, just navigate to the PlayerScreen without passing song details
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//                 builder: (context) => PlayerScreen(
//                         songDetails: SongDetails(
//                       title: audioProvider.currentSongTitle ?? 'No Title',
//                       artists: audioProvider.currentArtist ?? 'No Artist',
//                       albumArt: audioProvider.currentAlbumArtUrl ?? '',
//                       audioUrl: audioProvider.currentAudioUrl ?? '',
//                     ))),
//           ).then((_) {
//             audioProvider.setPlayerScreenVisible(false);
//           });
//         } else {
//           // The song is different, so start a new playback
//           audioProvider.setPlayerScreenVisible(true);
//           audioProvider.setCurrentSongDetails(SongDetails(
//             title: audioProvider.currentSongTitle ?? 'No Title',
//             artists: audioProvider.currentArtist ?? 'No Artist',
//             albumArt: audioProvider.currentAlbumArtUrl ?? '',
//             audioUrl: audioProvider.currentAudioUrl ?? '',
//           ));

//           // Play the song if it's different
//           if (audioProvider.currentAudioUrl != null &&
//               audioProvider.currentAudioUrl != '') {
//             audioProvider.playSong(audioProvider.currentAudioUrl ?? '',
//                 audioProvider.currentAlbumArtUrl ?? '');
//           }

//           audioProvider.updatePreviousSongDetails(
//             title: audioProvider.previousSongTitle,
//             artist: audioProvider.previousArtist,
//             audioUrl: audioProvider.previousAudioUrl,
//           );
//           // Navigate to PlayerScreen
//           Navigator.push(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => PlayerScreen(
//                     songDetails: SongDetails(
//                   title: audioProvider.currentSongTitle ?? 'No Title',
//                   artists: audioProvider.currentArtist ?? 'No Artist',
//                   albumArt: audioProvider.currentAlbumArtUrl ?? '',
//                   audioUrl: audioProvider.currentAudioUrl ?? '',
//                 )),
//               )).then((_) {
//             audioProvider.setPlayerScreenVisible(false);
//           });
//         }
//       },
//       child: Container(
//         padding: const EdgeInsets.all(10),
//         decoration: BoxDecoration(
//           color: Colors.black54,
//           borderRadius: BorderRadius.circular(8),
//         ),
//         child: Row(
//           children: [
//             ClipOval(
//               child: audioProvider.currentAlbumArtUrl != null &&
//                       audioProvider.currentAlbumArtUrl!.isNotEmpty
//                   ? (Uri.tryParse(audioProvider.currentAlbumArtUrl!)
//                               ?.hasScheme ??
//                           false
//                       ? Image.network(
//                           audioProvider.currentAlbumArtUrl!,
//                           width: 50,
//                           height: 50,
//                           fit: BoxFit.cover,
//                           errorBuilder: (context, error, stackTrace) {
//                             print("Network image failed to load");
//                             return const Icon(Icons.music_note, size: 50);
//                           },
//                         )
//                       : Image.file(
//                           File(audioProvider.currentAlbumArtUrl!),
//                           width: 50,
//                           height: 50,
//                           fit: BoxFit.cover,
//                           errorBuilder: (context, error, stackTrace) {
//                             print("File image failed to load");
//                             return const Icon(Icons.music_note, size: 50);
//                           },
//                         ))
//                   : Image.asset(
//                       'assets/images/default_album_art.jpg',
//                       width: 50,
//                       height: 50,
//                       fit: BoxFit.cover,
//                       errorBuilder: (context, error, stackTrace) {
//                         print("Asset image failed to load");
//                         return const Icon(Icons.music_note, size: 50);
//                       },
//                     ),
//             ),
//             const SizedBox(width: 10),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   AutoSizeText(
//                     truncateText(
//                         audioProvider.currentSongTitle ?? 'No Title', 40),
//                     style: const TextStyle(
//                       fontFamily: 'Mosterrat',
//                       color: Colors.white,
//                       fontSize: 16,
//                       decoration: TextDecoration.none,
//                     ),
//                     maxLines: 1,
//                     minFontSize: 12,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                   AutoSizeText(
//                     truncateText(
//                         audioProvider.currentArtist ?? 'No Artist', 40),
//                     style: const TextStyle(
//                       fontFamily: 'Mosterrat',
//                       color: Colors.grey,
//                       fontSize: 14,
//                       decoration: TextDecoration.none,
//                     ),
//                     maxLines: 1,
//                     minFontSize: 12,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ],
//               ),
//             ),
//             IconButton(
//               icon: Icon(
//                 audioProvider.isPlaying ? Icons.pause : Icons.play_arrow,
//                 color: Colors.white,
//               ),
//               onPressed: () {
//                 audioProvider.togglePlayPause();
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
