// import 'package:audio_service/audio_service.dart';
// import 'package:just_audio/just_audio.dart';
// import 'SongDetails.dart'; // Ensure this import is correct based on your file structure

// class AudioPlayerHandler extends BaseAudioHandler {
//   final AudioPlayer _audioPlayer = AudioPlayer();
//   bool isPlaying = false;

//   // Method to set song details
//   Future<void> setSong(SongDetails songDetails) async {
//     await _audioPlayer.setUrl(songDetails.audioUrl);
//     await play(); // Start playing the song immediately upon setting
//   }

//   @override
//   Future<void> play() async {
//     await _audioPlayer.play();
//     isPlaying = true;
//     // Update the playback state
//     playbackState.add(CustomPlaybackState(
//       playing: isPlaying,
//       controls: [MediaControl.pause],
//       currentPosition: _audioPlayer.position, // Set current position
//     ));
//   }

//   @override
//   Future<void> pause() async {
//     await _audioPlayer.pause();
//     isPlaying = false;
//     // Update the playback state
//     playbackState.add(CustomPlaybackState(
//       playing: isPlaying,
//       controls: [MediaControl.play],
//       currentPosition: _audioPlayer.position, // Set current position
//     ));
//   }

//   @override
//   Future<void> stop() async {
//     await _audioPlayer.stop();
//     isPlaying = false;
//     // Update the playback state
//     playbackState.add(CustomPlaybackState(
//       playing: isPlaying,
//       controls: [],
//       currentPosition: Duration.zero, // Reset position
//     ));
//   }

//   @override
//   Future<void> seek(Duration position) async {
//     await _audioPlayer.seek(position);
//     playbackState.add(CustomPlaybackState(
//       playing: isPlaying,
//       controls: isPlaying ? [MediaControl.pause] : [MediaControl.play],
//       currentPosition: position, // Set the current position
//     ));
//   }

//   @override
//   Future<void> onTaskRemoved() async {
//     await _audioPlayer.dispose(); // Dispose of the audio player when the task is removed
//     super.onTaskRemoved(); // Call the super implementation
//   }

//   // Listen for player state updates
//   void init() {
//     _audioPlayer.playingStream.listen((isPlaying) {
//       this.isPlaying = isPlaying;
//       playbackState.add(CustomPlaybackState(
//         playing: isPlaying,
//         controls: isPlaying ? [MediaControl.pause] : [MediaControl.play],
//         currentPosition: _audioPlayer.position, // Update position
//       ));
//     });

//     // Update duration and position changes
//     _audioPlayer.positionStream.listen((position) {
//       playbackState.add(CustomPlaybackState(
//         playing: isPlaying,
//         controls: isPlaying ? [MediaControl.pause] : [MediaControl.play],
//         currentPosition: position, // Update position
//       ));
//     });

//     // Listen for duration updates
//     _audioPlayer.durationStream.listen((duration) {
//       // Handle duration updates if necessary
//     });
//   }
// }
