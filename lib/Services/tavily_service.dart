// tavily_service.dart
import 'dart:convert';
import 'dart:math' show min;
import 'package:http/http.dart' as http;

class TavilyService {
  static const String _baseUrl = 'https://api.tavily.com';
  final String apiKey;

  TavilyService({required this.apiKey});

  /// Start a research task for music recommendations
  Future<String?> startMusicResearch(String query) async {
    final fullQuery =
        "Music information about '$query': "
        "Provide similar songs, artists, albums, genres, and recommendations. "
        "Include release years, popularity, and brief descriptions.";

    final response = await http.post(
      Uri.parse('$_baseUrl/research'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'query': fullQuery,
        'search_depth': 'advanced',
        'max_results': 10,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['request_id'];
    } else {
      print('Tavily API Error: ${response.statusCode} - ${response.body}');
      return null;
    }
  }

  /// Poll research result
  Future<Map<String, dynamic>> getResearchResult(String requestId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/research/$requestId'),
      headers: {'Authorization': 'Bearer $apiKey'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to fetch research result: ${response.statusCode}',
      );
    }
  }

  /// Quick search for immediate results
  Future<Map<String, dynamic>> quickMusicSearch(String query) async {
    print("🎵 Tavily searching for: $query");

    // Clean the query
    final cleanQuery = query.replaceAll('"', '').trim();

    // Create a more focused query for song recommendations
    // IMPORTANT: Keep it simple and direct
    final searchQuery = "songs similar to $cleanQuery list";

    try {
      print("📡 Sending request to Tavily API with query: $searchQuery");

      final response = await http.post(
        Uri.parse('$_baseUrl/search'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'query': searchQuery, // Simple, direct query
          'search_depth': 'basic',
          'include_answer': true,
          'include_images': false,
          'max_results': 5,
          'include_raw_content': false,
        }),
      );

      print("📡 Tavily response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("✅ Tavily search successful");

        // Log a preview of the response
        if (data['answer'] != null) {
          print(
            "📝 Answer preview: ${data['answer'].toString().substring(0, min(100, data['answer'].toString().length))}...",
          );
        }

        return data;
      } else {
        print("❌ Tavily API Error: ${response.statusCode}");
        print("Response body: ${response.body}");

        // Return fallback recommendations
        return _getFallbackRecommendations(cleanQuery);
      }
    } catch (e) {
      print("❌ Tavily network error: $e");
      return _getFallbackRecommendations(cleanQuery);
    }
  }

  /// Provide fallback recommendations when API fails
  Map<String, dynamic> _getFallbackRecommendations(String query) {
    // Extract artist or song name for better fallbacks
    final lowerQuery = query.toLowerCase();

    String fallbackSongs;

    if (lowerQuery.contains('arijit') || lowerQuery.contains('singh')) {
      fallbackSongs = '''
- Tum Hi Ho by Arijit Singh
- Channa Mereya by Arijit Singh
- Ae Dil Hai Mushkil by Arijit Singh
- Gerua by Arijit Singh
- Sanam Re by Arijit Singh
- Janam Janam by Arijit Singh
- Deewani Mastani by Arijit Singh
- Nashe Si Chadh Gayi by Arijit Singh
- Hamari Adhuri Kahani by Arijit Singh
- Phir Bhi Tumko Chaahunga by Arijit Singh
    ''';
    } else if (lowerQuery.contains('atif') || lowerQuery.contains('aslam')) {
      fallbackSongs = '''
- Tera Hone Laga Hoon by Atif Aslam
- Pehli Dafa by Atif Aslam
- Jeena Jeena by Atif Aslam
- Dil Diyan Gallan by Atif Aslam
- Tu Jaane Na by Atif Aslam
- Woh Lamhe by Atif Aslam
- Aadat by Atif Aslam
- Be Intehaan by Atif Aslam
- Rabba by Atif Aslam
- Tere Liye by Atif Aslam
    ''';
    } else {
      fallbackSongs = '''
- Shape of You by Ed Sheeran
- Blinding Lights by The Weeknd
- Dance Monkey by Tones and I
- Someone You Loved by Lewis Capaldi
- Bad Guy by Billie Eilish
- Believer by Imagine Dragons
- Havana by Camila Cabello
- Perfect by Ed Sheeran
- Senorita by Shawn Mendes
- Sunflower by Post Malone
    ''';
    }

    return {'answer': fallbackSongs, 'content': fallbackSongs};
  }

  List<MusicRecommendation> parseMusicRecommendations(
    Map<String, dynamic> result,
  ) {
    final List<MusicRecommendation> recommendations = [];
    final Set<String> uniqueTitles = {};

    try {
      // Get the content/answer from Tavily
      String content = result['answer'] ?? result['content'] ?? '';

      print("📝 Raw Tavily content: $content");

      if (content.isEmpty) {
        print("⚠️ No content in Tavily response");
        return [];
      }

      // METHOD 1: Look for "Song Name by Artist" pattern (WITHOUT quotes)
      // This matches: "Pani Da Rang by Ayushmann Khurrana"
      final byPatternNoQuotes = RegExp(
        r'([A-Z][A-Za-z\s]+?)\s+by\s+([A-Z][A-Za-z\s]+?)(?=[,.]|$)',
        caseSensitive: false,
      );
      final byMatches = byPatternNoQuotes.allMatches(content);

      for (var match in byMatches) {
        String title = match.group(1)?.trim() ?? '';
        String artist = match.group(2)?.trim() ?? '';

        if (title.isNotEmpty &&
            artist.isNotEmpty &&
            !uniqueTitles.contains(title.toLowerCase()) &&
            title.length < 50) {
          uniqueTitles.add(title.toLowerCase());
          recommendations.add(
            MusicRecommendation(
              title: title,
              description: 'by $artist',
              category: 'Recommended Songs',
              type: 'song',
            ),
          );
          print("✅ Found song with artist: $title by $artist");
        }
      }

      // METHOD 2: Extract quoted text (if any)
      final quotedPattern = RegExp(r'"([^"]+)"');
      final quotedMatches = quotedPattern.allMatches(content);

      for (var match in quotedMatches) {
        String quoted = match.group(1)?.trim() ?? '';
        if (quoted.isNotEmpty &&
            quoted.length > 2 &&
            quoted.length < 50 &&
            !uniqueTitles.contains(quoted.toLowerCase())) {
          // Try to find artist for this quoted title
          String artist = '';
          final artistMatch = RegExp(
            '"$quoted"\\s+by\\s+([^,.!?]+)',
            caseSensitive: false,
          ).firstMatch(content);
          if (artistMatch != null) {
            artist = artistMatch.group(1)?.trim() ?? '';
          }

          uniqueTitles.add(quoted.toLowerCase());
          recommendations.add(
            MusicRecommendation(
              title: quoted,
              description:
                  artist.isNotEmpty ? 'by $artist' : 'Recommended song',
              category: 'Recommended Songs',
              type: 'song',
            ),
          );
          print(
            "✅ Found quoted song: $quoted ${artist.isNotEmpty ? 'by $artist' : ''}",
          );
        }
      }

      // METHOD 3: Look for bullet points or lists
      final lines = content.split('\n');
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty) continue;

        // Check if line starts with bullet points, dashes, or numbers
        if (RegExp(r'^[-•*●○◆◇▪▫—–\s\d\.]+').hasMatch(line)) {
          String cleanLine =
              line.replaceFirst(RegExp(r'^[-•*●○◆◇▪▫—–\s\d\.]+'), '').trim();

          // Try to extract song and artist from bullet point
          final bulletMatch = RegExp(
            r'([A-Za-z\s]+?)(?:\s+by\s+|\s+[-–]\s+)([A-Za-z\s]+)',
            caseSensitive: false,
          ).firstMatch(cleanLine);

          if (bulletMatch != null) {
            String title = bulletMatch.group(1)?.trim() ?? '';
            String artist = bulletMatch.group(2)?.trim() ?? '';

            if (title.isNotEmpty &&
                !uniqueTitles.contains(title.toLowerCase())) {
              uniqueTitles.add(title.toLowerCase());
              recommendations.add(
                MusicRecommendation(
                  title: title,
                  description: 'by $artist',
                  category: 'Recommended Songs',
                  type: 'song',
                ),
              );
              print("✅ Found from bullet: $title by $artist");
            }
          }
        }
      }

      // METHOD 4: If we still have few recommendations, split by commas
      if (recommendations.length < 3) {
        // Split by common patterns
        final parts = content.split(RegExp(r',\s*|\.\s*'));

        for (var part in parts) {
          // Look for "something by someone" pattern
          final match = RegExp(
            r'([A-Z][A-Za-z\s]+?)\s+by\s+([A-Z][A-Za-z\s]+)',
            caseSensitive: false,
          ).firstMatch(part);

          if (match != null) {
            String title = match.group(1)?.trim() ?? '';
            String artist = match.group(2)?.trim() ?? '';

            if (title.isNotEmpty &&
                artist.isNotEmpty &&
                !uniqueTitles.contains(title.toLowerCase())) {
              uniqueTitles.add(title.toLowerCase());
              recommendations.add(
                MusicRecommendation(
                  title: title,
                  description: 'by $artist',
                  category: 'Recommended Songs',
                  type: 'song',
                ),
              );
              print("✅ Found from split: $title by $artist");
            }
          }
        }
      }

      print("🎵 Total recommendations parsed: ${recommendations.length}");
    } catch (e) {
      print('❌ Error parsing recommendations: $e');
    }

    return recommendations;
  }

  String _determineType(String category, String title) {
    final lowerTitle = title.toLowerCase();

    if (category == 'Artists') return 'artist';
    if (category == 'Songs') return 'song';
    if (category == 'Albums') return 'album';
    if (category == 'Genres') return 'genre';

    // Guess based on title patterns
    if (lowerTitle.contains('song') ||
        lowerTitle.contains('track') ||
        lowerTitle.contains('single')) {
      return 'song';
    }
    if (lowerTitle.contains('album') ||
        lowerTitle.contains('lp') ||
        lowerTitle.contains('ep')) {
      return 'album';
    }
    if (lowerTitle.contains('artist') ||
        lowerTitle.contains('band') ||
        lowerTitle.contains('singer')) {
      return 'artist';
    }
    if (lowerTitle.contains('genre') ||
        lowerTitle.contains('style') ||
        lowerTitle.contains('type of music')) {
      return 'genre';
    }

    return 'recommendation';
  }
}

class MusicRecommendation {
  final String title;
  final String description;
  final String category;
  final String type;
  final double? rating;

  MusicRecommendation({
    required this.title,
    required this.description,
    required this.category,
    required this.type,
    this.rating,
  });
}
