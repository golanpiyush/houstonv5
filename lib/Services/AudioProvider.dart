import 'package:flutter/material.dart';
import 'package:houstonv8/Services/PaletteGeneratorService.dart';
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

  // State management
  bool isPlaying = false;
  bool isMiniPlayer = false;
  bool _isLooping = false;
  bool isChangingSong = false;
  bool _isPlayerScreenVisible = false;
  final bool _isLoadingRelatedSongs = false;

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
  List<SongDetails>? _relatedSongsQueue;
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

  // Update the initialization to handle network songs differently
  void _initializeAudioPlayer() {
    // Playing state listener
    _playingSubscription = _audioPlayer.playingStream.listen((playing) {
      isPlaying = playing;
      notifyListeners();
    });

    _durationSubscription = _audioPlayer.durationStream.listen((duration) {
      notifyListeners();
    });

    // Processing state listener with network audio check
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        // markSongAsPlayedOrSkipped();
        // nextSong();

        // Only auto-play next song if it's not a network audio
        if (!_isNetworkAudio) {
          // if (_relatedSongsQueue == null) {
          //   // Corrected comparison (== instead of =)
          //   print('fetching and playing');
          //   fetchAndCacheRelatedSongs();
          // }

          markSongAsPlayedOrSkipped();
          nextSong();
          // _handleNextNetworkSong();
        } else {
          markSongAsPlayedOrSkipped();
          _handleNextNetworkSong();
        }
      }
      notifyListeners();
    });

    // Position listener with more frequent updates
    _initializePositionListener();
  }

  // Position listener with related songs fetching logic
  void _initializePositionListener() {
    _positionSubscription?.cancel();
    _positionSubscription = _audioPlayer.positionStream.listen((newPosition) {
      if (isChangingSong) return;
      position = newPosition;
      sliderPosition = newPosition;

      // Check if we should fetch related songs (after 10 seconds)
      // if (_isNetworkAudio &&
      //     newPosition.inSeconds >= 10 &&
      //     !_isLoadingRelatedSongs &&
      //     !_hasFetchedRelatedSongs) {
      //   _isLoadingRelatedSongs = true;
      //   fetchAndCacheRelatedSongs().then((_) {
      //     _isLoadingRelatedSongs = false;
      //     _hasFetchedRelatedSongs = true;
      //   });
      // }

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
      _relatedSongsQueue = [];
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

  Future<List<SongDetails>> fetchAndCacheRelatedSongs() async {
    // Check if related songs are already cached
    if (_relatedSongsQueue != null && _relatedSongsQueue!.isNotEmpty) {
      print("Returning related songs from cache...");
      return _relatedSongsQueue!;
    }

    try {
      // Fetch related songs from API
      final MusicApiService apiService = MusicApiService(
        baseUrl: 'https://hhlxm0tg-5000.inc1.devtunnels.ms/',
      );
      final List<RelatedSong> relatedSongs =
          await apiService.fetchRelatedSongs(); // Call instance method

      // Convert RelatedSong to SongDetails
      final List<SongDetails> songDetailsList = relatedSongs.map((song) {
        return SongDetails(
          title: song.title,
          artists: song.artists,
          albumArt: song.album_art,
          audioUrl: song.audio_url,
        );
      }).toList();

      // Cache the songs if any are fetched
      if (songDetailsList.isNotEmpty) {
        _relatedSongsQueue = songDetailsList; // Store in cache
        print("Caching related songs...");
      }

      // Ensure that _relatedSongsQueue is non-null when returning
      return _relatedSongsQueue ?? []; // Return an empty list if it's null
    } catch (e) {
      print("Error fetching related songs: $e");
      return []; // Return empty list if something goes wrong
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

  Future<void> _handleNextNetworkSong() async {
    if (_relatedSongsQueue?.isEmpty ?? true) {
      await fetchAndCacheRelatedSongs();
      return;
    }

    if (_currentRelatedSongIndex == 4) {
      await fetchAndCacheRelatedSongs();
    }

    final nextSong = _relatedSongsQueue![_currentRelatedSongIndex];
    _currentRelatedSongIndex =
        (_currentRelatedSongIndex + 1) % _relatedSongsQueue!.length;

    // Update current song details before playing
    setCurrentSongDetails(nextSong);

    await playSong(
      nextSong.audioUrl,
      nextSong.albumArt,
      title: nextSong.title,
      artist: nextSong.artists,
    );
    notifyListeners();
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
    _relatedSongsQueue = [];
    _currentRelatedSongIndex = 0;
    notifyListeners();
  }

  /// Updates the previous song details for history tracking
  /// This is useful for implementing "recently played" or back navigation features
  void updatePreviousSongDetails({
    required String? title,
    required String? artist,
    required String? audioUrl,
  }) {
    previousSongTitle = title;
    previousArtist = artist;
    previousAudioUrl = audioUrl;
    // No need to notify listeners as this is internal state that doesn't affect UI
  }

  // Update playSong method to ensure MediaItem is properly set
  Future<void> playSong(String audioUrl, String albumArtPath,
      {String? title, String? artist}) async {
    try {
      isChangingSong = true;
      position = Duration.zero;
      sliderPosition = Duration.zero;

      // Use the current song details that were set earlier
      String newTitle = title ?? currentSongTitle ?? "Unknown Title";
      String newArtist = artist ?? currentArtist ?? "Unknown Artist";

      if (albumArtPath.isNotEmpty) {
        _loadVibrantColor(albumArtPath);
      }

      Uri? artUri = _createArtUri(albumArtPath);

      _currentMediaItem = MediaItem(
        id: DateTime.now()
            .millisecondsSinceEpoch
            .toString(), // Unique ID for each song
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
    super.dispose();
  }
}
