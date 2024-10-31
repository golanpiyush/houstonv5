import 'package:flutter/material.dart';
import 'package:houstonv8/Services/StorageService.dart';
import 'package:provider/provider.dart';
import 'Services/AudioProvider.dart';
import 'screens/searchScreen.dart';
import '../Services/downloadProgress.dart'; // Make sure this import is correct
import 'package:just_audio_background/just_audio_background.dart';
import '../Screens/miniplayer.dart'; // Import your mini player widget
// Import your player screen

Future<void> main() async {
  // Ensure that all bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize JustAudioBackground for background audio playback
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.houstonv8.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProvider(create: (_) => StorageService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Streaming App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar included
      body: Consumer<StorageService>(
        builder: (context, storageService, child) {
          print(
              'Rebuilding MainScreen, isDownloading: ${storageService.isDownloading}');
          return Stack(
            children: [
              const SongSearchScreen(),
              DownloadProgressWidget(
                  progressStream:
                      storageService.progressStream), // Pass the stream here
              // Add the mini player here
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Consumer<AudioProvider>(
                  // Consumer to listen to audio state
                  builder: (context, audioProvider, child) {
                    // Check if we are on the player screen
                    final isPlayerScreen = audioProvider.isPlayerScreenVisible;
                    return Visibility(
                      visible: !isPlayerScreen,
                      child: MiniPlayer(), // Your MiniPlayer widget
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
