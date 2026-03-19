// // auto_play_service.dart
// import 'dart:async';
// import 'package:rythmx/Models/songs.dart';
// import 'package:rythmx/Services/api_service.dart';

// class AutoPlayService {
//   final ApiService apiService;
//   final Function(Song) onPlaySong;

//   // Cache for recommendations to avoid repeated API calls
//   final Map<String, List<Song>> _recommendationCache = {};
//   final Set<String> _playedSongIds = {};

//   // Queue for upcoming songs
//   final List<Song> _autoPlayQueue = [];

//   // Currently playing context
//   Song? _currentSong;
//   String? _currentArtist;
//   String? _currentGenre;

//   // State
//   bool _isEnabled = true;
//   bool _isLoading = false;

//   AutoPlayService({required this.apiService, required this.onPlaySong});

//   /// Enable/disable auto-play
//   void setEnabled(bool enabled) {
//     _isEnabled = enabled;
//     if (!enabled) {
//       _autoPlayQueue.clear();
//     }
//   }

//   bool get isEnabled => _isEnabled;

//   /// Called when a song starts playing
//   Future<void> onSongStarted(Song song) async {
//     if (!_isEnabled) return;

//     print("🎵 Auto-play: Song started - ${song.title}");
//     print("🎵 Auto-play: Artist - ${song.primaryArtists}");
//     print("🎵 Auto-play: Genres - ${song.genres}");

//     _currentSong = song;
//     _currentArtist = song.primaryArtists;
//     _playedSongIds.add(song.id);

//     // Clear old queue and prepare new one
//     _autoPlayQueue.clear();

//     // Immediately fetch next songs
//     await _fetchNextSongs(song);
//     print("🎵 Auto-play: Queue now has ${_autoPlayQueue.length} songs");
//     for (var i = 0; i < _autoPlayQueue.length; i++) {
//       print("🎵 Auto-play queue[$i]: ${_autoPlayQueue[i].title}");
//     }
//   }

//   /// Called when current song ends - play next song
//   Future<void> onSongEnded() async {
//     if (!_isEnabled) {
//       print("⏸️ Auto-play is disabled");
//       return;
//     }

//     print("🎵 Auto-play: Song ended, looking for next...");

//     // If we have songs in queue, play the next one
//     if (_autoPlayQueue.isNotEmpty) {
//       final nextSong = _autoPlayQueue.removeAt(0);
//       print("🎵 Auto-play: Playing next from queue - ${nextSong.title}");
//       onPlaySong(nextSong);

//       // Fetch more songs in background if queue is getting low
//       if (_autoPlayQueue.length < 3 && _currentSong != null) {
//         _fetchNextSongs(_currentSong!);
//       }
//       return;
//     }

//     // Queue is empty, try to fetch new recommendations
//     if (_currentSong != null) {
//       print("🎵 Auto-play: Queue empty, fetching new recommendations");
//       await _fetchNextSongs(_currentSong!);

//       if (_autoPlayQueue.isNotEmpty) {
//         final nextSong = _autoPlayQueue.removeAt(0);
//         onPlaySong(nextSong);
//       } else {
//         print("❌ Auto-play: No recommendations found");
//       }
//     }
//   }

//   /// Fetch next songs based on current song
//   Future<void> _fetchNextSongs(Song song) async {
//     if (_isLoading) return;

//     _isLoading = true;

//     try {
//       // Try to get recommendations based on artist first
//       if (song.primaryArtists != null && song.primaryArtists!.isNotEmpty) {
//         await _fetchSongsByArtist(song.primaryArtists!, excludeSongId: song.id);
//       }

//       // If we still need more songs, try by song title
//       if (_autoPlayQueue.length < 5) {
//         await _fetchSongsBySimilarTitle(song.title, excludeSongId: song.id);
//       }

//       // If still not enough, try by genre if available
//       if (_autoPlayQueue.length < 5 &&
//           song.genres != null &&
//           song.genres!.isNotEmpty) {
//         for (var genre in song.genres!.take(2)) {
//           await _fetchSongsByGenre(genre, excludeSongId: song.id);
//           if (_autoPlayQueue.length >= 5) break;
//         }
//       }

