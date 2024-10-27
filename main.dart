import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'Services/AudioProvider.dart';
import 'screens/searchScreen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioProvider()),
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
      home: const SongSearchScreen(),
    );
    // bottomNavigationBar: MiniPlayer(),
  }
}
