import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'SongDetails.dart'; // Ensure this import is correct based on your file structure
import 'dart:async';
// import 'package:audio_service/audio_service.dart';

class AudioProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  bool isMiniPlayer = false;
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
    // _startBackgroundPlayback();
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

  // Method to initialize and play a new song
  Future<void> playSong(String audioUrl) async {
    try {
      debugPrint("Attempting to play song: $audioUrl");
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
      isPlaying = true;
      notifyListeners(); // Notify listeners to update UI

      // Start the position listener for real-time updates
      _initializePositionListener();
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  // void togglePlayPause() {
  //   if (_audioPlayer.playing) {
  //     _audioPlayer.pause();
  //     isPlaying = false;
  //   } else {
  //     _audioPlayer.play();
  //     isPlaying = true;
  //   }
  //   notifyListeners(); // Notify listeners to update UI
  // }
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