//       print("🎵 Auto-play: Queue now has ${_autoPlayQueue.length} songs");
//     } catch (e) {
//       print("❌ Auto-play fetch error: $e");
//     } finally {
//       _isLoading = false;
//     }
//   }

//   /// Fetch songs by the same artist
//   Future<void> _fetchSongsByArtist(
//     String artist, {
//     required String excludeSongId,
//   }) async {
//     try {
//       // Check cache first
//       if (_recommendationCache.containsKey('artist:$artist')) {
//         final cached = _recommendationCache['artist:$artist']!;
//         _addToQueue(cached, excludeSongId: excludeSongId);
//         return;
//       }

//       print("🎤 Auto-play: Searching by artist: $artist");
//       final results = await apiService.searchSongs(artist);

//       // Filter and cache
//       final validSongs =
//           results
//               .where(
//                 (s) => s.downloadUrls != null && s.downloadUrls!.isNotEmpty,
//               )
//               .toList();

//       _recommendationCache['artist:$artist'] = validSongs;
//       _addToQueue(validSongs, excludeSongId: excludeSongId);
//     } catch (e) {
//       print("❌ Error fetching by artist: $e");
//     }
//   }

//   /// Fetch songs by similar title/keywords
//   Future<void> _fetchSongsBySimilarTitle(
//     String title, {
//     required String excludeSongId,
//   }) async {
//     try {
//       // Extract main keywords (remove common words)
//       final keywords = title
//           .toLowerCase()
//           .replaceAll(RegExp(r'\([^)]+\)'), '')
//           .split(' ')
//           .where((w) => w.length > 3)
//           .take(2)
//           .join(' ');

//       if (keywords.isEmpty) return;

//       print("🔍 Auto-play: Searching by keywords: $keywords");
//       final results = await apiService.searchSongs(keywords);

//       final validSongs =
//           results
//               .where(
//                 (s) => s.downloadUrls != null && s.downloadUrls!.isNotEmpty,
//               )
//               .toList();

//       _addToQueue(validSongs, excludeSongId: excludeSongId);
//     } catch (e) {
//       print("❌ Error fetching by title: $e");
//     }
//   }

//   /// Fetch songs by genre
//   Future<void> _fetchSongsByGenre(
//     String genre, {
//     required String excludeSongId,
//   }) async {
//     try {
//       print("🎸 Auto-play: Searching by genre: $genre");
//       final results = await apiService.searchSongs(genre);

//       final validSongs =
//           results
//               .where(
//                 (s) => s.downloadUrls != null && s.downloadUrls!.isNotEmpty,
//               )
//               .toList();

//       _addToQueue(validSongs, excludeSongId: excludeSongId);
//     } catch (e) {
//       print("❌ Error fetching by genre: $e");
//     }
//   }

//   /// Add songs to queue, avoiding duplicates
//   void _addToQueue(List<Song> songs, {required String excludeSongId}) {
//     for (var song in songs) {
//       // Skip if already played or already in queue
//       if (_playedSongIds.contains(song.id)) continue;
//       if (_autoPlayQueue.any((s) => s.id == song.id)) continue;
//       if (song.id == excludeSongId) continue;

//       _autoPlayQueue.add(song);

//       // Limit queue size
//       if (_autoPlayQueue.length >= 10) break;
//     }
//   }

//   /// Get current queue
//   List<Song> getQueue() => List.from(_autoPlayQueue);

//   /// Clear cache and played history
//   void reset() {
//     _recommendationCache.clear();
//     _playedSongIds.clear();
//     _autoPlayQueue.clear();
//   }
// }

import 'dart:async';
import 'package:rythmx/Models/songs.dart';
import 'package:rythmx/Services/api_service.dart';

class AutoPlayService {
  final ApiService apiService;
  final Function(Song) onPlaySong;

