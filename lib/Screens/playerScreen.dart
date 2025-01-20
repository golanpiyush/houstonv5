import 'package:flutter/material.dart';
import 'package:houstonv8/Services/Managers/downloadManager.dart';
import 'package:houstonv8/Services/Managers/playlistManager.dart';

import 'package:houstonv8/Services/SongDetails.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../Services/StorageService.dart';
import 'dart:io';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../Services/AudioProvider.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PlayerScreen extends StatefulWidget {
  final SongDetails songDetails;
  final bool isMiniplayer;

  const PlayerScreen(
      {super.key, required this.songDetails, required this.isMiniplayer});

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  bool isFavorite = false;
  bool showLyrics = false; // Define showLyrics here
  String? lyrics;
  bool isLoadingLyrics = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  // late RelatedSongData;
  bool _isControllerInitialized = false;
  bool _mounted = true;
  double downloadProgress = 0.0;
  Timer? _colorLoadingTimer;
  Timer? _playlistPressTimer;
  bool _isPlaylistPressed =
      false; // Changed to _isPlaylistPressed to follow naming convention
  Color _iconColor =
      Colors.white30; // Changed to _iconColor to follow naming convention
  late AnimationController _fadeInController;
  late final AudioProvider _audioProvider;
  late final StorageService _storageService;
  final PlaylistManager _playlistManager = PlaylistManager();
  final downloadManager = DownloadManager();

  @override
  void initState() {
    super.initState();
    _storageService = StorageService();
    _initializeAnimation(); // Ensure that both _controller and _fadeInController are initialized
    // _checkIfSongIsLiked();
    _initializePlayerState();
    _initializeScreen();
    _audioProvider = Provider.of<AudioProvider>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      audioProvider.setAlbumArt(widget.songDetails.albumArt);
    });
  }

  void _initializeScreen() {
    if (!_mounted) return;

    // Initialize audio provider after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_mounted) return;
      _initializeAudioProvider();
    });
  }

  // Initialize fade in animation for crossover effect
  void _initializeAnimation() {
    // Play/Pause animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.8, end: 0.0).animate(_controller);

    // Initialize fade-in animation for crossover effect
    _fadeInController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _isControllerInitialized = true;
  }

  void _handleSongChange(bool isNext, AudioProvider audioProvider) {
    // Start dimming current album art
    _controller.forward();

    // Reset fade-in controller for the next album art
    _fadeInController.reset();

    // Animate the fade-out and then proceed with song change
    _controller.forward().then((_) async {
      // Change to the next or previous song
      if (isNext) {
        await audioProvider.nextSong();
        _checkIfSongIsLiked();
      } else {
        _checkIfSongIsLiked();
        await audioProvider.previousSong();
      }

      // Reset dimming animation
      _controller.reset();

      // Fade in the new album art
      _fadeInController.forward();
    });
  }

  void _initializeAudioProvider() {
    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    audioProvider.setCurrentSongDetails(widget.songDetails);

    if (widget.songDetails.audioUrl.isNotEmpty &&
        widget.songDetails.albumArt.isNotEmpty) {
      audioProvider.playSong(
          widget.songDetails.audioUrl, widget.songDetails.albumArt);
    }
  }

  Future<void> _checkIfSongIsLiked() async {
    if (!_mounted) return;

    try {
      final isLiked = await _storageService.isSongLiked(
        widget.songDetails.title,
        widget.songDetails.artists,
      );
      if (!_mounted) return;

      setState(() {
        isFavorite = isLiked;
      });
    } catch (e) {
      debugPrint('Error checking if song is liked: $e');
    }
  }

  Future<void> _initializePlayerState() async {
    if (!_mounted) return;

    final currentSong = await _audioProvider.getCurrentSongDetails();
    if (currentSong != null) {
      setState(() {
        isFavorite = currentSong.isLiked;
      });
    }
  }

  Future<void> _handleFavoriteToggle() async {
    if (!_mounted) return;

    final previousState = isFavorite;
    setState(() {
      isFavorite = !isFavorite;
    });

    try {
      if (isFavorite) {
        _showSnackBar('Adding to favorites...');
        await _audioProvider.toggleLikeCurrentSong();
        if (_mounted) {
          _showSnackBar('Added to favorites!');
        }
      } else {
        _showSnackBar('Removing from favorites...');
        await _audioProvider.unlikeSong(
          title: widget.songDetails.title,
          artist: widget.songDetails.artists,
        );
        if (_mounted) {
          _showSnackBar('Removed from favorites!');
        }
      }

      // Refresh current song details to ensure UI is in sync
      if (_mounted) {
        final updatedSong = await _audioProvider.getCurrentSongDetails();
        if (updatedSong != null) {
          setState(() {
            isFavorite = updatedSong.isLiked;
          });
        }
      }
    } catch (e) {
      debugPrint('Error handling favorite toggle: $e');

      if (_mounted) {
        setState(() {
          isFavorite = previousState;
        });

        String errorMessage = 'Error updating favorites';
        if (e.toString().contains('download')) {
          errorMessage = 'Error downloading song';
        } else if (e.toString().contains('storage')) {
          errorMessage = 'Error saving song';
        }
        _showSnackBar('$errorMessage: Please try again');
      }
    }
  }

  void _showSnackBar(String message) {
    if (!_mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _mounted = false;
    _colorLoadingTimer?.cancel();
    if (_isControllerInitialized) {
      _controller.dispose();
    }
    _fadeInController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(builder: (context, audioProvider, child) {
      final isPlaying = audioProvider.isPlaying;

      // Ensure animations are triggered after the frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isControllerInitialized) {
          // Only update animation if the controller is initialized
          if (isPlaying) {
            _controller.forward();
          } else {
            _controller.reverse();
          }
        }
      });

      return Scaffold(
        backgroundColor: Colors.black,
        appBar: _buildAppBar(audioProvider),
        body: Stack(
          children: [
            // Your main player content goes here
            _buildBody(audioProvider, isPlaying),

            // Miniplayer at the bottom, only visible if `isMiniplayer` is true
            if (widget.isMiniplayer) _buildMiniplayer(context),
          ],
        ),
      );
    });
  }

  Widget _buildMiniplayer(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () {
          // When the miniplayer is tapped, go to full screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerScreen(
                songDetails: widget.songDetails,
                isMiniplayer: false, // Full screen player
              ),
            ),
          );
        },
        child: Container(
          height: 70,
          color: Colors.black.withOpacity(0.8),
          child: Row(
            children: [
              const Icon(Icons.music_note, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.songDetails.title,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    Text(
                      widget.songDetails.artists,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Removed progress display
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(
                  Icons.play_arrow, // Icon to indicate play action
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AudioProvider audioProvider) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      title: Text(audioProvider.currentSongTitle ?? "Unknown Title"),
      centerTitle: true,
      actions: const [],
    );
  }

  Widget _buildBody(AudioProvider audioProvider, bool isPlaying) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.center, // Ensures alignment is centered
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 40), // Adjust padding as needed
          child:
              _buildAlbumArt(audioProvider, isPlaying), // Album art at the top
        ),
        const SizedBox(height: 30), // Space between album art and song info
        _buildSongInfo(audioProvider),
        const SizedBox(height: 30),
        _buildProgressBar(audioProvider),
        _buildTimeLabels(audioProvider),
        const SizedBox(height: 2),
        _buildControls(audioProvider, isPlaying),
      ],
    );
  }

  Widget _buildAlbumArtContainer(AudioProvider audioProvider) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOutQuint,
      width: 340,
      height: 340,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: audioProvider.vibrantColor,
            blurRadius: 20,
            offset: const Offset(5, 5),
          ),
        ],
        image: DecorationImage(
          image: _getAlbumArtImage(audioProvider.currentAlbumArtUrl),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildLyricsOverlay(String lyrics, VoidCallback onDismiss) {
    // Split the lyrics into lines
    List<String> lines = lyrics.split("\n");

    return Positioned(
        top: 0, // Position at the top of the screen
        left: 0,
        right: 0,
        bottom: 0,
        child: GestureDetector(
            onTap: () {
              onDismiss(); // Call the onDismiss function when tapped
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0), // Apply 16 radius
              child: Container(
                padding: const EdgeInsets.all(2.0),
                color: Colors.black
                    .withOpacity(0.7), // Semi-transparent black background
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: lines.map((line) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4.0), // Add spacing between lines
                        child: Text(
                          line.toLowerCase(), // Convert to lowercase
                          textAlign: TextAlign.center, // Center-align the text
                          style: const TextStyle(
                            fontFamily: 'Jost', // Use Jost font
                            color: Colors.white,
                            fontSize: 14.0, // Same font size for all lines
                            fontWeight: FontWeight.w600,
                            height: 1.5, // Line height (spacing)
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            )));
  }

  Widget _buildAlbumArt(AudioProvider audioProvider, bool isPlaying) {
    double? dragStartX; // Horizontal drag start position
    double? dragStartY; // Vertical drag start position

    // Function to fetch lyrics for the current song and artist
    Future<void> fetchLyricsForSong(String songName, String artistName) async {
      setState(() {
        isLoadingLyrics = true; // Start loading
        print(
            "Attempting to fetch lyrics for: $songName by $artistName"); // Debugging
      });

      try {
        // Construct the URL for the new API with both songName and artistName
        final url = Uri.parse(
            "https://some-random-api.com/lyrics/?title=$songName%20$artistName");

        // Fetch the response
        final response = await http.get(url);

        // Check the response status
        if (response.statusCode == 200) {
          // Parse the JSON
          final data = json.decode(response.body);

          // Extract lyrics
          final fetchedLyrics =
              data['lyrics'] ?? 'No lyrics found for this song.';
          print("Lyrics fetched successfully: $fetchedLyrics"); // Debugging

          // Update the state with the fetched lyrics
          setState(() {
            isLoadingLyrics = false;
            lyrics = fetchedLyrics;
            showLyrics = true;
            print("showLyrics set to true");
          });
        } else {
          // Handle non-200 status codes
          print("Failed to fetch lyrics: ${response.statusCode}");
          setState(() {
            lyrics = "I couldn't find the lyrics of $songName by $artistName";
            showLyrics = true;
          });
        }
      } catch (e) {
        // Handle errors
        print("Error fetching lyrics: $e");
        setState(() {
          lyrics = "Error fetching lyrics: $e";
          showLyrics = true; // Show the error message as lyrics
        });
      } finally {
        setState(() {
          isLoadingLyrics = false; // Stop loading
        });
      }
    }

    // Function to fetch lyrics for the current song and artist dynamically
    // Future<void> fetchLyricsForCurrentSong() async {
    //   // Get the current song title and artist from the audio provider
    //   String currentSong = audioProvider.currentSongTitle ?? "Unknown Title";
    //   String currentArtist = audioProvider.currentArtist ?? "Unknown Artist";

    //   // Call the fetchLyricsForSong function with the current song and artist
    //   fetchLyricsForSong(currentSong, currentArtist);
    // }

    return StatefulBuilder(
      builder: (context, localSetState) {
        return GestureDetector(
            onTap: () => audioProvider.togglePlayPause(), // Toggle play/pause
            onHorizontalDragStart: (details) {
              dragStartX =
                  details.localPosition.dx; // Capture horizontal drag start
            },
            onHorizontalDragEnd: (details) {
              if (dragStartX != null) {
                final dragDistance = details.localPosition.dx - dragStartX!;
                const threshold = 20.0; // Threshold for horizontal drag
                if (dragDistance.abs() > threshold) {
                  _handleSongChange(dragDistance < 0, audioProvider);
                }
              }
              dragStartX = null; // Reset drag position
            },
            onVerticalDragStart: (details) {
              dragStartY =
                  details.localPosition.dy; // Capture vertical drag start
              print("Vertical drag started at: $dragStartY"); // Debugging
            },
            onVerticalDragUpdate: (details) {
              if (dragStartY != null) {
                final dragDistance = details.localPosition.dy - dragStartY!;
                const threshold = -50.0; // Negative threshold for swipe up

                print(
                    "Drag distance: $dragDistance, Loading: $isLoadingLyrics"); // Debugging

                if (dragDistance < threshold && !isLoadingLyrics) {
                  final currentSong = audioProvider.currentSongTitle;
                  final currentArtist = audioProvider.currentArtist;
                  if (currentSong != null && currentArtist != null) {
                    fetchLyricsForSong(
                        currentSong, currentArtist); // Fetch lyrics
                  }
                }
              }
            },
            onVerticalDragEnd: (_) {
              dragStartY = null; // Reset drag start position
            },
            child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: showLyrics
                    ? GestureDetector(
                        onTap: () {
                          setState(() {
                            showLyrics = false;
                            print("Lyrics overlay dismissed");
                          });
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _buildAlbumArtContainer(
                                audioProvider), // Album art in the background
                            _buildFadeOverlay(), // Fade overlay on top of the album art
                            _buildLyricsOverlay(lyrics ?? "No lyrics available",
                                () {
                              setState(() {
                                showLyrics = false; // Dismiss lyrics overlay
                              });
                            }), // Lyrics overlay on top
                          ],
                        ),
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Skeletonizer(
                            enabled:
                                isLoadingLyrics, // Enable skeleton loader when lyrics are loading
                            child: AnimatedOpacity(
                              opacity: isLoadingLyrics
                                  ? 0.01
                                  : 1.0, // Lower opacity to 0.1 when loading
                              duration: const Duration(
                                  milliseconds: 300), // Smooth fade transition
                              child: _buildAlbumArtContainer(
                                  audioProvider), // Your album art container
                            ),
                          ),
                          _buildFadeOverlay(), // Your fade overlay
                        ],
                      )));
      },
    );
  }

  ImageProvider _getAlbumArtImage(String? url) {
    if (url != null && url.isNotEmpty) {
      if (Uri.tryParse(url)?.hasScheme ?? false) {
        return NetworkImage(url);
      }
      return FileImage(File(url));
    }
    return const AssetImage('assets/images/default_album_art.jpg');
  }

  Widget _buildFadeOverlay() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        width: 340,
        height: 340,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildSongInfo(AudioProvider audioProvider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            truncateText(audioProvider.currentSongTitle ?? "Unknown Title"),
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
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            truncateText(audioProvider.currentArtist ?? "Unknown Artist"),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontFamily: 'Jost',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(AudioProvider audioProvider) {
    return Slider(
      value: audioProvider.sliderPosition.inSeconds.toDouble(),
      max: audioProvider.duration?.inSeconds.toDouble() ?? 0.0,
      onChanged: (value) {
        // Update the slider position through the new setSliderPosition method
        audioProvider.setSliderPosition(Duration(seconds: value.toInt()));
      },
      onChangeEnd: (value) {
        // Seek to the new position when the user finishes dragging the slider
        audioProvider.seekTo(Duration(seconds: value.toInt()));
      },
      activeColor: audioProvider.vibrantColor,
      inactiveColor: Colors.white30,
    );
  }

  Widget _buildTimeLabels(AudioProvider audioProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTimeLabel(audioProvider.position),
          _buildTimeLabel(audioProvider.duration ?? Duration.zero),
        ],
      ),
    );
  }

  Widget _buildTimeLabel(Duration duration) {
    return Text(
      _formatDuration(duration),
      style: GoogleFonts.jost(
        color: Colors.white,
        fontWeight: FontWeight.w400,
        fontSize: 12,
      ),
    );
  }

  Widget _buildBottomSheetContent() {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.2,
      maxChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                title: const Text("Sleep Timer"),
                onTap: () {
                  // Code to set sleep timer
                },
              ),
              ListTile(
                title: const Text("Add to Playlist"),
                trailing: const Icon(Icons.expand_more),
                onTap: () async {
                  await _showPlaylistSelectionSheet(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls(AudioProvider audioProvider, bool isPlaying) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
              ),
              color: isFavorite
                  ? audioProvider.vibrantColor
                  : audioProvider.vibrantColor,
              iconSize: 30,
              onPressed: _handleFavoriteToggle,
            ),
            const SizedBox(width: 30),
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              color: audioProvider.vibrantColor,
              iconSize: 50,
              onPressed: () => audioProvider.togglePlayPause(),
            ),
            const SizedBox(width: 30),
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.infinity),
              color: audioProvider.isLooping
                  ? audioProvider.vibrantColor
                  : Colors.grey,
              onPressed: () {
                audioProvider.setLoopMode(!audioProvider.isLooping);
                print('looping');
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.plug),
              color: _iconColor,
              iconSize: 25,
              onPressed: () {
                if (_mounted) {
                  setState(() {
                    _iconColor = audioProvider.vibrantColor;
                    _isPlaylistPressed = true;
                  });

                  // Cancel any existing timer
                  _playlistPressTimer?.cancel();

                  // Start new timer
                  _playlistPressTimer = Timer(const Duration(seconds: 20), () {
                    if (_mounted) {
                      setState(() {
                        _isPlaylistPressed = false;
                        _iconColor = Colors.white30;
                      });
                    }
                  });

                  showModalBottomSheet(
                    context: context,
                    builder: (context) => _buildBottomSheetContent(),
                    isScrollControlled: true,
                  );
                }
              },
            ),
          ],
        ),
        if (_isPlaylistPressed && _mounted)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FaIcon(FontAwesomeIcons.plug, size: 18),
                const SizedBox(width: 5),
                Text(
                  "Adding to playlist...",
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color: audioProvider.vibrantColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  String truncateText(String text) {
    const int maxLength = 25;
    if (text.length > maxLength) {
      return '${text.substring(0, maxLength)}...';
    }
    return text;
  }

  Future<void> _showPlaylistSelectionSheet(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF1DB954), // Spotify-like green color
        ),
      ),
    );

    final List<String> playlists = await _playlistManager.getPlaylists();
    debugPrint("Fetched playlists: $playlists");

    // Dismiss loading spinner
    Navigator.pop(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Makes bottom sheet expandable
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height:
              MediaQuery.of(context).size.height * 0.7, // 70% of screen height
          decoration: const BoxDecoration(
            color: Color(0xFF121212), // Dark background
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Handle bar at the top
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Add to Playlist",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'JosefinSans',
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Create New Playlist Button
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8, bottom: 16),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _createNewPlaylist();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1DB954),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          "Create New Playlist",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'JosefinSans',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: playlists.isEmpty
                      ? const Center(
                          child: Text(
                            "No playlists yet.\nCreate one to get started!",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              fontFamily: 'Jost',
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: playlists.length,
                          itemBuilder: (context, index) {
                            final playlistName = playlists[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF282828),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                title: Text(
                                  playlistName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: 'Jost',
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.add_circle_outline,
                                  color: Color(0xFF1DB954),
                                ),
                                onTap: () async {
                                  Navigator.pop(context);
                                  await _addToPlaylist(playlistName);
                                },
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _createNewPlaylist() async {
    String? playlistName = await _showCreatePlaylistDialog();

    if (playlistName != null && playlistName.isNotEmpty) {
      // Accessing properties directly from the SongDetails object
      final songDetails =
          widget.songDetails; // widget.songDetails is a SongDetails object

      final String title = songDetails.title; // Access title
      final String artist = songDetails.artists; // Access artist
      final String albumArtUrl = songDetails.albumArt; // Access albumArtUrl
      final String audioUrl = songDetails.audioUrl; // Access audioUrl

      Map<String, dynamic> songDetailsplaylistcreation = {
        'title': title,
        'artist': artist,
        'albumArtUrl': albumArtUrl,
        'audioUrl': audioUrl,
      };
      print("Creating new playlist: $playlistName");
      await _playlistManager.createPlaylist(
          playlistName, songDetailsplaylistcreation);
      _showSnackBar('New playlist "$playlistName" created!');
      setState(() {}); // Refresh the UI to reflect the new playlist
    }
  }

  Future<String?> _showCreatePlaylistDialog() async {
    TextEditingController controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Create New Playlist"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "Enter playlist name"),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text);
              },
              child: const Text("Create"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addToPlaylist(String playlistName) async {
    try {
      // Accessing properties directly from the SongDetails object
      final songDetails =
          widget.songDetails; // widget.songDetails is a SongDetails object

      final String title = songDetails.title; // Access title
      final String artist = songDetails.artists; // Access artist
      final String albumArtUrl = songDetails.albumArt; // Access albumArtUrl
      final String audioUrl = songDetails.audioUrl; // Access audioUrl

      // Prepare the song details as a Map
      Map<String, dynamic> songDetailsMap = {
        'title': title,
        'artist': artist,
        'albumArtUrl': albumArtUrl,
        'audioUrl': audioUrl,
      };

      // Generate a base path for storing the song data (e.g., using the song's title and artist)
      String basePath =
          '${playlistName}_$title'; // Example, you can customize it

      // Call the PlaylistManager method to add the song to the playlist
      await _playlistManager.addSongToPlaylist(
        playlistName: playlistName,
        songDetails: songDetailsMap, // Pass the map to addSongToPlaylist
        basePath: basePath, // Use the generated base path
      );

      _showSnackBar('Added to $playlistName');
    } catch (e) {
      debugPrint("Error adding song to $playlistName: $e");
    }
  }
}
