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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[400]!, Colors.teal[400]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.home), text: 'Home'),
            Tab(icon: Icon(Icons.search), text: 'Search'),
            Tab(icon: Icon(Icons.library_music), text: 'Library'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
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
