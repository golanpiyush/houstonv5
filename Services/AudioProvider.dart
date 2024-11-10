import 'package:flutter/material.dart';
import 'package:houstonv8/Services/PaletteGeneratorService.dart';
import 'package:houstonv8/Services/StorageService.dart';
import 'package:houstonv8/Services/musicApiService.dart';
import 'package:just_audio/just_audio.dart';
import 'SongDetails.dart';
import 'dart:async';

import 'package:just_audio_background/just_audio_background.dart';

// Class to store a collection of related songs
class RelatedSongs {
  final List<SongDetails> songs;
  RelatedSongs(this.songs);

  List<String> getSongTitles() {
    return songs.map((song) => song.title).toList();
  }

  List<SongDetails> getAllSongs() {
    return songs;
  }

  SongDetails? getNextSong(int currentIndex) {
    if (currentIndex < songs.length) {
      return songs[currentIndex];
    }
    return null;
  }

  void reset() {}
}

class AudioProvider with ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final StorageService _storageService = StorageService();
  final PaletteGeneratorService _paletteService = PaletteGeneratorService();
  Color _vibrantColor = Colors.grey; // Default color
  Timer? _colorLoadingTimer;

  static const String _baseUrl =
      'https://hhlxm0tg-5000.inc1.devtunnels.ms/'; // Define your base URL as a constant
  final MusicApiService _musicApiService;

  bool isPlaying = false;
  bool isMiniPlayer = false;
  bool _isPlayerScreenVisible = false;
  bool _isLooping = false;
  bool _isLoadingRelatedSongs = false;
  bool get isLoadingRelatedSongs => _isLoadingRelatedSongs;

  bool get isPlayerScreenVisible => _isPlayerScreenVisible;
  bool get isLooping => _isLooping;

  StreamSubscription<Duration>? _positionSubscription;
  Color get vibrantColor => _vibrantColor;

  // Track related songs
  List<SongDetails>? _relatedSongsQueue; // List for related songs
  int _currentRelatedSongIndex = 0; // Pointer for currently playing song
  int _songsPlayedOrSkipped = 0; // Counter for songs played or skipped

  // Constructor to initialize MusicApiService without parameters
  AudioProvider() : _musicApiService = MusicApiService(baseUrl: _baseUrl) {
    _audioPlayer.playingStream.listen((isPlaying) {
      this.isPlaying = isPlaying;
      notifyListeners();
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        markSongAsPlayedOrSkipped(); // Handle completion
        nextSong(); // Automatically go to the next song
      }
    });
  }
  // Current song details
  String? currentAudioUrl;
  String? currentSongTitle;
  String? currentArtist;
  String? currentAlbumArtUrl;
  String? currentPlayingSongKey;

  //previous song details
  String? previousSongTitle;
  String? previousArtist;
  String? previousAudioUrl;

  //init duration (ie: 00)
  Duration position = Duration.zero;

  //duration getter
  Duration? get duration => _audioPlayer.duration;

  void setCurrentSongDetails(SongDetails songDetails) {
    currentSongTitle = songDetails.title;
    currentArtist = songDetails.artists;
    currentAlbumArtUrl = songDetails.albumArt;
    currentAudioUrl = songDetails.audioUrl;
    currentPlayingSongKey = "${songDetails.artists}-${songDetails.title}";
    notifyListeners();
  }

  void setAlbumArt(String? url) {
    currentAlbumArtUrl = url; // Updates the album art URL
    notifyListeners(); // Notify listeners so the UI updates
  }

  void setPlayerScreenVisible(bool isVisible) {
    _isPlayerScreenVisible = isVisible;
    notifyListeners();
  }

  void _initializePositionListener() {
    _positionSubscription = _audioPlayer.positionStream.listen((newPosition) {
      position = newPosition;
      notifyListeners();
    });
  }

  void seekTo(Duration position) {
    _audioPlayer.seek(position);
  }

  MediaItem? _currentMediaItem;

  // Mark the current song as played or skipped
  void markSongAsPlayedOrSkipped() {
    _songsPlayedOrSkipped++;
    if (_songsPlayedOrSkipped >= 5) {
      resetRelatedSongs(); // Reset after 5 songs
    }
  }

  // Helper method to clear the queue
  void clearRelatedSongs() {
    _relatedSongsQueue = [];
  }

  // Reset related songs
  void resetRelatedSongs() {
    print('reset-called');
    _currentRelatedSongIndex = 0; // Reset index
    _songsPlayedOrSkipped = 0; // Reset counter
    clearRelatedSongs(); // Clear the queue in the service
  }

  Future<void> fetchAndCacheRelatedSongs(
      String songName, String artistName) async {
    if (songName.isEmpty || artistName.isEmpty) {
      debugPrint(
          "Cannot fetch related songs: song name or artist name is empty");
      return;
    }

    // Truncate any text within parentheses or square brackets for both song name and artist name
    songName = truncateExtraText(songName);
    artistName = truncateExtraText(artistName);
    debugPrint("Truncated song name: $songName");
    debugPrint("Truncated artist name: $artistName");

    // Clear the cache of related songs before fetching new ones
    resetRelatedSongs();

    _isLoadingRelatedSongs = true;
    notifyListeners();

    try {
      debugPrint("Fetching related songs for: $songName by $artistName");

      // Fetch the related songs with both song name and artist name
      List<SongDetails> fetchedSongs =
          await _musicApiService.fetchRelatedSongs(songName, artistName);

      // Handle fetched songs
      if (fetchedSongs.isEmpty) {
        debugPrint("No related songs found for $songName by $artistName.");
      } else {
        _relatedSongsQueue = fetchedSongs;
        debugPrint("Successfully cached ${fetchedSongs.length} related songs.");
      }

      _currentRelatedSongIndex = 0;
      _songsPlayedOrSkipped = 0;
    } catch (e) {
      debugPrint("Error caching related songs: $e");
      _relatedSongsQueue = null;
    } finally {
      _isLoadingRelatedSongs = false;
      notifyListeners();
    }
  }

  Future<void> previousSong() async {
    // Check if the current audio URL is an online URL
    bool isNetworkAudio = (currentAudioUrl != null &&
        (currentAudioUrl!.startsWith('http://') ||
            currentAudioUrl!.startsWith('https://')));

    // If the current song is an online song, skip retrieving liked songs
    if (isNetworkAudio) {
      debugPrint(
          "Current song is online. Cannot skip to previous liked songs.");
      return; // Exit without changing to liked songs
    }

    // If current song is local, proceed to retrieve liked songs
    final likedSongs = await _storageService.getLikedSongs();

    if (likedSongs.isEmpty) {
      debugPrint("No liked songs available.");
      return; // Exit if there are no liked songs
    }

    // Find the index of the currently playing song in liked songs
    int currentIndex = likedSongs.indexWhere((song) =>
        song['title'] == currentSongTitle && song['artist'] == currentArtist);

    if (currentIndex == -1) {
      debugPrint(
          "Current song not found in liked songs, starting from the last.");
      currentIndex =
          0; // Start from the first liked song if the current is not found
    } else {
      debugPrint("Current index found: $currentIndex");
    }

    // Calculate the previous index
    int previousIndex =
        (currentIndex - 1 + likedSongs.length) % likedSongs.length;

    Map<String, String> previousSongDetails = likedSongs[previousIndex];

    debugPrint(
        "Playing previous song: ${previousSongDetails['title']} by ${previousSongDetails['artist']}");

    // Update current song details
    currentSongTitle = previousSongDetails['title'];
    currentArtist = previousSongDetails['artist'];
    currentAlbumArtUrl = previousSongDetails['albumArtPath'];

    // Play the previous liked song
    await playSong(
      previousSongDetails['audioPath']!,
      previousSongDetails['albumArtPath']!,
    );
  }

  Future<void> nextSong() async {
    bool isNetworkAudio = (currentAudioUrl != null &&
        (currentAudioUrl!.startsWith('http://') ||
            currentAudioUrl!.startsWith('https://')));

    if (isNetworkAudio) {
      debugPrint("Current song is online. Handling related songs.");

      // Check if there are related songs to play
      if (_relatedSongsQueue != null && _relatedSongsQueue!.isNotEmpty) {
        if (_currentRelatedSongIndex >= _relatedSongsQueue!.length) {
          _currentRelatedSongIndex =
              0; // Reset index if end of queue is reached
        }

        SongDetails nextRelatedSong =
            _relatedSongsQueue![_currentRelatedSongIndex];
        _currentRelatedSongIndex++;

        debugPrint(
            "Playing next related song: ${nextRelatedSong.title} by ${nextRelatedSong.artists}");

        // Play the next related song
        await playSong(
          nextRelatedSong.audioUrl,
          nextRelatedSong.albumArt,
          title: nextRelatedSong.title,
          artist: nextRelatedSong.artists,
        );

        // Update the current song information to update the UI
        currentSongTitle = nextRelatedSong.title;
        currentArtist = nextRelatedSong.artists;
        currentAlbumArtUrl = nextRelatedSong.albumArt;

        // Update UI with the new song details
        _updateCurrentSongUI(); // Ensure this function triggers a UI update
      } else {
        debugPrint("No related songs available, fetching new ones...");
        await fetchAndCacheRelatedSongs(currentSongTitle ?? "Unknown Song",
            currentArtist ?? "Unknown Artist");
      }
      return;
    }

    // Handle liked songs if the current song is not from the network
    final likedSongs = await _storageService.getLikedSongs();
    if (likedSongs.isEmpty) {
      debugPrint("No liked songs available.");
      return; // Exit if no liked songs are available
    }

    int currentIndex = likedSongs.indexWhere((song) =>
        song['title'] == currentSongTitle && song['artist'] == currentArtist);

    if (currentIndex == -1) {
      debugPrint(
          "Current song not found in liked songs, starting from the first.");
      currentIndex = 0; // Start from the first liked song if not found
    }

    // Get the next liked song and update the UI
    int nextIndex = (currentIndex + 1) % likedSongs.length;
    Map<String, String> nextSongDetails = likedSongs[nextIndex];

    debugPrint(
        "Playing next liked song: ${nextSongDetails['title']} by ${nextSongDetails['artist']}");

    currentSongTitle = nextSongDetails['title'];
    currentArtist = nextSongDetails['artist'];
    currentAlbumArtUrl = nextSongDetails['albumArtPath'];

    await playSong(
        nextSongDetails['audioPath']!, nextSongDetails['albumArtPath']!);

    // Update the UI with the new liked song details
    _updateCurrentSongUI();
  }

  void _updateCurrentSongUI() {
    notifyListeners();
  }

  // Private method to load the vibrant color with a delay
  void _loadVibrantColor(String imageUrl) {
    if (imageUrl.isEmpty) return;

    // Cancel any previous color loading timer to avoid overlap
    _colorLoadingTimer?.cancel();

    // Set a timer to delay color loading
    _colorLoadingTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final color = await _paletteService.getVibrantColor(imageUrl);
        _vibrantColor = color;
        notifyListeners(); // Notify listeners to update UI
      } catch (e) {
        debugPrint('Error generating palette: $e');
        _vibrantColor = Colors.blue; // Fallback color
        notifyListeners();
      }
    });
  }

  Future<void> playSong(String audioUrl, String albumArtPath,
      {String? title, String? artist}) async {
    try {
      debugPrint("Attempting to play song: $audioUrl");

      String newTitle = title ?? currentSongTitle ?? "Unknown Title";
      String newArtist = artist ?? currentArtist ?? "Unknown Artist";
      // Update vibrant color based on new album art path
      if (albumArtPath.isNotEmpty) {
        _loadVibrantColor(albumArtPath); // Call to load the vibrant color
      }

      // Check if we're at the third song in the related songs queue
      if (_relatedSongsQueue != null && _relatedSongsQueue!.length >= 3) {
        int currentIndex = _relatedSongsQueue!.indexWhere(
            (song) => song.title == newTitle && song.artists == newArtist);

        if (currentIndex == 2) {
          debugPrint(
              "Playing the third song in the queue, fetching new related songs...");
          _relatedSongsQueue =
              await _musicApiService.fetchRelatedSongs(newTitle, newArtist);
          notifyListeners();
        }
      }

      // Update vibrant color based on new album art path
      if (albumArtPath.isNotEmpty) {
        _vibrantColor = await _paletteService.getVibrantColor(albumArtPath);
        notifyListeners(); // Notify listeners to refresh the UI
      }

      // Set up artUri
      Uri? artUri;
      if (albumArtPath.isNotEmpty) {
        if (albumArtPath.startsWith('http://') ||
            albumArtPath.startsWith('https://') ||
            albumArtPath.startsWith('file://')) {
          artUri = Uri.parse(albumArtPath);
        } else {
          artUri = Uri.file(albumArtPath);
        }
        notifyListeners();
      }

      if (artUri == null || !artUri.hasScheme) {
        debugPrint("Invalid artUri: $albumArtPath, setting artUri to null.");
        artUri = null;
      }

      // Create new MediaItem for playback
      _currentMediaItem = MediaItem(
        id: '1',
        album: newArtist,
        title: newTitle,
        artUri: artUri,
      );

      // Set the audio source
      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(audioUrl),
          tag: _currentMediaItem,
        ),
      );

      // Start playback
      await _audioPlayer.play();
      isPlaying = true;
      notifyListeners();
      _initializePositionListener();

      // Update UI with the current song details
      _updateCurrentSongUI();
    } catch (e) {
      debugPrint("Error playing audio: $e");
    }
  }

  void setLoopMode(bool shouldLoop) {
    _isLooping = shouldLoop;
    _audioPlayer.setLoopMode(shouldLoop ? LoopMode.one : LoopMode.off);
    notifyListeners(); // Notify listeners to update the UI if needed
  }

  Future<void> togglePlayPause() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
      isPlaying = false;
    } else {
      await _audioPlayer.play();
      isPlaying = true;
    }
    notifyListeners();
  }

  // Add this method in your AudioProvider class to show Snackbar
  void showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  //stores prevoius song details
  void updatePreviousSongDetails(
      String? title, String? artist, String? audioUrl) {
    previousSongTitle = title;
    previousArtist = artist;
    previousAudioUrl = audioUrl;
  }

  // Function to truncate text within parentheses and square brackets
  String truncateExtraText(String title) {
    // Remove content between () and [] (including the brackets themselves)
    final RegExp regex = RegExp(r'[\(\[].*?[\)\]]');
    return title.replaceAll(regex, '').trim();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
