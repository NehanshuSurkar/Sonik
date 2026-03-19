// lib/services/home_service.dart
import 'package:rythmx/Models/home_data.dart';
import 'package:rythmx/Models/songs.dart';
import 'package:rythmx/Services/api_service.dart';

class HomeService {
  final ApiService apiService;

  HomeService({required this.apiService});

  // Fetch trending songs (based on popular searches)
  Future<List<Song>> getTrendingSongs() async {
    // You can customize these based on your API
    final trendingQueries = [
      'popular songs',
      'top hits',
      'viral songs',
      'trending now',
      'bollywood hits',
    ];

    try {
      // Pick a random trending query
      final query =
          trendingQueries[DateTime.now().second % trendingQueries.length];
      final results = await apiService.searchSongs(query);
      return results.take(10).toList();
    } catch (e) {
      print('Error fetching trending: $e');
      return [];
    }
  }

  // Fetch new releases
  Future<List<Song>> getNewReleases() async {
    final newQueries = [
      'new songs 2025',
      'latest releases',
      'new music',
      'fresh tracks',
    ];

    try {
      final query = newQueries[DateTime.now().millisecond % newQueries.length];
      final results = await apiService.searchSongs(query);
      return results.take(10).toList();
    } catch (e) {
      print('Error fetching new releases: $e');
      return [];
    }
  }

  // Fetch popular artists
  Future<List<Artist>> getPopularArtists() async {
    final popularArtists = [
      'Arijit Singh',
      'Atif Aslam',
      'Neha Kakkar',
      'Darshan Raval',
      'Shreya Ghoshal',
      'Badshah',
      'Diljit Dosanjh',
      'AP Dhillon',
    ];

    List<Artist> artists = [];

    for (var artistName in popularArtists) {
      try {
        final results = await apiService.searchSongs(artistName);
        if (results.isNotEmpty) {
          artists.add(
            Artist(
              id: 'artist_${artistName.replaceAll(' ', '_')}',
              name: artistName,
              imageUrl:
                  results.first.images.isNotEmpty
                      ? results.first.images.first.url
                      : '',
              genre: 'Pop',
              songCount: results.length,
            ),
          );
        }
      } catch (e) {
        print('Error fetching artist $artistName: $e');
      }
    }

    return artists;
  }

  // Fetch featured playlists
  Future<List<Playlist>> getFeaturedPlaylists() async {
    final playlists = [
      {
        'name': 'Bollywood Hits',
        'description': 'Top Bollywood songs of the month',
        'query': 'bollywood hits',
      },
      {
        'name': 'Chill Vibes',
        'description': 'Relax and unwind with these soothing tracks',
        'query': 'chill songs',
      },
      {
        'name': 'Workout Mix',
        'description': 'High energy tracks for your workout',
        'query': 'workout songs',
      },
      {
        'name': 'Romantic Classics',
        'description': 'Timeless romantic melodies',
        'query': 'romantic songs',
      },
      {
        'name': 'Party Anthems',
        'description': 'Get the party started with these bangers',
        'query': 'party songs',
      },
      {
        'name': 'Indie Rising',
        'description': 'Best of independent artists',
        'query': 'indie songs',
      },
    ];

    List<Playlist> result = [];

    for (var playlist in playlists) {
      try {
        final songs = await apiService.searchSongs(playlist['query']!);
        result.add(
          Playlist(
            id: 'playlist_${playlist['name']!.replaceAll(' ', '_')}',
            name: playlist['name']!,
            description: playlist['description']!,
            imageUrl:
                songs.isNotEmpty && songs.first.images.isNotEmpty
                    ? songs.first.images.first.url
                    : '',
            songCount: songs.length,
            songs: songs.take(20).toList(),
          ),
        );
      } catch (e) {
        print('Error creating playlist ${playlist['name']}: $e');
      }
    }

    return result;
  }

  // Get recommendations based on user's taste (you can expand this)
  Future<List<Song>> getRecommendedForYou() async {
    // For now, return a mix of different genres
    final queries = ['pop hits', 'rock classics', 'electronic'];
    try {
      final query = queries[DateTime.now().second % queries.length];
      final results = await apiService.searchSongs(query);
      return results.take(10).toList();
    } catch (e) {
      return [];
    }
  }
}
