// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:houstonv8/Screens/playerScreen.dart';
// import 'package:houstonv8/Services/Managers/playlistManager.dart';
// import 'package:houstonv8/Services/SongDetails.dart';

// class PlaylistScreen extends StatefulWidget {
//   const PlaylistScreen({super.key});

//   @override
//   _PlaylistScreenState createState() => _PlaylistScreenState();
// }

// class _PlaylistScreenState extends State<PlaylistScreen> {
//   final PlaylistManager _playlistManager = PlaylistManager();

//   List<Map<String, String>> _songs = [];
//   String? _selectedPlaylist;

//   // Fetch playlists when the screen is loaded
//   Future<List<String>> _fetchPlaylists() async {
//     return await _playlistManager.getPlaylists();
//   }

//   // Fetch details of songs in the selected playlist
//   Future<void> _fetchPlaylistDetails(String playlistName) async {
//     try {
//       List<Map<String, dynamic>> songs =
//           await _playlistManager.getPlaylistDetails(playlistName);

//       // Convert to List<Map<String, String>> if necessary
//       List<Map<String, String>> stringSongs = songs
//           .map((song) =>
//               song.map((key, value) => MapEntry(key, value.toString())))
//           .toList();

//       setState(() {
//         _selectedPlaylist = playlistName;
//         _songs = stringSongs.isNotEmpty ? stringSongs : [];
//       });
//     } catch (e) {
//       print('Error fetching playlist details: $e');
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(_selectedPlaylist ?? 'Playlists'),
//         leading: _selectedPlaylist != null
//             ? IconButton(
//                 icon: const Icon(Icons.arrow_back),
//                 onPressed: () {
//                   setState(() {
//                     _selectedPlaylist = null;
//                     _songs = [];
//                   });
//                 },
//               )
//             : null,
//       ),
//       body: SafeArea(
//         child:
//             _selectedPlaylist == null ? _buildPlaylistList() : _buildSongList(),
//       ),
//     );
//   }

//   // Build the grid view of playlists
//   Widget _buildPlaylistList() {
//     return FutureBuilder<List<String>>(
//       future: _fetchPlaylists(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }
//         if (snapshot.hasError) {
//           return Center(child: Text('Error: ${snapshot.error}'));
//         }
//         if (!snapshot.hasData || snapshot.data!.isEmpty) {
//           return const Center(child: Text('No playlists found.'));
//         }

//         final playlists = snapshot.data!;
//         return GridView.builder(
//           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: 2,
//             crossAxisSpacing: 10.0,
//             mainAxisSpacing: 10.0,
//             childAspectRatio: 1,
//           ),
//           itemCount: playlists.length,
//           itemBuilder: (context, index) {
//             final playlistName = playlists[index];
//             return GestureDetector(
//               onTap: () => _fetchPlaylistDetails(playlistName),
//               child: Card(
//                 elevation: 5,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Icon(Icons.folder, size: 50, color: Colors.blue),
//                     const SizedBox(height: 10),
//                     Text(
//                       playlistName,
//                       textAlign: TextAlign.center,
//                       style: const TextStyle(
//                           fontSize: 16, fontWeight: FontWeight.bold),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }

//   // Build the list of songs in the selected playlist
//   Widget _buildSongList() {
//     if (_songs.isEmpty) {
//       return const Center(child: Text("No songs found in this playlist."));
//     }

//     return ListView.builder(
//       itemCount: _songs.length,
//       itemBuilder: (context, index) {
//         final song = _songs[index];
//         final title = song['title'] ?? 'Unknown Title';
//         final artist = song['artist'] ?? 'Unknown Artist';
//         final albumArtPath = song['albumArtPath'] ?? '';
//         final audioPath = song['audioPath'] ?? '';

//         return GestureDetector(
//           onTap: () {
//             if (audioPath.isNotEmpty && File(audioPath).existsSync()) {
//               print('Audio file found at: $audioPath');
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => PlayerScreen(
//                     songDetails: SongDetails(
//                       title: title,
//                       artists: artist,
//                       albumArt: albumArtPath,
//                       audioUrl: audioPath,
//                     ),
//                   ),
//                 ),
//               );
//             } else {
//               print('Audio file not found at: $audioPath');
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text('Audio file not found.')),
//               );
//             }
//           },
//           child: Container(
//             padding: const EdgeInsets.all(10),
//             margin: const EdgeInsets.only(bottom: 10),
//             decoration: BoxDecoration(
//               color: Colors.black.withOpacity(0.5),
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Row(
//               children: [
//                 // Album art or default icon
//                 albumArtPath.isNotEmpty && File(albumArtPath).existsSync()
//                     ? SizedBox(
//                         width: 50,
//                         height: 50,
//                         child: Image.file(
//                           File(albumArtPath),
//                           fit: BoxFit.cover,
//                         ),
//                       )
//                     : const Icon(Icons.music_note, color: Colors.white),
//                 const SizedBox(width: 10),
//                 Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       title,
//                       style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold),
//                     ),
//                     Text(
//                       artist,
//                       style: const TextStyle(color: Colors.white70),
//                     ),
//                   ],
//                 ),
//                 const Spacer(),
//                 IconButton(
//                   icon: const Icon(Icons.more_vert, color: Colors.white),
//                   onPressed: () {
//                     _removeFromPlaylist(title, artist);
//                   },
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   // Remove song from playlist
//   Future<void> _removeFromPlaylist(String title, String artist) async {
//     await _playlistManager.deleteSongFromPlaylist(
//       _selectedPlaylist!,
//       title,
//     );
//     setState(() {
//       _songs.removeWhere(
//           (song) => song['title'] == title && song['artist'] == artist);
//     });
//   }
// }
