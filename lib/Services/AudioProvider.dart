import 'package:flutter/material.dart';
import 'package:houstonv8/Services/PaletteGeneratorService.dart';
import 'package:houstonv8/Services/RelatedSongsData.dart';
import 'package:houstonv8/Services/StorageService.dart';
import 'package:houstonv8/Services/musicApiService.dart';
import 'package:just_audio/just_audio.dart';
import 'SongDetails.dart';
import 'dart:async';
import 'package:just_audio_background/just_audio_background.dart';

/// Class to manage related songs queue
class AudioProvider with ChangeNotifier {
  // Constants
  static const int _maxSongsBeforeReset = 13;

  // Services
  final AudioPlayer _audioPlayer = AudioPlayer();
  final StorageService _storageService = StorageService();
  final PaletteGeneratorService _paletteService = PaletteGeneratorService();
  final RelatedSongsQueue _relatedSongsQueue = RelatedSongsQueue();
  StreamSubscription<RelatedSongData>? _relatedSongsSubscription;

  // State management
  bool isPlaying = false;
  bool isMiniPlayer = false;
  bool _isLooping = false;
  bool isChangingSong = false;
  bool _isPlayerScreenVisible = false;
  bool _isLoadingRelatedSongs = false;
  bool showEmptyQueueMessage = false;

  // Current playback state
  Duration position = Duration.zero;
  Duration sliderPosition = Duration.zero;
  Color _vibrantColor = Colors.grey;
  MediaItem? _currentMediaItem;
  Timer? _colorLoadingTimer;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;

  // Song queue management
  int _currentRelatedSongIndex = 0;
  int _songsPlayedOrSkipped = 0;

  // Current song details
  String? currentAudioUrl;
  String? currentSongTitle;
  String? currentArtist;
  String? currentAlbumArtUrl;
  String? currentPlayingSongKey;

  // Previous song details
  String? previousSongTitle;
  String? previousArtist;
  String? previousAudioUrl;

  // Getters
  bool get isPlayerScreenVisible => _isPlayerScreenVisible;
  bool get isLooping => _isLooping;
  bool get isLoadingRelatedSongs => _isLoadingRelatedSongs;
  Color get vibrantColor => _vibrantColor;
  Duration? get duration => _audioPlayer.duration;

  AudioProvider() {
    _initializeAudioPlayer();
  }

  /// Ensure playback starts only after the queue is ready
  void startPlaybackAfterQueueReady() {
    debugPrint('Queue size before check: ${_relatedSongsQueue.length}');
    if (_relatedSongsQueue.isEmpty) {
      debugPrint('Queue is empty. Waiting for songs...');
      // Optionally, handle the empty queue scenario
    } else if (!isPlaying) {
      // Start playback only if not already playing
      debugPrint('Queue is already populated. Starting playback.');
      nextSong();
    }
  }

