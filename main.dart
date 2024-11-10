import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'Services/MusicApiService.dart';
import 'Services/StorageService.dart';
import 'Services/AudioProvider.dart';
import 'Screens/splashScreen.dart';
import 'Screens/likedSongs.dart';
import 'Screens/miniplayer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      title: 'Houston',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late Future<bool> _serverHealthCheck;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _serverHealthCheck = _checkServerHealth();
  }

  Future<bool> _checkServerHealth() async {
    try {
      final musicApiService =
          MusicApiService(baseUrl: 'https://hhlxm0tg-5000.inc1.devtunnels.ms');
      return await musicApiService.checkHealth();
    } catch (e) {
      debugPrint('Server health check error: $e');
      return false;
    }
  }

  Widget _buildErrorScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 80),
          const SizedBox(height: 10),
          const Text(
            'Server is unreachable. Please check your connection or try again later.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _serverHealthCheck = _checkServerHealth();
              });
            },
            child: const Text('Retry'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LikedSongsScreen(),
                ),
              );
            },
            child: const Text('Liked Songs'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Consumer<StorageService>(
      builder: (context, storageService, child) {
        return Stack(
          children: [
            const SplashScreen(),
            // ValueListenableBuilder<double>(
            //   valueListenable: storageService.progressNotifier,
            //   builder: (context, progress, child) {
            //     return DownloadProgressWidget(progress: progress);
            //   },
            // ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Consumer<AudioProvider>(
                builder: (context, audioProvider, child) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: !audioProvider.isPlayerScreenVisible
                        ? const MiniPlayer()
                        : const SizedBox.shrink(),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Houston'),
      ),
      body: SafeArea(
        child: FutureBuilder<bool>(
          future: _serverHealthCheck,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError || !(snapshot.data ?? false)) {
              return _buildErrorScreen();
            } else {
              return _buildMainContent();
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Add any cleanup here if needed
    super.dispose();
  }
}
