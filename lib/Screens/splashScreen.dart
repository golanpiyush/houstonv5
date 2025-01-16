import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'loginScreen.dart';
import 'searchScreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _hasError = false;
  bool _isButtonLoading = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _setupVideo();
  }

  Future<void> _setupVideo() async {
    try {
      _videoController = VideoPlayerController.asset(
        'assets/videos/my_video_9.mp4',
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      _videoController?.addListener(_videoListener);

      await _videoController?.initialize().then((_) async {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });

          await _videoController?.seekTo(Duration.zero);
          await _videoController?.play();
          _startNavigationTimer();
        }
      }).catchError((error) {
        debugPrint('Video initialization error: $error');
        _handleVideoError();
      });
    } catch (e) {
      debugPrint('Video setup error: $e');
      _handleVideoError();
    }
  }

  void _videoListener() {
    if (!mounted) return;

    if (_videoController?.value.hasError ?? false) {
      debugPrint('Video error: ${_videoController?.value.errorDescription}');
      _handleVideoError();
    }
  }

  void _handleVideoError() {
    if (!mounted) return;
    setState(() {
      _hasError = true;
    });
    _startNavigationTimer(duration: const Duration(milliseconds: 500));
  }

  void _startNavigationTimer({Duration? duration}) {
    Future.delayed(duration ?? const Duration(seconds: 9), () {
      if (mounted) {
        _navigateBasedOnLoginStatus();
      }
    });
  }

  Future<void> _navigateBasedOnLoginStatus() async {
    if (!mounted) return;

    try {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );

      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');

      if (!mounted) return;

      // Dispose of video controller before navigation
      await _videoController?.pause();
      await _videoController?.dispose();
      _videoController = null;

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => username != null && username.isNotEmpty
              ? const SongSearchScreen()
              : const LoginScreen(),
        ),
      );
    } catch (e) {
      debugPrint('Navigation error: $e');
      // Fallback navigation
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _skipIntro() {
    setState(() {
      _isButtonLoading = true;
    });

    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isButtonLoading = false;
      });
      _navigateBasedOnLoginStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Video
              _hasError || !_isVideoInitialized
                  ? Container(color: Colors.black)
                  : Positioned.fill(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoController?.value.size.width ??
                              double.infinity,
                          height: _videoController?.value.size.height ??
                              double.infinity,
                          child: _videoController != null
                              ? VideoPlayer(_videoController!)
                              : Container(color: Colors.black),
                        ),
                      ),
                    ),

              // Loading Indicator
              if (!_isVideoInitialized && !_hasError)
                const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),

              // Skip Intro Button
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.amber,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: const BorderSide(color: Colors.amber, width: 2),
                      ),
                    ),
                    onPressed: _skipIntro,
                    child: _isButtonLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.amber,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'Skip Intro',
                            style: TextStyle(
                              fontFamily: 'Jost',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
