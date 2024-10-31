import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Services/PaletteGeneratorService.dart';
import '../Services/AudioProvider.dart';
import '../Services/SongDetails.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Services/StorageService.dart';
import 'dart:io';

class PlayerScreen extends StatefulWidget {
  final SongDetails songDetails;

  const PlayerScreen({super.key, required this.songDetails});

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  Color? vibrantColor;
  bool isFavorite = false; // Variable to track favorite state
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _isControllerInitialized =
      false; // Flag to track controller initialization
  // double _progress = 0.0;
  double downloadProgress = 0.0;

  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _checkIfSongIsLiked(); // Check if the song is liked
  }

  void _initializeAnimation() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.8, end: 0.0).animate(_controller);
    _isControllerInitialized = true; // Set the flag to true
  }

  @override
  void dispose() {
    if (_isControllerInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _checkIfSongIsLiked() async {
    final isLiked = await _storageService.isSongLiked(
      widget.songDetails.title,
      widget.songDetails.artists,
    );
    setState(() {
      isFavorite = isLiked;
    });
  }

  Future<void> _loadVibrantColor(String imageUrl) async {
    final paletteGeneratorService = PaletteGeneratorService();
    final color = await paletteGeneratorService.getVibrantColor(imageUrl);
    setState(() {
      vibrantColor = color;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);

    // Wrap state changes in addPostFrameCallback to avoid build phase errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      audioProvider.setCurrentSongDetails(widget.songDetails);
      audioProvider.currentSongTitle = widget.songDetails.title;
      audioProvider.currentArtist = widget.songDetails.artists;
      audioProvider.currentAlbumArtUrl = widget.songDetails.albumArt;
      audioProvider.currentAudioUrl = widget.songDetails.audioUrl;

      // Ensure both audioUrl and albumArt are provided
      if (widget.songDetails.audioUrl.isNotEmpty &&
          widget.songDetails.albumArt.isNotEmpty) {
        audioProvider.playSong(
            widget.songDetails.audioUrl, widget.songDetails.albumArt);
      }

      _loadVibrantColor(widget.songDetails.albumArt);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, child) {
        // Determine if the audio is playing
        bool isPlaying = audioProvider.isPlaying;

        // Control the fade animation based on playback state
        if (_isControllerInitialized) {
          if (isPlaying) {
            _controller.forward(); // Fade out when playing
          } else {
            _controller.reverse(); // Fade in when paused
          }
        }

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            title: Text(audioProvider.currentSongTitle ?? "Unknown Title"),
            centerTitle: true,
            actions: const [],
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () async {
                    await audioProvider.togglePlayPause();
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                          width: 340,
                          height: 340,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: vibrantColor?.withOpacity(0.7) ??
                                    Colors.black45,
                                blurRadius: 20,
                                offset: const Offset(5, 5),
                              ),
                            ],
                            image: DecorationImage(
                              image: audioProvider.currentAlbumArtUrl != null &&
                                      audioProvider
                                          .currentAlbumArtUrl!.isNotEmpty
                                  ? (Uri.tryParse(audioProvider
                                                  .currentAlbumArtUrl!)
                                              ?.hasScheme ??
                                          false
                                      ? NetworkImage(audioProvider
                                          .currentAlbumArtUrl!) // Use network image if valid URL
                                      : FileImage(File(audioProvider
                                          .currentAlbumArtUrl!))) // Fallback to local file
                                  : const AssetImage(
                                      'assets/images/default_album_art.jpg'), // Fallback to default asset if both are invalid
                              fit: BoxFit.cover,
                            ),
                          )),
                      // Low-light filter overlay with fade animation
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: 340,
                          height: 340,
                          decoration: BoxDecoration(
                            color: Colors.black
                                .withOpacity(0.9), // Low light filter
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                // Song Title and Artist
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Center(
                    child: Text(
                      truncateText(
                          audioProvider.currentSongTitle ?? "Unknown Title"),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontFamily: 'Jost',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Center(
                    child: Text(
                      truncateText(
                          audioProvider.currentArtist ?? "Unknown Artist"),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Progress Bar
                Slider(
                  value: audioProvider.position.inMilliseconds.toDouble().clamp(
                      0,
                      (audioProvider.duration?.inMilliseconds.toDouble() ?? 1)),
                  min: 0,
                  max: (audioProvider.duration?.inMilliseconds.toDouble() ?? 1),
                  onChanged: (value) {
                    audioProvider.seekTo(Duration(milliseconds: value.toInt()));
                  },
                  activeColor: vibrantColor,
                  inactiveColor: Colors.white30,
                ),
                const SizedBox(height: 0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(audioProvider.position),
                        style: GoogleFonts.jost(
                          color: Colors.white, // Text color
                          fontWeight:
                              FontWeight.w400, // Medium weight for Jost font
                          fontSize: 12, // Adjust font size as desired
                        ),
                      ),
                      Text(
                        _formatDuration(
                            audioProvider.duration ?? Duration.zero),
                        style: GoogleFonts.jost(
                          color: Colors.white, // Text color
                          fontWeight:
                              FontWeight.w400, // Medium weight for Jost font
                          fontSize: 12, // Adjust font size as desired
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                // Playback Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                      ),
                      color: isFavorite
                          ? vibrantColor ?? Colors.white
                          : Colors.white,
                      iconSize: 30,
                      onPressed: () async {
                        setState(() {
                          isFavorite = !isFavorite; // Toggle favorite state
                        });

                        // If it's marked as favorite, save the song details locally
                        if (isFavorite) {
                          try {
                            await _storageService.likeSong(
                              title: widget.songDetails.title,
                              artist: widget.songDetails.artists,
                              albumArtUrl: widget.songDetails.albumArt,
                              audioUrl: widget.songDetails.audioUrl,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Added to favorites!')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error saving song: $e')),
                            );
                          }
                        } else {
                          // If it's unmarked as favorite, remove it and cancel the download if in progress
                          try {
                            // Cancel the download if it's in progress
                            await _storageService
                                .cancelDownload(); // Cancel download
                            await _storageService.unlikeSong(
                              widget.songDetails.title,
                              widget.songDetails.artists,
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Removed from favorites!')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Error removing song: $e')),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 40),
                    IconButton(
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                      color: vibrantColor,
                      iconSize: 50,
                      onPressed: () async {
                        await audioProvider.togglePlayPause();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  // Method to truncate text if it exceeds a certain length
  String truncateText(String text) {
    const int maxLength = 25; // Maximum length for the text
    if (text.length > maxLength) {
      return '${text.substring(0, maxLength)}...'; // Truncate and add ellipsis
    }
    return text; // Return the original text if it's within the limit
  }
}
