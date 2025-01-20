import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:houstonv8/Services/settings.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Services/StorageService.dart';
import 'Services/AudioProvider.dart';
import 'Screens/splashScreen.dart';
import 'Screens/loginScreen.dart';
import 'Screens/searchScreen.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize audio background service
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.audio.channel',
    androidNotificationChannelName: 'Audio Playback',
    androidNotificationOngoing: true,
  );

  // Initialize Awesome Notifications
  await AwesomeNotifications().initialize(
    'resource://drawable/ic_launcher',
    [
      NotificationChannel(
        channelKey: 'basic_channel',
        channelName: 'Basic notifications',
        channelDescription: 'Notification channel for basic notifications',
        defaultColor: const Color(0xFF9D50DD),
        ledColor: Colors.white,
        importance: NotificationImportance.High,
        playSound: true,
        enableVibration: true,
      ),
    ],
  );

  // Request notification permissions
  await AwesomeNotifications().isNotificationAllowed().then((isAllowed) async {
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  });

  // Initialize settings
  final settings = Settings();
  await settings.loadThemePreference();

  // Run the app with providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => StorageService(),
        ),
        ChangeNotifierProvider(
          create: (_) => AudioProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => settings,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _getInitialScreen() async {
    try {
      await Future.delayed(const Duration(seconds: 9));

      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');

      if (username != null && username.isNotEmpty) {
        return const SongSearchScreen();
      } else {
        return const LoginScreen();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error determining initial screen: $e');
      }
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Settings>(
      builder: (context, settings, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Houston',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            bannerTheme: const MaterialBannerThemeData(
              elevation: 8,
            ),
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return Consumer<StorageService>(
              builder: (context, storageService, _) {
                if (kDebugMode) {
                  debugPrint(
                      'Main.dart - StorageService isDownloading: ${storageService.isDownloading}');
                }
                return child!;
              },
            );
          },
          home: FutureBuilder<Widget>(
            future: _getInitialScreen(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              } else if (snapshot.hasError) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                return snapshot.data!;
              }
            },
          ),
        );
      },
    );
  }
}
