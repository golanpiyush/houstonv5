import 'package:flutter/material.dart';
import 'package:houstonv8/Services/StorageService.dart';
import 'package:provider/provider.dart';
import 'Services/AudioProvider.dart';
import 'screens/searchScreen.dart';
import '../Services/downloadProgress.dart'; // Make sure this import is correct
import 'package:just_audio_background/just_audio_background.dart';

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
        ChangeNotifierProvider(
            create: (_) => StorageService()), // Add this line
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
    final storageService =
        Provider.of<StorageService>(context); // Listen to StorageService

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Streaming App'),
      ),
      body: Stack(
        children: [
          const SongSearchScreen(), // Main content

          // Add the DownloadProgressBar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0, // Position at the bottom of the screen
            child: DownloadProgressBar(
              progress: storageService.downloadProgress,
              isDownloading: storageService.isDownloading,
            ),
          ),
        ],
      ),
    );
  }
}
