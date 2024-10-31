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

    // Notify listeners about the change
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

  // Method to initialize and play a new song with MediaItem tag
  Future<void> playSong(String audioUrl, String albumArtPath) async {
    try {
      debugPrint("Attempting to play song: $audioUrl");

      // Check if the audioUrl is a local file or a remote URL
      if (audioUrl.startsWith('file://')) {
        print("Playing song from local file.");
      } else if (audioUrl.startsWith('http://') ||
          audioUrl.startsWith('https://')) {
        print("Playing song from URL.");
      } else {
        print("Unknown audio source.");
      }

      // Prepare the artUri
      Uri? artUri;

      // Check if the albumArtPath is a valid URL first
      if (albumArtPath.isNotEmpty) {
        // Try URL first
        if (albumArtPath.startsWith('http://') ||
            albumArtPath.startsWith('https://')) {
          artUri = Uri.parse(albumArtPath);
        } else if (albumArtPath.startsWith('file://')) {
          artUri = Uri.parse(albumArtPath);
        } else {
          // Assuming the albumArtPath could be a local file without 'file://' prefix
          artUri = Uri.file(albumArtPath);
        }
      }

      // If the parsed URI is not valid, log a message
      if (artUri == null || artUri.hasScheme == false) {
        debugPrint("Invalid artUri: $albumArtPath");
        artUri = null; // Fall back to null if invalid
      }

      // Set up the audio source with a MediaItem tag for background capabilities
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(audioUrl),
          tag: MediaItem(
            id: '1', // Ensure a unique ID per track
            album: currentArtist ?? "Unknown Artist",
            title: currentSongTitle ?? "Unknown Title",
            artUri: artUri, // Set the validated artUri
          ),
        ),
      );

      await _audioPlayer.play();
      isPlaying = true;
      notifyListeners(); // Notify listeners to update UI

      // Start the position listener for real-time updates
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
