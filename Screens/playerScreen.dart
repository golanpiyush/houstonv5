import 'package:flutter/material.dart';
import 'package:houstonv8/Services/SongDetails.dart';
import 'package:provider/provider.dart';
import '../Services/AudioProvider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Services/StorageService.dart';
import 'dart:io';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'dart:async';

class PlayerScreen extends StatefulWidget {
  final SongDetails songDetails;

  const PlayerScreen({super.key, required this.songDetails});

  @override
  _PlayerScreenState createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  bool isFavorite = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _isControllerInitialized = false;
  bool _mounted = true;
  double downloadProgress = 0.0;
  Timer? _colorLoadingTimer;
  late AnimationController _fadeInController;

  final StorageService _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _initializeAnimation(); // Ensure that both _controller and _fadeInController are initialized
    _checkIfSongIsLiked();
    _initializeScreen();

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
    _controller.forward(); // Start dimming current album art
    _fadeInController.reset(); // Reset fade-in for the next album art

    _controller.forward().then((_) {
      if (isNext) {
        audioProvider.nextSong();
      } else {
        audioProvider.previousSong();
      }
      _controller.reset(); // Reset dimming animation
      _fadeInController.forward(); // Fade in the new album art
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

  Future<void> _handleFavoriteToggle() async {
    if (!_mounted) return;

    final previousState = isFavorite;
    setState(() {
      isFavorite = !isFavorite;
    });

    try {
      if (isFavorite) {
        await _storageService.likeSong(
          title: widget.songDetails.title,
          artist: widget.songDetails.artists,
          albumArtUrl: widget.songDetails.albumArt,
          audioUrl: widget.songDetails.audioUrl,
        );
        _showSnackBar('Added to favorites!');
      } else {
        await _storageService.cancelDownload();
        await _storageService.unlikeSong(
          widget.songDetails.title,
          widget.songDetails.artists,
        );
        _showSnackBar('Removed from favorites!');
      }
    } catch (e) {
      debugPrint('Error handling favorite toggle: $e');
      // Revert state on error
      if (_mounted) {
        setState(() {
          isFavorite = previousState;
        });
        _showSnackBar('Error updating favorites: Please try again');
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
        body: _buildBody(audioProvider, isPlaying),
      );
    });
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildAlbumArt(audioProvider, isPlaying),
          const SizedBox(height: 30),
          _buildSongInfo(audioProvider),
          const SizedBox(height: 30),
          _buildProgressBar(audioProvider),
          _buildTimeLabels(audioProvider),
          const SizedBox(height: 2),
          _buildControls(audioProvider, isPlaying),
        ],
      ),
    );
  }

  Widget _buildAlbumArtContainer(AudioProvider audioProvider) {
    return Container(
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
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildAlbumArt(AudioProvider audioProvider, bool isPlaying) {
    double? dragStartX;

    return GestureDetector(
      onTap: () => audioProvider.togglePlayPause(),
      onHorizontalDragStart: (details) {
        dragStartX = details.localPosition.dx;
      },
      onHorizontalDragEnd: (details) {
        if (dragStartX != null) {
          final dragDistance = details.localPosition.dx - dragStartX!;
          const threshold = 40.0;
          if (dragDistance.abs() > threshold) {
            _handleSongChange(dragDistance < 0, audioProvider);
          }
        }
        dragStartX = null;
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildAlbumArtContainer(audioProvider),
          _buildFadeOverlay(),
        ],
      ),
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
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(AudioProvider audioProvider) {
    return Slider(
      value: audioProvider.position.inMilliseconds
          .toDouble()
          .clamp(0, (audioProvider.duration?.inMilliseconds.toDouble() ?? 1)),
      min: 0,
      max: (audioProvider.duration?.inMilliseconds.toDouble() ?? 1),
      onChanged: (value) {
        audioProvider.seekTo(Duration(milliseconds: value.toInt()));
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

  Widget _buildControls(AudioProvider audioProvider, bool isPlaying) {
    return Row(
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
              : Colors.grey, // Change color based on loop state
          onPressed: () {
            audioProvider.setLoopMode(!audioProvider.isLooping);
            print('looping');
          },
        )
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
}
