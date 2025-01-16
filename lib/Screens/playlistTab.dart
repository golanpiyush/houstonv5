import 'package:flutter/material.dart';
import 'package:houstonv8/Services/Managers/playlistManager.dart';
import 'dart:io';

class PlaylistTab extends StatefulWidget {
  const PlaylistTab({super.key});

  @override
  _PlaylistTabState createState() => _PlaylistTabState();
}

class _PlaylistTabState extends State<PlaylistTab> {
  final PlaylistManager _playlistManager = PlaylistManager();
  List<String> _playlists = [];
  List<Map<String, String>> _songs = [];
  String? _selectedPlaylist;

  // Fetch playlists
  Future<void> _fetchPlaylists() async {
    try {
      List<String> playlists = await _playlistManager.getPlaylists();
      setState(() {
        _playlists = playlists;
      });
    } catch (e) {
      print('Error fetching playlists: $e');
    }
  }

  // Fetch songs in the selected playlist
  Future<void> _fetchPlaylistDetails(String playlistName) async {
    try {
      List<Map<String, dynamic>> songs =
          await _playlistManager.getPlaylistDetails(playlistName);
      List<Map<String, String>> stringSongs = songs
          .map((song) =>
              song.map((key, value) => MapEntry(key, value.toString())))
          .toList();

      setState(() {
        _songs = stringSongs.isNotEmpty ? stringSongs : [];
        _selectedPlaylist = playlistName;
      });
    } catch (e) {
      print('Error fetching playlist details: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchPlaylists();
  }

  @override
  Widget build(BuildContext context) {
    return _selectedPlaylist == null
        ? _buildPlaylistGrid()
        : _buildPlaylistDetail();
  }

  // Grid view of playlists
  Widget _buildPlaylistGrid() {
    if (_playlists.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    } else {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10.0,
          mainAxisSpacing: 10.0,
          childAspectRatio: 1,
        ),
        itemCount: _playlists.length,
        itemBuilder: (context, index) {
          final playlistName = _playlists[index];
          return GestureDetector(
            onTap: () => _fetchPlaylistDetails(playlistName),
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder, size: 50, color: Colors.blue),
                  const SizedBox(height: 10),
                  Text(
                    playlistName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  // List view of songs for the selected playlist
  Widget _buildPlaylistDetail() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Folder Icon and Playlist Info
          Container(
            alignment: Alignment.center,
            child: const Column(
              children: [
                Icon(Icons.folder, size: 250, color: Colors.blue),
                SizedBox(height: 10),
                Text(
                  'Date Created: null', // Placeholder text for now
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),

          // Songs List
          _songs.isEmpty
              ? const Center(child: Text('No songs found in this playlist.'))
              : Expanded(
                  child: ListView.builder(
                    itemCount: _songs.length,
                    itemBuilder: (context, index) {
                      final song = _songs[index];
                      final title = song['title'] ?? 'Unknown Title';
                      final artist = song['artist'] ?? 'Unknown Artist';
                      final albumArtPath = song['albumArtPath'] ?? '';
                      final audioPath = song['audioPath'] ?? '';

                      return GestureDetector(
                        onTap: () {
                          // Play the song if valid audio path
                          if (audioPath.isNotEmpty &&
                              File(audioPath).existsSync()) {
                            print('Audio file found at: $audioPath');
                            // Navigate to PlayerScreen or play the song directly
                          } else {
                            print('Audio file not found at: $audioPath');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Audio file not found.')),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              albumArtPath.isNotEmpty &&
                                      File(albumArtPath).existsSync()
                                  ? SizedBox(
                                      width: 50,
                                      height: 50,
                                      child: Image.file(
                                        File(albumArtPath),
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : const Icon(Icons.music_note,
                                      color: Colors.white),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    artist,
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}
