import 'dart:async';
import 'dart:io';
import 'package:auto_size_text/auto_size_text.dart';
import 'dart:math';
import 'package:lottie/lottie.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:houstonv8/Screens/UI/settings_screen.dart';
import 'package:houstonv8/Screens/playerScreen.dart';
import 'package:houstonv8/Services/AudioProvider.dart';
import 'package:houstonv8/Services/SongDetails.dart';
import 'package:houstonv8/Services/StorageService.dart';
import 'package:houstonv8/Services/settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Services/musicApiService.dart';
import '../Screens/UI/photo_upload_dialog.dart';
import 'package:houstonv8/Services/Managers/playlistManager.dart';
import 'package:houstonv8/Screens/playlistTab.dart';

class SongSearchScreen extends StatefulWidget {
  const SongSearchScreen({super.key});

  @override
  _SongSearchScreenState createState() => _SongSearchScreenState();
}

class _SongSearchScreenState extends State<SongSearchScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late AnimationController _controller;
  bool isMiniplayerActive = true;
  String? selectedGender;

  File? _profileImage;

  final MusicApiService _musicApiService = MusicApiService(
    baseUrl: 'https://hhlxm0tg-5000.inc1.devtunnels.ms/',
  );
  final TextEditingController _searchController = TextEditingController();
  final PlaylistManager _playlistManager = PlaylistManager();
  final StorageService _storageService = StorageService();
  List<Map<String, String>> _likedSongs = [];
  bool _isLoading = true;

  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<File?> _profileImageNotifier = ValueNotifier<File?>(null);
  final ValueNotifier<List<String>> _playlistsNotifier =
      ValueNotifier<List<String>>([]);

  String _username = 'User!';
  bool _isRequestInProgress = false;
  bool _isHelloVisible = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..addListener(() {
        setState(() {});
      });
    _toggleGreeting();
    _getGender();
    _initializeData();
    _loadInitialProfileImage();
    _loadLikedSongs();

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isHelloVisible = false;
      });
      _controller.forward();
    });
  }

  Future<void> _initializeData() async {
    await _fetchUsername();
    await _fetchPlaylists();
  }

  Future<String?> _getGender() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('gender'); // Retrieve the stored gender
  }

  Future<void> _fetchUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'User!';
    });
  }

  Future<void> _fetchPlaylists() async {
    try {
      final playlists = await _playlistManager.getPlaylists();
      _playlistsNotifier.value = playlists;
    } catch (e) {
      debugPrint('Error fetching playlists: $e');
    }
  }

  void _showEnlargedImage(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black.withOpacity(0.7),
                  child: Center(
                    child: _profileImageNotifier.value != null
                        ? Image.file(_profileImageNotifier.value!)
                        : SvgPicture.asset(
                            'assets/images/avatars/niggis.svg',
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleGreeting() {
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isHelloVisible = false;
      });
    });
  }

  Future<void> _searchSong() async {
    if (_isRequestInProgress) return;

    FocusScope.of(context).unfocus();
    final songName = _searchController.text.trim();

    if (songName.isEmpty) return;

    _isRequestInProgress = true;
    _isLoadingNotifier.value = true;

    final audioProvider = Provider.of<AudioProvider>(context, listen: false);
    audioProvider.clearRelatedSongs();

    try {
      final songDetails =
          await _musicApiService.fetchSongDetails(songName, _username);

      if (songDetails != null &&
          songDetails.title.isNotEmpty &&
          songDetails.audioUrl.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayerScreen(
              songDetails: songDetails,
              isMiniplayer: false,
            ),
          ),
        );
      } else {
        _showErrorSnackBar('No results found or song details are incomplete.');
      }
    } catch (e) {
      _showErrorSnackBar('Error fetching song details: $e');
    } finally {
      _isLoadingNotifier.value = false;
      _isRequestInProgress = false;
    }
  }

  Future<void> _loadLikedSongs() async {
    try {
      final songs = await _storageService.getLikedSongs();
      if (mounted) {
        setState(() {
          _likedSongs = songs;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading liked songs: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unlikeSong(String title, String artist) async {
    try {
      await _storageService.unlikeSong(title, artist);
      await _loadLikedSongs();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unlike song: $e')),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadInitialProfileImage() async {
    final imagePath = await loadProfileImage();
    setState(() {
      _profileImage = imagePath != null ? File(imagePath) : null;
    });
  }

  void _showPhotoUploadDialog() {
    showDialog(
      context: context,
      builder: (context) => PhotoUploadDialog(
        onImageSelected: (imageFile) {
          setState(() {
            _profileImage = imageFile;
          });
        },
        onDeleteImage: () {
          setState(() {
            _profileImage = null;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _isLoadingNotifier.dispose();
    _profileImageNotifier.dispose();
    _playlistsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, child) {
        // SongDetails? songDetails = audioProvider.currentSong;
        // bool isMiniplayerActive = songDetails != null;

        // Determine text and background colors based on theme
        bool isBlackTheme = Settings().isBlackTheme;
        Color textColor = isBlackTheme ? Colors.white : Colors.black;
        Color backgroundColor = isBlackTheme ? Colors.black : Colors.white;

        return Scaffold(
          backgroundColor: backgroundColor, // Set the background color
          body: SafeArea(
            // Wrap the entire content in SafeArea
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserHeader(textColor),
                    _buildSearchField(textColor),
                    _buildTabBar(textColor),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildRecentlyPlayedTab(textColor),
                          _buildPopularTab(),
                          _buildLikedSongsTab(textColor),
                          const PlaylistTab(), // Ensure this returns a Widget
                        ],
                      ),
                    ),
                  ],
                ),
                // Uncomment this block for the miniplayer
                // if (isMiniplayerActive)
                //   Positioned(
                //     bottom: 0,
                //     left: 0,
                //     right: 0,
                //     child: GestureDetector(
                //       onTap: () {
                //         Navigator.push(
                //           context,
                //           MaterialPageRoute(
                //             builder: (context) => PlayerScreen(
                //               songDetails: songDetails!,
                //               isMiniplayer: false,
                //             ),
                //           ),
                //         );
                //       },
                //       child: PlayerScreen(
                //         songDetails: songDetails!,
                //         isMiniplayer: true,
                //       ),
                //     ),
                //   ),
              ],
            ),
          ),
        );
      },
    );
  }

// Helper Methods

  String _getGreeting() {
    final hour = DateTime.now().hour;

    // Define different variations for each part of the day
    Map<String, List<String>> greetings = {
      'early_morning': ['Good Early Morning', 'Rise and Shine, Early Bird'],
      'morning': [
        'Good Morning',
        'Morning Sunshine',
        'Rise and Shine',
        'Good Day'
      ],
      'late_morning': ['Good Late Morning', 'Almost Afternoon, huh?...'],
      'afternoon': [
        'Good Afternoon',
        'Hope you’re having a great afternoon',
        'Afternoon music huh!',
        'How’s your afternoon going?'
      ],
      'mid_afternoon': [
        'Mid-Afternoon music huh?...',
        'Hope your afternoon is going well'
      ],
      'evening': [
        'Good Evening',
        'Evening, buddy',
        'Hope your evening is awesome',
        'Good to see you this evening'
      ],
      'night': [
        'Good Night, if decide to sleep',
        'Sweet dreams, if decide to sleep',
        'Happy late night',
        'Have a restful night, if decide to sleep'
      ],
      'midnight': [
        'Good Midnight',
        'Hope you’re still awake!',
        'Late-night vibes',
        'It’s getting late, huh?...'
      ],
    };

    String greeting;

    // Determine the time of day and randomly pick a greeting
    if (hour >= 5 && hour < 7) {
      greeting = greetings['early_morning']![
          Random().nextInt(greetings['early_morning']!.length)];
    } else if (hour >= 7 && hour < 10) {
      greeting =
          greetings['morning']![Random().nextInt(greetings['morning']!.length)];
    } else if (hour >= 10 && hour < 12) {
      greeting = greetings['late_morning']![
          Random().nextInt(greetings['late_morning']!.length)];
    } else if (hour >= 12 && hour < 15) {
      greeting = greetings['afternoon']![
          Random().nextInt(greetings['afternoon']!.length)];
    } else if (hour >= 15 && hour < 17) {
      greeting = greetings['mid_afternoon']![
          Random().nextInt(greetings['mid_afternoon']!.length)];
    } else if (hour >= 17 && hour < 20) {
      greeting =
          greetings['evening']![Random().nextInt(greetings['evening']!.length)];
    } else if (hour >= 20 && hour < 22) {
      greeting =
          greetings['night']![Random().nextInt(greetings['night']!.length)];
    } else {
      greeting = greetings['midnight']![
          Random().nextInt(greetings['midnight']!.length)];
    }

    return greeting;
  }

  Widget _buildUserHeader(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildUserGreeting(textColor),
          _buildProfileAvatar(context),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPhotoUploadDialog(),
      child: CircleAvatar(
        radius: 25,
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        backgroundImage:
            _profileImage != null ? FileImage(_profileImage!) : null,
        child: _profileImage == null
            ? FutureBuilder<String?>(
                future: _getGender(), // Load gender from SharedPreferences
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  if (snapshot.hasData) {
                    String gender = snapshot.data ?? 'default';

                    // Load gender-based SVG
                    String svgPath = gender == 'male'
                        ? 'assets/images/avatars/niggas.svg'
                        : gender == 'female'
                            ? 'assets/images/avatars/niggis.svg'
                            : 'assets/images/avatars/niggis.svg';

                    return SvgPicture.asset(
                      svgPath,
                      fit: BoxFit.cover,
                      width: 50,
                      height: 50,
                    );
                  } else {
                    return SvgPicture.asset(
                      'assets/images/avatars/default.svg',
                      fit: BoxFit.cover,
                      width: 50,
                      height: 50,
                    );
                  }
                },
              )
            : null,
      ),
    );
  }

  Widget _buildUserGreeting(Color textColor) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: 70, // Increased from 50 to allow more space
        minHeight: 50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize:
            MainAxisSize.min, // Important: prevents expanding beyond content
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            layoutBuilder:
                (Widget? currentChild, List<Widget> previousChildren) {
              return Stack(
                alignment: Alignment.centerLeft,
                children: <Widget>[
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
            transitionBuilder: (Widget child, Animation<double> animation) {
              return SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0, 1), // Slide up from bottom
                        end: Offset.zero)
                    .animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: _isHelloVisible
                ? Text(
                    'Hello,',
                    key: const ValueKey('hello'),
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                    ),
                  )
                : Text(
                    _getGreeting(),
                    key: const ValueKey('greeting'),
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () {
              print('Navigating to settings...');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            child: Text(
              _username,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSearchField(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: IconButton(
            icon: Icon(Icons.search, color: textColor),
            onPressed: _searchSong,
          ),
          filled: true,
          fillColor: Settings().isBlackTheme
              ? Colors.grey.shade800
              : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
        ),
        style: TextStyle(color: textColor),
        onSubmitted: (_) => _searchSong(),
      ),
    );
  }

  Widget _buildTabBar(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color.fromARGB(255, 45, 251, 107),
        labelColor: Colors.greenAccent,
        unselectedLabelColor: textColor.withOpacity(0.6),
        isScrollable: true,
        tabs: [
          Tab(
            child: Center(
              child: Text(
                'Recently',
                style: TextStyle(
                  fontFamily: 'Jost',
                  fontWeight: FontWeight.w500,
                  fontSize: 16.0,
                  color: textColor,
                ),
              ),
            ),
          ),
          Tab(
            child: Center(
              child: Text(
                'Popular',
                style: TextStyle(
                  fontFamily: 'Jost',
                  fontWeight: FontWeight.w500,
                  fontSize: 16.0,
                  color: textColor,
                ),
              ),
            ),
          ),
          Tab(
            child: Center(
              child: Text(
                'Favourite',
                style: TextStyle(
                  fontFamily: 'Jost',
                  fontWeight: FontWeight.w500,
                  fontSize: 16.0,
                  color: textColor,
                ),
              ),
            ),
          ),
          Tab(
            child: Center(
              child: Text(
                'Playlists',
                style: TextStyle(
                  fontFamily: 'Jost',
                  fontWeight: FontWeight.w500,
                  fontSize: 16.0,
                  color: textColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentlyPlayedTab(Color textColor) {
    final songHistory = _musicApiService.songHistory;

    if (songHistory.isEmpty) {
      return Center(
        child: Text(
          'No recently played song found. Try Playing a song?',
          style: TextStyle(
            fontSize: 16,
            color: textColor,
            fontFamily: 'Montserrat',
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      itemBuilder: (context, index) {
        SongDetails song = songHistory[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
          leading: ClipRRect(
            borderRadius:
                BorderRadius.circular(8.0), // Adjust the radius as needed
            // ignore: unnecessary_null_comparison
            child: song.albumArt != null
                ? Image.network(
                    song.albumArt,
                    width: 57, // Set desired width
                    height: 57, // Set desired height
                    fit: BoxFit
                        .cover, // Ensures the image fits within the square
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.music_note,
                        size: 30, color: Colors.grey),
                  ),
          ),
          title: AutoSizeText(
            song.title,
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Jost',
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: AutoSizeText(
            song.artists,
            style: TextStyle(
              fontSize: 14,
              fontFamily: 'Jost',
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: AutoSizeText(
            'Expires in: ${song.timeLeft}', // Display the expiration time
            style: TextStyle(
              fontFamily: 'Jost',
              fontWeight: FontWeight.w100,
              fontSize: 12, // Adjust font size as needed
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis, // Truncates text if it overflows
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlayerScreen(
                  songDetails: song,
                  isMiniplayer: false,
                ),
              ),
            );
          },
        );
      },
      separatorBuilder: (context, index) => const Divider(),
      itemCount: songHistory.length,
    );
  }

  Widget _buildLikedSongAvatar(Map<String, String> song) {
    return Container(
      width: 60, // Set the width for the square
      height: 60, // Set the height for the square
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 206, 25, 25),
        borderRadius:
            BorderRadius.circular(12), // Apply rounded corners with radius
        image: song['albumArtPath'] != null
            ? DecorationImage(
                image: FileImage(File(song['albumArtPath']!)),
                fit: BoxFit.cover, // Fit the image within the square
              )
            : null,
      ),
      child: song['albumArtPath'] == null
          ? Icon(Icons.music_note, size: 30, color: Colors.grey.shade400)
          : null,
    );
  }

  void _navigateToPlayerScreen(SongDetails song) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          songDetails: song,
          isMiniplayer: false,
        ),
      ),
    );
  }

  Widget _buildPopularTab() {
    return const Center(
      child: Text(
        'Popular Songs',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLikedSongsTab(Color textColor) {
    // Determine Lottie file based on the provided textColor
    final lottieFile = textColor == Colors.white
        ? 'assets/animations/404_2.json'
        : 'assets/animations/404.json';

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_likedSongs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Lottie.asset(
            lottieFile, // Dynamically choose Lottie file based on textColor
            height: MediaQuery.of(context).size.height * 0.5, // Scaled height
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      itemBuilder: (context, index) {
        final song = _likedSongs[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
          leading: _buildLikedSongAvatar(song),
          title: Text(
            song['title'] ?? 'Unknown Title',
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'Jost',
              fontWeight: FontWeight.w500,
              color: textColor, // Adapt text color
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            song['artist'] ?? 'Unknown Artist',
            style: TextStyle(
              fontFamily: 'Jost',
              fontSize: 14,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.favorite, color: Colors.red),
            onPressed: () {
              _unlikeSong(song['title']!, song['artist']!);
            },
          ),
          onTap: () {
            final songDetails = SongDetails(
              title: song['title'] ?? '',
              artists: song['artist'] ?? '',
              albumArt: song['albumArtPath'] ?? '',
              audioUrl: song['audioPath'] ?? '',
            );
            _navigateToPlayerScreen(songDetails);
          },
        );
      },
      separatorBuilder: (context, index) => const Divider(
        color: Colors.grey,
        height: 1,
        indent: 16,
        endIndent: 16,
      ),
      itemCount: _likedSongs.length,
    );
  }
}

// Miniplayer (only show if songDetails is not null)
// if (isMiniplayerActive)
//   Positioned(
//     bottom = 0,
//     left = 0,
//     right = 0,
//     child = GestureDetector(
//       onTap: () {
//         // When the miniplayer is tapped, go to the full screen player
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => PlayerScreen(
//               songDetails: songDetails!, // Pass the current song details
//               isMiniplayer: false, // Open the full screen player
//             ),
//           ),
//         );
//       },
//       child: PlayerScreen(
//         songDetails: songDetails!, // Pass the current song details
//         isMiniplayer: true, // This is the miniplayer version
//       ),
//     ),
//   ),
// ],
// );
