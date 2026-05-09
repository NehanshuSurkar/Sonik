import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:rythmx/Models/music_player.dart';
import 'package:rythmx/Models/songs.dart';
import 'package:rythmx/Screens/home_screen.dart';
import 'package:rythmx/Screens/search_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(
    debug: true, // set to false in production
    ignoreSsl: true,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RythmX',
      theme: ThemeData(
        appBarTheme: AppBarTheme(elevation: 4),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainScreen(), // Changed back to MainScreen with tabs
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late MusicPlayerService _playerService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _playerService = MusicPlayerService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Don't dispose player service here as it might be needed
    super.dispose();
  }

  // Method to play song from anywhere
  Future<void> playSong(Song song) async {
    print("🎵 MainScreen.playSong called for: ${song.title}");
    // First, switch to search tab
    _tabController.animateTo(1);

    // Wait for tab switch to complete
    await Future.delayed(Duration(milliseconds: 300));

    // Get the search screen state and play the song
    final searchState = SearchScreenGlobalKey.searchKey.currentState;
    if (searchState != null) {
      print("✅ Search screen state found, forwarding song");
      await searchState.playSong(song);
    } else {
      print("❌ Search screen not initialized");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Search screen not ready. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: TabBarView(
        controller: _tabController,
        children: [
          HomeScreen(
            onPlaySong: playSong, // Pass the playSong method
            tabController: _tabController,
          ),
          SearchScreen(
            key: SearchScreenGlobalKey.searchKey,
            playerService: _playerService,
          ),
          // LibraryScreen (placeholder for now)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.library_music, size: 80, color: Colors.green[300]),
                SizedBox(height: 16),
                Text(
                  'Library Coming Soon...',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your saved songs and playlists will appear here',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: NeumorphicNavBar(tabController: _tabController),
    );
  }
}

class NeumorphicNavBar extends StatefulWidget {
  final TabController tabController;

  const NeumorphicNavBar({required this.tabController});

  @override
  State<NeumorphicNavBar> createState() => _NeumorphicNavBarState();
}

class _NeumorphicNavBarState extends State<NeumorphicNavBar>
    with TickerProviderStateMixin {
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _opacityAnimations;

  @override
  void initState() {
    super.initState();
    _animationControllers = List.generate(3, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      );
    });

    _scaleAnimations = List.generate(3, (index) {
      return Tween<double>(begin: 1.0, end: 1.15).animate(
        CurvedAnimation(
          parent: _animationControllers[index],
          curve: Curves.easeOutBack,
        ),
      );
    });

    _opacityAnimations = List.generate(3, (index) {
      return Tween<double>(begin: 1.0, end: 0.3).animate(
        CurvedAnimation(
          parent: _animationControllers[index],
          curve: Curves.easeInOut,
        ),
      );
    });

    widget.tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (mounted) {
      setState(() {});
      // Animate the newly selected tab
      final selectedIndex = widget.tabController.index;
      _animationControllers[selectedIndex].forward();

      // Reset animation after completion
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && widget.tabController.index == selectedIndex) {
          _animationControllers[selectedIndex].reset();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_handleTabChange);
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      height: 70,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[400]!, Colors.teal[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: Material(
          color: Colors.transparent,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(3, (index) {
              final isSelected = widget.tabController.index == index;
              return _buildNeumorphicTab(
                index: index,
                icon:
                    index == 0
                        ? Icons.home
                        : index == 1
                        ? Icons.search
                        : Icons.library_music,
                label:
                    index == 0
                        ? 'Home'
                        : index == 1
                        ? 'Search'
                        : 'Library',
                isSelected: isSelected,
                onTap: () => widget.tabController.animateTo(index),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNeumorphicTab({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _animationControllers[index].forward();
          onTap();
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && widget.tabController.index == index) {
              _animationControllers[index].reset();
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? Colors.white.withOpacity(0.95)
                    : Colors
                        .transparent, // Changed: removed bubble effect when not selected
            borderRadius: BorderRadius.circular(25),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: Colors.green[800]!.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(-2, -2),
                      ),
                      BoxShadow(
                        color: Colors.teal[800]!.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(2, 2),
                      ),
                    ]
                    : null,
            border:
                isSelected
                    ? Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 0.5,
                    )
                    : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimations[index],
                child: Icon(
                  icon,
                  color:
                      isSelected
                          ? Colors.green[600]
                          : Colors
                              .white, // Changed: constant white color for unselected text
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              FadeTransition(
                opacity: _opacityAnimations[index],
                child: Text(
                  label,
                  style: TextStyle(
                    color:
                        isSelected
                            ? Colors.green[600]
                            : Colors
                                .white, // Changed: constant white color for unselected text
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
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

class AnimatedBottomNavBar extends StatefulWidget {
  final TabController tabController;

  const AnimatedBottomNavBar({required this.tabController});

  @override
  State<AnimatedBottomNavBar> createState() => _AnimatedBottomNavBarState();
}

class _AnimatedBottomNavBarState extends State<AnimatedBottomNavBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[400]!, Colors.teal[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(3, (index) {
                  return _buildAnimatedTab(
                    index: index,
                    icon:
                        index == 0
                            ? Icons.home
                            : index == 1
                            ? Icons.search
                            : Icons.library_music,
                    label:
                        index == 0
                            ? 'Home'
                            : index == 1
                            ? 'Search'
                            : 'Library',
                    isSelected: widget.tabController.index == index,
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTab({
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        widget.tabController.animateTo(index);
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              tween: Tween<double>(begin: 1.0, end: isSelected ? 1.1 : 1.0),
              builder: (context, double scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.white70,
                    size: 24,
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// Global key to access SearchScreen state
class SearchScreenGlobalKey {
  static final GlobalKey<SearchScreenState> searchKey =
      GlobalKey<SearchScreenState>();
}