  /// Initialize audio player and listeners
  void _initializeAudioPlayer() {
    _playingSubscription = _audioPlayer.playingStream.listen((playing) {
      isPlaying = playing;
      notifyListeners();
    });

    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      notifyListeners();
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        markSongAsPlayedOrSkipped();
        nextSong();
      }
      notifyListeners();
    });

    _initializePositionListener();
  }

  /// Position listener for playback
  void _initializePositionListener() {
    _positionSubscription?.cancel();
    _positionSubscription = _audioPlayer.positionStream.listen((newPosition) {
      if (isChangingSong) return;
      position = newPosition;
      sliderPosition = newPosition;
      notifyListeners();
    });
  }

  // UI Update Methods
  void setSliderPosition(Duration position) {
    sliderPosition = position;
    notifyListeners();
  }

  void setCurrentSongDetails(SongDetails songDetails) {
    currentSongTitle = songDetails.title;
    currentArtist = songDetails.artists;
    currentAlbumArtUrl = songDetails.albumArt;
    currentAudioUrl = songDetails.audioUrl;
    currentPlayingSongKey = "${songDetails.artists}-${songDetails.title}";
    notifyListeners();
  }

  void setAlbumArt(String? url) {
    currentAlbumArtUrl = url;
    notifyListeners();
  }

  void setPlayerScreenVisible(bool isVisible) {
    _isPlayerScreenVisible = isVisible;
    notifyListeners();
  }

  // Playback Control Methods
  Future<void> togglePlayPause() async {
    try {
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
      isPlaying = _audioPlayer.playing;
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling play/pause: $e');
      notifyListeners();
    }
  }

  Future<void> seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
      this.position = position; // Update local position
      notifyListeners();
    } catch (e) {
      debugPrint('Error seeking: $e');
      notifyListeners();
    }
  }

  void setLoopMode(bool shouldLoop) {
    _isLooping = shouldLoop;
    _audioPlayer.setLoopMode(shouldLoop ? LoopMode.one : LoopMode.off);
    notifyListeners();
  }

  // Related Songs Management
  void markSongAsPlayedOrSkipped() {
    _songsPlayedOrSkipped++;
    if (_songsPlayedOrSkipped >= _maxSongsBeforeReset) {
      resetRelatedSongs();
    }
  }

  void resetRelatedSongs() {
    if (_audioPlayer.processingState != ProcessingState.idle) {
      _currentRelatedSongIndex = 0;
      _songsPlayedOrSkipped = 0;
      notifyListeners();
    }
  }

  // Navigation Methods
  Future<void> previousSong() async {
    if (_isNetworkAudio) {
      return;
    }

    final likedSongs = await _storageService.getLikedSongs();
    if (likedSongs.isEmpty) return;

    int currentIndex = _findCurrentSongIndex(likedSongs);
    int previousIndex =
        (currentIndex - 1 + likedSongs.length) % likedSongs.length;

    await _playLikedSong(likedSongs[previousIndex]);
  }

  Future<void> nextSong() async {
    if (_isNetworkAudio) {
      await _handleNextNetworkSong();
    } else {
      await _handleNextLocalSong();
    }
  }

  // Helper Methods
  bool get _isNetworkAudio =>
      currentAudioUrl != null &&
      (currentAudioUrl!.startsWith('http://') ||
          currentAudioUrl!.startsWith('https://'));

  int _findCurrentSongIndex(List<Map<String, String>> songs) {
    return songs.indexWhere((song) =>
        song['title'] == currentSongTitle && song['artist'] == currentArtist);
  }

  /// Handle the next song in the queue
  Future<void> _handleNextNetworkSong() async {
    // Check if the related songs queue is empty
    if (_relatedSongsQueue.isEmpty) {
      debugPrint('Queue is empty. No songs to play.');
      return;
    }

    // Inspect the queue and song data
    debugPrint('Related Songs Queue: $_relatedSongsQueue');

    // Get the next song from the queue
    final RelatedSongData? nextSong = _relatedSongsQueue.getNextSong();

    if (nextSong == null) {
      debugPrint('No more songs in the queue.');
      return;
    }

    // Inspect nextSong data
    debugPrint('Next Song: ${nextSong.title}, Audio URL: ${nextSong.audioUrl}');

    try {
      debugPrint('Playing next network song: ${nextSong.title}');

      // Set current song details for the player
      setCurrentSongDetails(SongDetails(
        title: nextSong.title,
        artists: nextSong.artists,
        albumArt: nextSong.albumArt,
        audioUrl: nextSong.audioUrl,
      ));

      // Play the song
      await playSong(
        nextSong.audioUrl,
        nextSong.albumArt,
        title: nextSong.title,
        artist: nextSong.artists,
      );

      debugPrint('Next song URL: ${nextSong.audioUrl}');

      notifyListeners(); // Notify listeners about the state change
    } catch (e) {
      debugPrint('Error playing next network song: $e');

      // Optional: Skip to the next song in case of failure
      await _handleNextNetworkSong(); // Recursively attempt to play the next song
    }
  }

  Future<void> _handleNextLocalSong() async {
    final likedSongs = await _storageService.getLikedSongs();
    if (likedSongs.isEmpty) return;

    int currentIndex = _findCurrentSongIndex(likedSongs);
    int nextIndex = (currentIndex + 1) % likedSongs.length;

    await _playLikedSong(likedSongs[nextIndex]);
  }

  Future<void> _playLikedSong(Map<String, String> songDetails) async {
    currentSongTitle = songDetails['title'];
    currentArtist = songDetails['artist'];
    currentAlbumArtUrl = songDetails['albumArtPath'];

    await playSong(
      songDetails['audioPath']!,
      songDetails['albumArtPath']!,
    );
  }

  /// Clears the queue of related songs
  void clearRelatedSongs() {
    _currentRelatedSongIndex = 0;
    notifyListeners();
  }

  /// Updates the previous song details for history tracking
  void updatePreviousSongDetails({
    required String? title,
    required String? artist,
    required String? audioUrl,
  }) {
    previousSongTitle = title;
    previousArtist = artist;
    previousAudioUrl = audioUrl;
  }

  // Update playSong method to ensure MediaItem is properly set
  Future<void> playSong(String audioUrl, String albumArtPath,
      {String? title, String? artist}) async {
    try {
      isChangingSong = true;
      position = Duration.zero;
      sliderPosition = Duration.zero;

      String newTitle = title ?? currentSongTitle ?? "Unknown Title";
      String newArtist = artist ?? currentArtist ?? "Unknown Artist";

      if (albumArtPath.isNotEmpty) {
        _loadVibrantColor(albumArtPath);
      }

      Uri? artUri = _createArtUri(albumArtPath);

      _currentMediaItem = MediaItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        album: newArtist,
        title: newTitle,
        artUri: artUri,
      );

      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(audioUrl),
          tag: _currentMediaItem,
        ),
      );

      position = Duration.zero;
      await _audioPlayer.play();
      isPlaying = true;
      isChangingSong = false;

      _initializePositionListener();
      notifyListeners();
    } catch (e) {
      debugPrint("Error playing audio: $e");
      isChangingSong = false;
      notifyListeners();
    }
    resetRelatedSongs();
  }

  Uri? _createArtUri(String albumArtPath) {
    if (albumArtPath.isEmpty) return null;

    try {
      if (albumArtPath.startsWith('http://') ||
          albumArtPath.startsWith('https://') ||
          albumArtPath.startsWith('file://')) {
        return Uri.parse(albumArtPath);
      }
      return Uri.file(albumArtPath);
    } catch (e) {
      debugPrint("Error creating artUri: $e");
      return null;
    }
  }

  void _loadVibrantColor(String imageUrl) {
    _colorLoadingTimer?.cancel();
    _colorLoadingTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        _vibrantColor = await _paletteService.getVibrantColor(imageUrl);
        notifyListeners();
      } catch (e) {
        _vibrantColor = Colors.blue;
        notifyListeners();
      }
    });
  }

  String _truncateExtraText(String text) {
    return text.replaceAll(RegExp(r'[\(\[].*?[\)\]]'), '').trim();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playingSubscription?.cancel();
    _colorLoadingTimer?.cancel();
    _relatedSongsSubscription?.cancel();
    _relatedSongsQueue.clear();
    super.dispose();
  }
}
