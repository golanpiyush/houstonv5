import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart'; // Import Lottie package
import '../../Services/musicApiService.dart';
import 'playerScreen.dart';
import 'likedSongs.dart'; // Import the LikedSongsScreen

class SongSearchScreen extends StatefulWidget {
  const SongSearchScreen({super.key});

  @override
  _SongSearchScreenState createState() => _SongSearchScreenState();
}

class _SongSearchScreenState extends State<SongSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final MusicApiService _musicApiService =
      MusicApiService(baseUrl: 'https://hhlxm0tg-5000.inc1.devtunnels.ms/');
  bool _isLoading = false;
  Timer? _debounce;

  String greetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning, Piyush';
    } else if (hour < 17) {
      return 'Good Afternoon, Piyush';
    } else if (hour < 20) {
      return 'Good Evening, Piyush';
    } else {
      return 'Good Night, Piyush';
    }
  }

  Future<void> _searchSong() async {
    FocusScope.of(context).unfocus();
    String songName = _controller.text.trim();
    if (songName.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final songDetails = await _musicApiService.fetchSongDetails(songName);
      if (songDetails != null &&
          songDetails.title.isNotEmpty &&
          songDetails.audioUrl.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen(
              songDetails: songDetails,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('No results found or song details are incomplete.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching song details: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchPressed() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchSong();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background image layer
        Positioned.fill(
          child: Image.asset(
            'assets/images/bg.jpg', // Replace with the path to your image
            fit: BoxFit.cover,
          ),
        ),
        // Lottie animation layer
        Positioned(
          left:
              -50, // Shift to the left by 20 pixels (adjust this value as needed)
          top: 0,
          right:
              20, // Optional: add some space on the right if needed for centering
          bottom: 0,
          child: Lottie.asset(
            'assets/images/Animations/dog_animation.json',
            fit: BoxFit.cover,
            repeat: true,
          ),
        ),

        // Transparent scaffold overlay for app content
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              greetingMessage(),
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 20,
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 3,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(Icons.favorite, color: Colors.red),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LikedSongsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Enter song name',
                      hintStyle: TextStyle(color: Colors.black54),
                      suffixIcon: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color.fromARGB(255, 255, 0, 0)),
                              ),
                            )
                          : IconButton(
                              icon: Icon(Icons.search),
                              onPressed: _isLoading ? null : _onSearchPressed,
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.4),
                    ),
                    onSubmitted: (_) => _onSearchPressed(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }
}
