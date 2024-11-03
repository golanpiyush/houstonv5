import 'dart:io';

import 'package:flutter/material.dart';
import '../Services/StorageService.dart';
import '../Services/SongDetails.dart';
import 'PlayerScreen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Services/AudioProvider.dart';
import 'miniplayer.dart'; // Ensure you have the MiniPlayer import
import 'package:provider/provider.dart';

class LikedSongsScreen extends StatefulWidget {
  const LikedSongsScreen({super.key});

  @override
  _LikedSongsScreenState createState() => _LikedSongsScreenState();
}

class _LikedSongsScreenState extends State<LikedSongsScreen> {
  final StorageService _storageService = StorageService();
  bool _isLoading = true;
  List<Map<String, String>> _likedSongs = [];

  @override
  void initState() {
    super.initState();
    _loadLikedSongs();
  }

  Future<void> _loadLikedSongs() async {
    try {
      final songs = await _storageService.getLikedSongs();
      setState(() {
        _likedSongs = songs;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading liked songs: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unlikeSong(String title, String artist) async {
    try {
      await _storageService.unlikeSong(title, artist);
      await _loadLikedSongs(); // Reload the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unlike song: $e')),
      );
    }
  }

  void _playSong(Map<String, String> songData) {
    final songDetails = SongDetails(
      title: songData['title'] ?? '',
      artists: songData['artist'] ?? '',
      duration: '', // You might want to store this in StorageService if needed
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          'Downloaded Songs',
          style: GoogleFonts.jost(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Main content
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white))
              : _likedSongs.isEmpty
                  ? Center(
                      child: Text(
                        'No downloaded songs yet',
                        style: GoogleFonts.jost(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _likedSongs.length,
                      itemBuilder: (context, index) {
                        final song = _likedSongs[index];
                        return Dismissible(
                          key: Key(song['title']! + song['artist']!),
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20.0),
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          direction: DismissDirection.endToStart,
                          onDismissed: (direction) {
                            _unlikeSong(song['title']!, song['artist']!);
                          },
                          child: ListTile(
                            onTap: () => _playSong(song),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(File(song['albumArtPath']!)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            title: Text(
                              song['title'] ?? 'Unknown Title',
                              style: GoogleFonts.jost(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              song['artist'] ?? 'Unknown Artist',
                              style: GoogleFonts.jost(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.white70),
                              onPressed: () {
                                // Show options menu if needed
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.grey[900],
                                  builder: (context) => Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.delete,
                                            color: Colors.white),
                                        title: const Text(
                                          'Remove from downloads',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _unlikeSong(
                                              song['title']!, song['artist']!);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
          // MiniPlayer at the bottom of the screen
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Consumer<AudioProvider>(
              builder: (context, audioProvider, child) {
                return Visibility(
                  visible: !audioProvider.isPlayerScreenVisible,
                  child: const MiniPlayer(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
