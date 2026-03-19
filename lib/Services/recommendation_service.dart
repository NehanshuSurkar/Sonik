// services/recommendation_service.dart
import 'package:rythmx/Services/tavily_service.dart';
import 'package:rythmx/Models/songs.dart';
import 'package:rythmx/Services/api_service.dart';

class RecommendationService {
  final TavilyService tavilyService;
  final ApiService apiService;

  RecommendationService({
    required this.tavilyService,
    required this.apiService,
  });

  Future<RecommendationResult> getSongRecommendations(Song song) async {
    try {
      print("🎵 Getting recommendations for: ${song.title}");

      // Step 1: Get AI recommendations from Tavily with improved query
      final query =
          song.primaryArtists != null
              ? "${song.title} by ${song.primaryArtists}"
              : song.title;

      final tavilyResponse = await tavilyService.quickMusicSearch(query);
      print("📡 Tavily response received");

      // Parse AI recommendations
      final aiRecommendations = tavilyService.parseMusicRecommendations(
        tavilyResponse,
      );
      print("📋 Parsed ${aiRecommendations.length} AI recommendations");

      // Step 2: For each AI recommendation, search for actual songs on Saavn
      final List<Song> playableSongs = [];
      final Set<String> fetchedSongIds = {
        song.id,
      }; // Avoid duplicate current song

      // First try: Search for each AI recommendation
      for (var aiRec in aiRecommendations.take(8)) {
        // Try up to 8
        try {
          print("🔍 Searching Saavn for: ${aiRec.title}");

          // Use the title as search query
          final songs = await apiService.searchSongs(aiRec.title);

          if (songs.isNotEmpty) {
            // Take the first match that's not the current song
            for (var saavnSong in songs) {
              if (!fetchedSongIds.contains(saavnSong.id)) {
                fetchedSongIds.add(saavnSong.id);
                playableSongs.add(saavnSong);
                print("✅ Found playable: ${saavnSong.title}");
                break; // Take only the best match per recommendation
              }
            }
          } else {
            print("⚠️ No results for: ${aiRec.title}");
          }

          if (playableSongs.length >= 10) break;
        } catch (e) {
          print("❌ Error searching for ${aiRec.title}: $e");
          continue;
        }
      }

      // Second try: If we don't have enough songs, search by artist
      if (playableSongs.length < 5 && song.primaryArtists != null) {
        print("🎤 Fallback: Searching by artist: ${song.primaryArtists}");
        final artistSongs = await apiService.searchSongs(song.primaryArtists!);

        for (var artistSong in artistSongs) {
          // Skip the current song
          if (artistSong.id == song.id) continue;

          // Skip if already in playlist
          if (!fetchedSongIds.contains(artistSong.id)) {
            fetchedSongIds.add(artistSong.id);
            playableSongs.add(artistSong);
            print("✅ Added artist song: ${artistSong.title}");
            if (playableSongs.length >= 8) break;
          }
        }
      }

      // Third try: If still not enough, search by genre if available
      if (playableSongs.length < 3 &&
          song.genres != null &&
          song.genres!.isNotEmpty) {
        final genre = song.genres!.first;
        print("🎸 Fallback: Searching by genre: $genre");
        final genreSongs = await apiService.searchSongs(genre);

        for (var genreSong in genreSongs.take(5)) {
          if (!fetchedSongIds.contains(genreSong.id) &&
              genreSong.id != song.id) {
            fetchedSongIds.add(genreSong.id);
            playableSongs.add(genreSong);
            if (playableSongs.length >= 5) break;
          }
        }
      }

      print("✅ Found ${playableSongs.length} playable recommendations");

      // Extract AI analysis text
      String? aiAnalysis;
      if (tavilyResponse['answer'] != null) {
        aiAnalysis = tavilyResponse['answer'].toString();
      } else if (tavilyResponse['content'] != null) {
        aiAnalysis = tavilyResponse['content'].toString();
      }

      return RecommendationResult(
        aiAnalysis: aiAnalysis,
        aiRecommendations: aiRecommendations,
        playableSongs: playableSongs,
      );
    } catch (e) {
      print("❌ Error getting recommendations: $e");
      return RecommendationResult(
        aiAnalysis: null,
        aiRecommendations: [],
        playableSongs: [],
      );
    }
  }
}

class RecommendationResult {
  final String? aiAnalysis;
  final List<MusicRecommendation> aiRecommendations;
  final List<Song> playableSongs;

  RecommendationResult({
    required this.aiAnalysis,
    required this.aiRecommendations,
    required this.playableSongs,
  });
}