  // Use a queue of song IDs to prevent duplicates
  final List<String> _queue = [];
  final Map<String, Song> _songCache = {};
  final Set<String> _playedSongIds = {};

  String? _currentSongId;
  bool _isEnabled = true;
  bool _isLoading = false;
  bool _isFetching = false;

  // Add debounce mechanism
  Timer? _fetchDebounceTimer;

  AutoPlayService({required this.apiService, required this.onPlaySong});

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    if (!enabled) {
      _queue.clear();
    }
  }

  bool get isEnabled => _isEnabled;
  int get queueLength => _queue.length;

  Future<void> onSongStarted(Song song) async {
    if (!_isEnabled) return;

    _currentSongId = song.id;
    _playedSongIds.add(song.id);

    // Cancel any pending fetch
    _fetchDebounceTimer?.cancel();

    // Debounce to prevent multiple rapid fetches
    _fetchDebounceTimer = Timer(Duration(seconds: 1), () {
      _fetchNextSongs(song);
    });
  }

  Future<void> onSongEnded() async {
    if (!_isEnabled || _queue.isEmpty) return;

    final nextSongId = _queue.removeAt(0);
    final nextSong = _songCache[nextSongId];

    if (nextSong != null) {
      onPlaySong(nextSong);
    }

    // Trigger background fetch if queue is low
    if (_queue.length < 3 && _currentSongId != null) {
      final currentSong = _songCache[_currentSongId];
      if (currentSong != null) {
        _fetchNextSongs(currentSong);
      }
    }
  }

  Future<void> _fetchNextSongs(Song song) async {
    if (_isFetching) return;

    _isFetching = true;

    try {
      final List<Song> newSongs = [];

      // Try artist-based search first
      if (song.primaryArtists != null && song.primaryArtists!.isNotEmpty) {
        final artistSongs = await _fetchSongsByArtist(
          song.primaryArtists!,
          excludeSongId: song.id,
        );
        newSongs.addAll(artistSongs);
      }

      // If still need more, try similar title
      if (newSongs.length < 5) {
        final titleSongs = await _fetchSongsBySimilarTitle(
          song.title,
          excludeSongId: song.id,
        );
        newSongs.addAll(titleSongs);
      }

      // Add to queue, avoiding duplicates
      for (var newSong in newSongs) {
        if (!_playedSongIds.contains(newSong.id) &&
            !_queue.contains(newSong.id) &&
            _queue.length < 10) {
          _queue.add(newSong.id);
          _songCache[newSong.id] = newSong;
        }
      }
    } catch (e) {
      print("Auto-play fetch error: $e");
    } finally {
      _isFetching = false;
    }
  }

  Future<List<Song>> _fetchSongsByArtist(
    String artist, {
    required String excludeSongId,
  }) async {
    try {
      final results = await apiService.searchSongs(artist);
      return results
          .where(
            (s) =>
                s.id != excludeSongId &&
                s.downloadUrls != null &&
                s.downloadUrls!.isNotEmpty,
          )
          .take(3)
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Song>> _fetchSongsBySimilarTitle(
    String title, {
    required String excludeSongId,
  }) async {
    try {
      // Extract keywords
      final keywords = title
          .split(' ')
          .where((w) => w.length > 3)
          .take(2)
          .join(' ');

      if (keywords.isEmpty) return [];

      final results = await apiService.searchSongs(keywords);
      return results
          .where(
            (s) =>
                s.id != excludeSongId &&
                s.downloadUrls != null &&
                s.downloadUrls!.isNotEmpty,
          )
          .take(3)
          .toList();
    } catch (e) {
      return [];
    }
  }

  List<Song> getQueue() {
    return _queue.map((id) => _songCache[id]).whereType<Song>().toList();
  }

  Song? getNextSong() {
    if (_queue.isEmpty) return null;
    return _songCache[_queue.first];
  }

  void clearQueue() {
    _queue.clear();
    // Don't clear cache - keep for history
  }

  void reset() {
    _queue.clear();
    _songCache.clear();
    _playedSongIds.clear();
    _currentSongId = null;
  }
}
