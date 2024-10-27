import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'package:rxdart/rxdart.dart';

class AudioPlayerHandler extends BaseAudioHandler {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // BehaviorSubject to track the current media item
  final BehaviorSubject<MediaItem?> mediaItemSubject =
      BehaviorSubject<MediaItem?>();

  AudioPlayerHandler() {
    _initialize();
  }

  Future<void> _initialize() async {
    // Set up the media item stream and player state listener
    mediaItem.addStream(mediaItemSubject.stream);

    _audioPlayer.playerStateStream.listen((state) {
      final playing = state.playing;
      final processingState = state.processingState;

      playbackState.add(
        playbackState.value.copyWith(
          playing: playing,
          processingState: _mapProcessingState(processingState),
          controls: [
            MediaControl.pause,
            MediaControl.stop,
          ],
        ),
      );
    });
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      default:
        return AudioProcessingState.idle;
    }
  }

  @override
  Future<void> play() async {
    print("Attempting to play audio.");
    // Check if a media item is available before playing
    if (_audioPlayer.playing) {
      return; // Avoid calling play if already playing
    }
    await _audioPlayer.play();
  }

  @override
  Future<void> pause() => _audioPlayer.pause();

  @override
  Future<void> stop() => _audioPlayer.stop();

  @override
  Future<void> seek(Duration position) => _audioPlayer.seek(position);

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    mediaItemSubject.add(mediaItem); // Update media item
    await _audioPlayer.setUrl(mediaItem.extras!['url']);
  }

  @override
  Future<void> onTaskRemoved() async {
    await _audioPlayer.stop();
    await super.onTaskRemoved();
  }

  // Expose the AudioPlayer for external access
  AudioPlayer get audioPlayer => _audioPlayer;

  // Clean up resources without overriding
  void dispose() {
    _audioPlayer.dispose();
    mediaItemSubject.close(); // Close mediaItemSubject on disposal
    // Do not call super.dispose() since BaseAudioHandler doesn't have it
  }
}
