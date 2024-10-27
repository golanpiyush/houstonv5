// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'AudioProvider.dart'; // Ensure this import matches your file structure

// class MiniPlayer extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<AudioProvider>(
//       builder: (context, audioProvider, child) {
//         return Container(
//           padding: const EdgeInsets.all(16.0),
//           decoration: BoxDecoration(
//             color: Colors.black,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black45,
//                 blurRadius: 10,
//                 offset: Offset(0, 5),
//               ),
//             ],
//           ),
//           child: Row(
//             children: [
//               // Album Art
//               Container(
//                 width: 50,
//                 height: 50,
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(8),
//                   image: DecorationImage(
//                     image: (audioProvider.currentAlbumArtUrl != null && 
//                              audioProvider.currentAlbumArtUrl!.isNotEmpty)
//                         ? NetworkImage(audioProvider.currentAlbumArtUrl!)
//                         : AssetImage('assets/placeholder.png') as ImageProvider, // Provide a local placeholder image
//                     fit: BoxFit.cover,
//                   ),
//                 ),
//               ),
//               const SizedBox(width: 10),
//               // Song Details
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       audioProvider.currentSongTitle ?? "Unknown Title",
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.bold,
//                       ),
//                       overflow: TextOverflow.ellipsis,
//                       maxLines: 1,
//                     ),
//                     Text(
//                       audioProvider.currentArtist ?? "Unknown Artist",
//                       style: TextStyle(
//                         color: Colors.white70,
//                       ),
//                       overflow: TextOverflow.ellipsis,
//                       maxLines: 1,
//                     ),
//                   ],
//                 ),
//               ),
//               // Play/Pause Button
//               IconButton(
//                 icon: Icon(
//                   audioProvider.isPlaying ? Icons.pause : Icons.play_arrow,
//                   color: Colors.white,
//                 ),
//                 onPressed: () async {
//                   await audioProvider.togglePlayPause();
//                 },
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }
