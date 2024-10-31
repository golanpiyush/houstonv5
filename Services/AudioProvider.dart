import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'SongDetails.dart'; // Ensure this import is correct based on your file structure
import 'dart:async';
import 'package:just_audio_background/just_audio_background.dart'; // Add this import

class AudioProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  bool isMiniPlayer = false;
  // bool _isInitialized = false;
  bool _isPlayerScreenVisible = false;

  bool get isPlayerScreenVisible => _isPlayerScreenVisible;

  StreamSubscription<Duration>? _positionSubscription;

  AudioProvider() {
    // Listen for playback state changes
    _audioPlayer.playingStream.listen((isPlaying) {
      this.isPlaying = isPlaying;
      notifyListeners(); // Notify listeners whenever playback state changes
    });
  }

  // Properties to hold current song details
  String? currentAudioUrl;
  String? currentSongTitle;
  String? currentArtist;
  String? currentAlbumArtUrl;
  String? currentPlayingSongKey;

  // Public getter for the audio player position
  Duration position = Duration.zero;

  // Public getter for the audio player duration
  Duration? get duration => _audioPlayer.duration;

  // Method to set current song details
  void setCurrentSongDetails(SongDetails songDetails) {
    currentSongTitle = songDetails.title;
    currentArtist = songDetails.artists;
    currentAlbumArtUrl = songDetails.albumArt;
    currentAudioUrl = songDetails.audioUrl;

    currentPlayingSongKey = "${songDetails.artists}-${songDetails.title}";

    // Notify listeners about the change
    notifyListeners();
  }

  void setPlayerScreenVisible(bool isVisible) {
    _isPlayerScreenVisible = isVisible;
    notifyListeners();
  }

  // Initialize position listener for real-time UI updates
  void _initializePositionListener() {
    _positionSubscription = _audioPlayer.positionStream.listen((newPosition) {
      position = newPosition;
      notifyListeners(); // Update the UI on each position change
    });
  }

  // Method to seek to a specific position in the audio
  void seekTo(Duration position) {
    _audioPlayer.seek(position);
  }

  MediaItem? _currentMediaItem;

  Future<void> playSong(String audioUrl, String albumArtPath) async {
    try {
      debugPrint("Attempting to play song: $audioUrl");

      String newTitle = currentSongTitle ?? "Unknown Title";
      String newArtist = currentArtist ?? "Unknown Artist";

      // Check if we're trying to play the same song
      if (_currentMediaItem != null &&
          _currentMediaItem!.title == newTitle &&
          _currentMediaItem!.album == newArtist) {
        // Same song, just resume playback if not already playing
        if (!isPlaying) {
          await _audioPlayer.play();
          isPlaying = true;
          notifyListeners();
        }
        return;
      }

      // If we reach here, it's a different song, so initialize new audio source

      // Prepare the artUri
      Uri? artUri;
      if (albumArtPath.isNotEmpty) {
        if (albumArtPath.startsWith('http://') ||
            albumArtPath.startsWith('https://')) {
          artUri = Uri.parse(albumArtPath);
        } else if (albumArtPath.startsWith('file://')) {
          artUri = Uri.parse(albumArtPath);
        } else {
          artUri = Uri.file(albumArtPath);
        }
      }

      // Validate artUri
      if (artUri == null || artUri.hasScheme == false) {
        debugPrint("Invalid artUri: $albumArtPath");
        artUri = null;
      }

      // Create new MediaItem
      _currentMediaItem = MediaItem(
        id: '1',
        album: newArtist,
        title: newTitle,
        artUri: artUri,
      );

      // Set up the new audio source
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(audioUrl),
          tag: _currentMediaItem,
        ),
      );

      await _audioPlayer.play();
      isPlaying = true;
      notifyListeners();

      _initializePositionListener();
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  // Method to toggle play/pause
  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause(); // Await the pause operation
      isPlaying = false;
    } else {
      await _audioPlayer.play(); // Await the play operation
      isPlaying = true;
    }
    notifyListeners(); // Notify listeners to update the UI
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _positionSubscription
        ?.cancel(); // Cancel the position subscription on dispose
    super.dispose();
  }
}
