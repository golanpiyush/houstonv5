import 'package:flutter/material.dart';
import 'package:houstonv8/Services/PaletteGeneratorService.dart';
import 'package:houstonv8/Services/RelatedSongsData.dart';
import 'package:houstonv8/Services/StorageService.dart';
import 'package:just_audio/just_audio.dart';
import 'SongDetails.dart';
import 'dart:async';
import 'package:just_audio_background/just_audio_background.dart';

class CurrentSong {
  final String title;
  final String artist;
  final String url;
  final String? albumArt;
  final bool isLiked;
  final String? key;

  CurrentSong({
    required this.title,
    required this.artist,
    required this.url,
    this.albumArt,
    this.isLiked = false,
    this.key,
  });
}

extension CurrentSongExtension on CurrentSong {
  CurrentSong copyWith({
    String? title,
    String? artist,
    String? url,
    String? albumArt,
    bool? isLiked,
    String? key,
  }) {
    return CurrentSong(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      url: url ?? this.url,
      albumArt: albumArt ?? this.albumArt,
      isLiked: isLiked ?? this.isLiked,
      key: key ?? this.key,
    );
  }
}

/// Class to manage audio related services
class AudioProvider with ChangeNotifier {
  // Constants
  static const int _maxSongsBeforeReset = 13;
  CurrentSong? _currentSong;

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
  int _songsPlayedOrSkipped = 0;

  // Current song details
  CurrentSong? get currentSong => _currentSong;

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

