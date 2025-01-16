import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

/// A service to handle gapless playback with manual crossfade for local audio files.
class GaplessLocalService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  late ConcatenatingAudioSource _playlist;
  Timer? _crossfadeTimer;

  GaplessLocalService();

  /// Initialize the service with a list of liked songs and optional crossfade duration.
  Future<void> initialize(List<Map<String, String>> likedSongs,
      {Duration? crossfadeDuration}) async {
    final audioSources = likedSongs.map((song) {
      // Wrap each AudioSource with MediaItem
      return AudioSource.uri(
        Uri.file(song['audioPath']!), // Ensure audioPath is not null
        tag: MediaItem(
          id: song['audioPath']!,
          album: song['title'] ?? 'Unknown Album', // Default if title is null
          title: song['title'] ?? 'Unknown Title', // Default if title is null
          artist:
              song['artist'] ?? 'Unknown Artist', // Default if artist is null
          artUri: song['albumArtPath'] != null
              ? Uri.file(song['albumArtPath']!)
              : Uri.parse(''), // Handle null albumArtPath
        ),
      );
    }).toList();

    _playlist = ConcatenatingAudioSource(children: audioSources);
    await _audioPlayer.setAudioSource(_playlist, preload: true);

    // Enable crossfade if duration is provided
    if (crossfadeDuration != null) {
      _enableCrossfade(crossfadeDuration);
    }
  }

  /// Enable crossfade transitions between tracks.
  void _enableCrossfade(Duration crossfadeDuration) {
    _audioPlayer.positionStream.listen((position) async {
      final currentIndex = _audioPlayer.currentIndex;
      final duration = _audioPlayer.duration;

      if (currentIndex != null && duration != null) {
        final timeRemaining = duration - position;

        if (timeRemaining <= crossfadeDuration &&
            timeRemaining > Duration.zero) {
          _crossfadeTimer ??= Timer(timeRemaining, () async {
            final nextIndex = currentIndex + 1;

            // Fade out the current track manually
            await _fadeOut(crossfadeDuration);

            // Switch to the next track and fade in
            if (nextIndex < _playlist.children.length) {
              await _audioPlayer.seek(Duration.zero, index: nextIndex);
              await _fadeIn(crossfadeDuration);
            }

            // Reset the timer
            _crossfadeTimer?.cancel();
            _crossfadeTimer = null;
          });
        }
      }
    });
  }

  /// Gradually fades out the volume.
  Future<void> _fadeOut(Duration duration) async {
    const int steps = 10;
    final stepDuration = duration.inMilliseconds ~/ steps;

    for (int i = steps; i > 0; i--) {
      if (_audioPlayer.playing) {
        _audioPlayer.setVolume(i / steps); // Fade out the volume
      }
      await Future.delayed(Duration(milliseconds: stepDuration));
    }
  }

  /// Gradually fades in the volume.
  Future<void> _fadeIn(Duration duration) async {
    const int steps = 10;
    final stepDuration = duration.inMilliseconds ~/ steps;

    for (int i = 1; i <= steps; i++) {
      if (_audioPlayer.playing) {
        _audioPlayer.setVolume(i / steps); // Fade in the volume
      }
      await Future.delayed(Duration(milliseconds: stepDuration));
    }
  }

  /// Play the next song with crossfade.
  Future<void> playNextSongWithCrossfade({
    Duration? crossfadeDuration,
    String? title,
    String? artist,
  }) async {
    final currentIndex = _audioPlayer.currentIndex;
    if (currentIndex == null) return;

    final nextIndex = currentIndex + 1;

    if (nextIndex < _playlist.children.length) {
      // Start fading out the current song
      await _fadeOut(crossfadeDuration ?? const Duration(seconds: 3));

      // Seek to the next song and start fading it in
      await _audioPlayer.seek(Duration.zero, index: nextIndex);
      await _fadeIn(crossfadeDuration ?? const Duration(seconds: 3));

      // Optionally display metadata
      if (title != null && artist != null) {
        print('Now Playing: $title - $artist');
      }
    }
  }

  /// Seek to a specific song by index in the playlist.
  Future<void> seekToSong(int index) async {
    await _audioPlayer.seek(Duration.zero, index: index);
  }

  /// Dispose of the player when no longer needed.
  void dispose() {
    _crossfadeTimer?.cancel();
    _audioPlayer.dispose();
  }

  /// Expose the AudioPlayer for external access (e.g., listening to state changes).
  AudioPlayer get audioPlayer => _audioPlayer;
}
