// lib/Screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:rythmx/Models/home_data.dart';
import 'package:rythmx/Services/home_service.dart';
import 'package:rythmx/Models/songs.dart';
import 'package:rythmx/Services/api_service.dart';

class HomeScreen extends StatefulWidget {
  final Function(Song) onPlaySong;
  final TabController? tabController;

  const HomeScreen({Key? key, required this.onPlaySong, this.tabController})
    : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  late HomeService _homeService;
  bool _isLoading = true;

  List<HomeSection> _sections = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _homeService = HomeService(apiService: ApiService());
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch all data in parallel
      final trendingSongs = await _homeService.getTrendingSongs();
      final newReleases = await _homeService.getNewReleases();
      final featuredPlaylists = await _homeService.getFeaturedPlaylists();
      final popularArtists = await _homeService.getPopularArtists();
      final recommendedSongs = await _homeService.getRecommendedForYou();

      _sections = [
        // Greeting Section (Special)
        HomeSection(
          title: "Let's get Sonik",
          subtitle: 'Discover your favorite songs',
          items: [],
          type: SectionType.trending,
        ),

        // Trending Now
        if (trendingSongs.isNotEmpty)
          HomeSection(
            title: '🔥 Trending Now',
            subtitle: 'Most played songs today',
            items:
                trendingSongs
                    .map(
                      (song) => HomeItem(
                        id: song.id,
                        title: song.title,
                        subtitle: song.primaryArtists ?? 'Unknown Artist',
                        imageUrl:
                            song.images.isNotEmpty ? song.images.first.url : '',
                        type: ItemType.song,
                        data: song,
                      ),
                    )
                    .toList(),
            type: SectionType.trending,
          ),

        // Featured Playlists
        if (featuredPlaylists.isNotEmpty)
          HomeSection(
            title: 'Featured Playlists',
            subtitle: 'Curated just for you',
            items:
                featuredPlaylists
                    .map(
                      (playlist) => HomeItem(
                        id: playlist.id,
                        title: playlist.name,
                        subtitle: playlist.description,
                        imageUrl: playlist.imageUrl,
                        type: ItemType.playlist,
                        data: playlist,
                      ),
                    )
                    .toList(),
            type: SectionType.featuredPlaylists,
          ),

        // New Releases
        if (newReleases.isNotEmpty)
          HomeSection(
            title: 'New Releases',
            subtitle: 'Fresh tracks added this week',
            items:
                newReleases
                    .map(
                      (song) => HomeItem(
                        id: song.id,
                        title: song.title,
                        subtitle: song.primaryArtists ?? 'Unknown Artist',
                        imageUrl:
                            song.images.isNotEmpty ? song.images.first.url : '',
                        type: ItemType.song,
                        data: song,
                      ),
                    )
                    .toList(),
            type: SectionType.newReleases,
          ),

        // Popular Artists
        if (popularArtists.isNotEmpty)
          HomeSection(
            title: '🎤 Popular Artists',
            subtitle: 'Artists you might like',
            items:
                popularArtists
                    .map(
                      (artist) => HomeItem(
                        id: artist.id,
                        title: artist.name,
                        subtitle: artist.genre ?? 'Artist',
                        imageUrl: artist.imageUrl,
                        type: ItemType.artist,
                        data: artist,
                      ),
                    )
                    .toList(),
            type: SectionType.popularArtists,
          ),

        // Recommended For You
        if (recommendedSongs.isNotEmpty)
          HomeSection(
            title: 'Some pics for you',
            subtitle: 'Songs we think you\'ll love',
            items:
                recommendedSongs
                    .map(
                      (song) => HomeItem(
                        id: song.id,
                        title: song.title,
                        subtitle: song.primaryArtists ?? 'Unknown Artist',
                        imageUrl:
                            song.images.isNotEmpty ? song.images.first.url : '',
                        type: ItemType.song,
                        data: song,
                      ),
                    )
                    .toList(),
            type: SectionType.recommendedForYou,
          ),
      ];

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading home data: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning ☀️';
    if (hour < 17) return 'Good Afternoon 🌤️';
    return 'Good Evening 🌙';
  }

  void _handleItemTap(HomeItem item) {
    switch (item.type) {
      case ItemType.song:
        widget.onPlaySong(item.data as Song);
        break;
      case ItemType.artist:
        _showArtistSongs(item.data as Artist);
        break;
      case ItemType.playlist:
        _showPlaylist(item.data as Playlist);
        break;
      case ItemType.album:
        // Handle album
        break;
    }
  }

  void _showArtistSongs(Artist artist) {
    // Navigate to artist detail screen
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundImage:
                              artist.imageUrl.isNotEmpty
                                  ? NetworkImage(artist.imageUrl)
                                  : null,
                          child:
                              artist.imageUrl.isEmpty
                                  ? Icon(Icons.person, size: 30)
                                  : null,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                artist.name,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${artist.songCount ?? 0} songs',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: FutureBuilder(
                        future: ApiService().searchSongs(artist.name),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Center(child: CircularProgressIndicator());
                          }
                          final songs = snapshot.data as List<Song>;
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: songs.length,
                            itemBuilder: (context, index) {
                              final song = songs[index];
                              return ListTile(
                                leading:
                                    song.images.isNotEmpty
                                        ? Image.network(
                                          song.images.first.url,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                        )
                                        : Container(
                                          width: 40,
                                          height: 40,
                                          color: Colors.grey[200],
                                        ),
                                title: Text(song.title),
                                subtitle: Text(song.primaryArtists ?? ''),
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onPlaySong(song);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  void _showPlaylist(Playlist playlist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image:
                                playlist.imageUrl.isNotEmpty
                                    ? DecorationImage(
                                      image: NetworkImage(playlist.imageUrl),
                                      fit: BoxFit.cover,
                                    )
                                    : null,
                            color: Colors.grey[300],
                          ),
                          child:
                              playlist.imageUrl.isEmpty
                                  ? Icon(Icons.playlist_play)
                                  : null,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                playlist.name,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                playlist.description,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              Text(
                                '${playlist.songCount} songs',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: FutureBuilder(
                        future: ApiService().searchSongs(playlist.name),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Center(child: CircularProgressIndicator());
                          }
                          final songs = snapshot.data as List<Song>;
                          return ListView.builder(
                            controller: scrollController,
                            itemCount: songs.length,
                            itemBuilder: (context, index) {
                              final song = songs[index];
                              return ListTile(
                                leading:
                                    song.images.isNotEmpty
                                        ? Image.network(
                                          song.images.first.url,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                        )
                                        : Container(
                                          width: 40,
                                          height: 40,
                                          color: Colors.grey[200],
                                        ),
                                title: Text(song.title),
                                subtitle: Text(song.primaryArtists ?? ''),
                                trailing: Icon(
                                  Icons.play_arrow,
                                  color: Colors.green,
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onPlaySong(song);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _loadHomeData,
        color: Colors.green,
        child: CustomScrollView(
          slivers: [
            // App Bar with greeting
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.white10,
              elevation: 0,
              title:
                  _isLoading
                      ? Text('Loading...')
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            // 'Hello 👋 ',
                            // style: TextStyle(
                            //   fontStyle: FontStyle.normal,
                            //   fontSize: 19,
                            //   color: Colors.grey[700],
                            //   fontWeight: FontWeight.w500,
                            // ),
                          ),
                          // Text(
                          //   'Welcome to Sonik',
                          //   style: TextStyle(
                          //     fontSize: 24,
                          //     fontWeight: FontWeight.bold,
                          //     color: Colors.green[700],
                          //   ),
                          // ),
                        ],
                      ),
              actions: [
                IconButton(
                  icon: Icon(Icons.search, color: Colors.green[700]),
                  onPressed: () {
                    // Switch to search tab
                    if (widget.tabController != null) {
                      widget.tabController!.animateTo(1);
                    } else {
                      // Fallback if tabController is not available
                      print("TabController not available");
                    }
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.notifications_none,
                    color: Colors.green[700],
                  ),
                  onPressed: () {},
                ),
              ],
            ),

            if (_isLoading)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.green),
                      SizedBox(height: 16),
                      Text('Discovering music for you...'),
                    ],
                  ),
                ),
              )
            else
              ..._sections.map((section) => _buildSection(section)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(HomeSection section) {
    if (section.items.isEmpty && section.type != SectionType.trending) {
      return SliverToBoxAdapter(child: SizedBox.shrink());
    }

    // Special handling for greeting section
    if (section.type == SectionType.trending && section.items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                ),
              ),
              SizedBox(height: 4),
              Text(
                section.subtitle,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      section.subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'See All',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12),
              itemCount: section.items.length,
              itemBuilder: (context, index) {
                final item = section.items[index];
                return _buildHorizontalCard(item);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCard(HomeItem item) {
    return GestureDetector(
      onTap: () => _handleItemTap(item),
      child: Container(
        width: 150,
        margin: EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image:
                    item.imageUrl.isNotEmpty
                        ? DecorationImage(
                          image: NetworkImage(item.imageUrl),
                          fit: BoxFit.cover,
                        )
                        : null,
                color: Colors.grey[300],
              ),
              child:
                  item.imageUrl.isEmpty
                      ? Icon(
                        item.type == ItemType.artist
                            ? Icons.person
                            : item.type == ItemType.playlist
                            ? Icons.playlist_play
                            : Icons.music_note,
                        size: 40,
                        color: Colors.grey[600],
                      )
                      : null,
            ),
            SizedBox(height: 8),
            Text(
              item.title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              item.subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