  Future<void> setCurrentSongDetails(SongDetails songDetails) async {
    currentSongTitle = songDetails.title;
    currentArtist = songDetails.artists;
    currentAlbumArtUrl = songDetails.albumArt;
    currentAudioUrl = songDetails.audioUrl;
    currentPlayingSongKey = "${songDetails.artists}-${songDetails.title}";

    final isLiked = await _storageService.isSongLiked(
      songDetails.title,
      songDetails.artists,
    );

    _currentSong = CurrentSong(
      title: songDetails.title,
      artist: songDetails.artists,
      url: songDetails.audioUrl,
      albumArt: songDetails.albumArt,
      isLiked: isLiked,
      key: currentPlayingSongKey,
    );

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

  Future<CurrentSong?> getCurrentSongDetails() async {
    if (currentSongTitle == null ||
        currentArtist == null ||
        currentAudioUrl == null) {
      return null;
    }

    final isLiked = await _storageService.isSongLiked(
      currentSongTitle!,
      currentArtist!,
    );

    return CurrentSong(
      title: currentSongTitle!,
      artist: currentArtist!,
      url: currentAudioUrl!,
      albumArt: currentAlbumArtUrl,
      isLiked: isLiked,
      key: currentPlayingSongKey,
    );
  }

  /// Checks if a song is currently downloading
  bool isSongDownloading(String title, String artist) {
    return _storageService.isDownloading &&
        _storageService.currentDownloadTitle == title &&
        _storageService.currentDownloadArtist == artist;
  }

  Future<String> toggleLikeCurrentSong() async {
    debugPrint('toggleLikeCurrentSong called');

    if (currentSongTitle == null ||
        currentArtist == null ||
        currentAudioUrl == null ||
        currentAlbumArtUrl == null) {
      return 'Error: Song details are missing';
    }

    try {
      // Optimistically toggle the UI state
      if (_currentSong != null) {
        final currentStatus = _currentSong!.isLiked;
        _currentSong = _currentSong!.copyWith(isLiked: !currentStatus);
        notifyListeners();
      }

      // Perform the toggle action
      if (_currentSong?.isLiked == true) {
        debugPrint('Adding song to favorites');
        await _storageService.likeSong(
          title: currentSongTitle!,
          artist: currentArtist!,
          albumArtUrl: currentAlbumArtUrl!,
          audioUrl: currentAudioUrl!,
        );
        return 'Added to favorites';
      } else {
        debugPrint('Removing song from favorites');
        await _storageService.unlikeSong(currentSongTitle!, currentArtist!);
        return 'Removed from favorites';
      }
    } catch (e) {
      debugPrint('Error in toggleLikeCurrentSong: $e');

      // Revert UI state on error
      if (_currentSong != null) {
        final currentStorageState = await _storageService.isSongLiked(
            currentSongTitle!, currentArtist!);
        _currentSong = _currentSong!.copyWith(isLiked: currentStorageState);
        notifyListeners();
      }
      return 'Error updating favorites: Please try again';
    }
  }

  /// Handle unliking the current song
  Future<void> unlikeCurrentSong() async {
    if (currentSongTitle == null || currentArtist == null) return;

    try {
      // Use existing StorageService unlikeSong method
      await _storageService.unlikeSong(
        currentSongTitle!,
        currentArtist!,
      );

      // Update current song state
      if (_currentSong != null) {
        _currentSong = CurrentSong(
          title: _currentSong!.title,
          artist: _currentSong!.artist,
          url: _currentSong!.url,
          albumArt: _currentSong!.albumArt,
          isLiked: false,
          key: _currentSong!.key,
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error unliking current song: $e');
      rethrow;
    }
  }

  Future<void> unlikeSong({
    required String title,
    required String artist,
    Function? onStart,
    Function? onSuccess,
    Function(String)? onError,
  }) async {
    try {
      // Notify start of unlike process
      onStart?.call();

      // Check if this is the currently playing song
      if (currentSongTitle == title && currentArtist == artist) {
        // Update current song's like status
        _currentSong = _currentSong?.copyWith(isLiked: false);
      }

      // Unlike the song using storage service
      await _storageService.unlikeSong(title, artist);

      // Notify success
      onSuccess?.call();
      notifyListeners();
    } catch (e) {
      debugPrint('Error unliking song: $e');
      onError?.call('Failed to unlike song: ${e.toString()}');
      // Re-throw to allow UI to handle error if needed
      rethrow;
    }
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
      _songsPlayedOrSkipped = 0;
      notifyListeners();
    }
  }

  // Navigation Methods
  Future<void> previousSong() async {
    if (_isNetworkAudio) {
      // If it's a network audio, handle it (you may want to fetch from the history or queue)
      final previousSong = _relatedSongsQueue.getPreviousSong();
      if (previousSong != null) {
        // Handle playing the previous network song
        await _playNetworkSong(previousSong);
      }
      return;
    }

    final likedSongs = await _storageService.getLikedSongs();
    if (likedSongs.isEmpty) return;

    int currentIndex = _findCurrentSongIndex(likedSongs);
    int previousIndex =
        (currentIndex - 1 + likedSongs.length) % likedSongs.length;

    await playLikedSong(likedSongs[previousIndex]);
  }

  Future<void> _playNetworkSong(RelatedSongData previousSong) async {
    try {
      // Set the current song details using RelatedSongData
      currentSongTitle = previousSong.title;
      currentArtist = previousSong.artists;
      currentAlbumArtUrl = previousSong.albumArt;
      currentAudioUrl = previousSong.audioUrl;
      currentPlayingSongKey = "${previousSong.artists}-${previousSong.title}";

      // Update the UI
      notifyListeners();

      // Play the song directly from RelatedSongData
      await playSong(
        previousSong.audioUrl,
        previousSong.albumArt,
        title: previousSong.title,
        artist: previousSong.artists,
      );
      debugPrint('Now playing song: ${currentSongTitle}');

      debugPrint('Playing previous network song: ${previousSong.title}');
    } catch (e) {
      debugPrint('Error playing previous network song: $e');
    }
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

    await playLikedSong(likedSongs[nextIndex]);
  }

  /// Play a song from liked songs
  Future<void> playLikedSong(Map<String, String> songDetails) async {
    try {
      currentSongTitle = songDetails['title'];
      currentArtist = songDetails['artist'];
      currentAlbumArtUrl = songDetails['albumArtPath'];
      currentAudioUrl = songDetails['audioPath'];
      currentPlayingSongKey =
          "${songDetails['artist']}-${songDetails['title']}";

      await playSong(
        songDetails['audioPath']!,
        songDetails['albumArtPath']!,
        title: songDetails['title'],
        artist: songDetails['artist'],
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error playing liked song: $e');
      // Handle error appropriately
    }
  }

  /// Clears the queue of related songs
  void clearRelatedSongs() {
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
      String newTitle = title ?? currentSongTitle ?? "Unknown Title";
      String newArtist = artist ?? currentArtist ?? "Unknown Artist";

      // Check like status first
      final isLiked = await _storageService.isSongLiked(newTitle, newArtist);

      // Update current song with correct like status
      _currentSong = CurrentSong(
        title: newTitle,
        artist: newArtist,
        url: audioUrl,
        albumArt: albumArtPath,
        isLiked: isLiked,
        key: "$newArtist-$newTitle",
      );

      if (_audioPlayer.audioSource != null) {
        final currentSource = _audioPlayer.audioSource;

        // Check if the current source is a UriAudioSource
        if (currentSource is UriAudioSource) {
          final currentUri = currentSource.uri.toString();
          if (audioUrl == currentUri) {
            debugPrint("Same audio source detected. Updating metadata only.");

            if (albumArtPath.isNotEmpty) {
              _loadVibrantColor(albumArtPath);
            }

            Uri? artUri = _createArtUri(albumArtPath);

            _currentMediaItem = MediaItem(
              id: _currentMediaItem?.id ??
                  DateTime.now().millisecondsSinceEpoch.toString(),
              album: newArtist,
              title: newTitle,
              artUri: artUri,
            );

            notifyListeners();
            return;
          }
        }
      }

      // New song initialization
      debugPrint("New audio source detected. Initializing playback.");
      isChangingSong = true;
      position = Duration.zero;
      sliderPosition = Duration.zero;

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

  Future<bool> checkSongLikeStatus(String title, String artist) async {
    return await _storageService.isSongLiked(title, artist);
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
