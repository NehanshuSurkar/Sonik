import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rythmx/Models/songs.dart';

class ApiService {
  static const String baseUrl = "https://saavn.sumit.co";
  static const int maxRetries = 3;
  static const Duration timeout = Duration(seconds: 10);

  Future<http.Response> _getWithRetry(Uri url, {int retryCount = 0}) async {
    try {
      final response = await http.get(url).timeout(timeout);
      return response;
    } catch (e) {
      if (retryCount < maxRetries) {
        print("Retry ${retryCount + 1} for $url");
        await Future.delayed(Duration(seconds: 1 * (retryCount + 1)));
        return _getWithRetry(url, retryCount: retryCount + 1);
      }
      rethrow;
    }
  }

  Future<List<Song>> searchSongs(String query) async {
    final encodedQuery = Uri.encodeQueryComponent(query);
    // Try multiple endpoints
    final urls = [
      Uri.parse(
        "$baseUrl/api/search/songs?query=$encodedQuery&page=0&limit=20",
      ),
      Uri.parse("$baseUrl/api/search?query=$encodedQuery"),
    ];

    for (var url in urls) {
      try {
        print("Searching with URL: $url");
        final res = await http.get(url);

        if (res.statusCode == 200) {
          final jsonData = jsonDecode(res.body);
          print("Response keys: ${jsonData.keys}");

          if (jsonData["success"] == true) {
            List songsData = [];

            // Try different response structures
            if (jsonData["data"]["results"] != null) {
              songsData = jsonData["data"]["results"];
              print("Found ${songsData.length} songs in 'results'");
            } else if (jsonData["data"]["songs"]["results"] != null) {
              songsData = jsonData["data"]["songs"]["results"];
              print("Found ${songsData.length} songs in 'songs.results'");
            }

            return List<Song>.from(songsData.map((s) => Song.fromJson(s)));
          }
        }
      } catch (e) {
        print("Search error with URL $url: $e");
      }
    }

    return [];
  }

  Future<String?> fetchAudioUrl(String songId) async {
    print("Fetching audio for song ID: $songId");
    final url = Uri.parse("$baseUrl/api/song?id=$songId");

    try {
      final res = await http.get(url);
      print("Response status: ${res.statusCode}");

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);

        if (json["success"] == true) {
          final data = json["data"];

          // Create a quality priority map
          const qualityPriority = {
            '320kbps': 4,
            '256kbps': 3,
            '192kbps': 2,
            '128kbps': 1,
            '96kbps': 0,
          };

          String? bestUrl;
          int highestPriority = -1;

          // Check for downloadUrl
          if (data["downloadUrl"] != null && data["downloadUrl"] is List) {
            final downloadUrls = data["downloadUrl"] as List;

            for (var download in downloadUrls) {
              final quality = download['quality']?.toString() ?? '';
              final url = download['url']?.toString();

              if (url != null && url.isNotEmpty) {
                final priority = qualityPriority[quality] ?? -1;
                if (priority > highestPriority) {
                  highestPriority = priority;
                  bestUrl = url;
                }
              }
            }
          }

          // Check alternate location
          if (bestUrl == null &&
              data["downloadUrls"] != null &&
              data["downloadUrls"] is List) {
            final downloadUrls = data["downloadUrls"] as List;
            for (var download in downloadUrls) {
              final quality = download['quality']?.toString() ?? '';
              final url = download['url']?.toString();

              if (url != null && url.isNotEmpty) {
                final priority = qualityPriority[quality] ?? -1;
                if (priority > highestPriority) {
                  highestPriority = priority;
                  bestUrl = url;
                }
              }
            }
          }

          // Final fallback
          if (bestUrl == null) {
            bestUrl = data["url"]?.toString();
          }

          if (bestUrl != null && bestUrl.isNotEmpty) {
            print("Selected audio URL with quality priority: $bestUrl");
            return bestUrl;
          }
        }
      }
    } catch (e) {
      print("Fetch audio URL error: $e");
    }

    return null;
  }
  // Future<String?> fetchAudioUrl(String songId) async {
  //   print("Fetching audio for song ID: $songId");
  //   final url = Uri.parse("$baseUrl/api/song?id=$songId");

  //   try {
  //     final res = await http.get(url);
  //     print("Response status: ${res.statusCode}");

  //     if (res.statusCode == 200) {
  //       final json = jsonDecode(res.body);
  //       print("Song API response: ${json.keys}");

  //       if (json["success"] == true) {
  //         final data = json["data"];
  //         print("Song data keys: ${data.keys}");

  //         // Check for downloadUrl directly in the song data
  //         if (data["downloadUrl"] != null && data["downloadUrl"] is List) {
  //           final downloadUrls = data["downloadUrl"] as List;
  //           print("Found ${downloadUrls.length} download URLs");

  //           for (var download in downloadUrls) {
  //             print(
  //               "Download quality: ${download['quality']}, URL: ${download['url']}",
  //             );
  //           }

  //           if (downloadUrls.isNotEmpty) {
  //             // CHANGED: Always use the LAST URL (highest quality in Saavn)
  //             final highQuality = downloadUrls.last;
  //             print(
  //               "Using LAST download URL (usually highest quality): ${highQuality['quality']}",
  //             );

  //             final audioUrl = highQuality['url'];
  //             if (audioUrl != null && audioUrl.toString().isNotEmpty) {
  //               print("Selected audio URL: $audioUrl");
  //               return audioUrl.toString();
  //             }
  //           }
  //         }

  //         // Try alternate location
  //         if (data["downloadUrls"] != null && data["downloadUrls"] is List) {
  //           final downloadUrls = data["downloadUrls"] as List;
  //           if (downloadUrls.isNotEmpty) {
  //             // CHANGED: Use last URL here too
  //             final audioUrl = downloadUrls.last["url"];
  //             if (audioUrl != null && audioUrl.toString().isNotEmpty) {
  //               print("Alternate audio URL (last): $audioUrl");
  //               return audioUrl.toString();
  //             }
  //           }
  //         }

  //         // Final fallback
  //         final fallbackUrl = data["url"];
  //         if (fallbackUrl != null && fallbackUrl.toString().isNotEmpty) {
  //           print("Fallback URL: $fallbackUrl");
  //           return fallbackUrl.toString();
  //         }
  //       }
  //     }
  //   } catch (e) {
  //     print("Fetch audio URL error: $e");
  //   }

  //   print("No audio URL found for song: $songId");
  //   return null;
  // }
}
