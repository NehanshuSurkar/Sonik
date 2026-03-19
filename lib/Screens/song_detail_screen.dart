// song_details_screen.dart
import 'package:flutter/material.dart';
import 'package:rythmx/Services/tavily_service.dart';
import 'package:rythmx/Models/songs.dart';
import 'package:rythmx/Services/recommendation_service.dart';

class SongDetailsScreen extends StatefulWidget {
  final Song song;
  final RecommendationService recommendationService;

  const SongDetailsScreen({
    required this.song,
    required this.recommendationService,
  });

  @override
  _SongDetailsScreenState createState() => _SongDetailsScreenState();
}

class _SongDetailsScreenState extends State<SongDetailsScreen> {
  List<MusicRecommendation> aiRecommendations = [];
  List<Song> playableRecommendations = [];
  String? aiAnalysis;
  bool isLoading = true;
  bool isError = false;

  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    try {
      setState(() {
        isLoading = true;
        isError = false;
      });

      print("🔄 Fetching recommendations for: ${widget.song.title}");

      final result = await widget.recommendationService.getSongRecommendations(
        widget.song,
      );

      print("✅ Recommendations fetched: ${result.playableSongs.length} songs");

      setState(() {
        aiAnalysis = result.aiAnalysis;
        aiRecommendations = result.aiRecommendations;
        playableRecommendations = result.playableSongs;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error in _fetchRecommendations: $e');
      setState(() {
        isError = true;
        isLoading = false;
      });
    }
  }

  void _playSong(Song song) {
    Navigator.pop(context, song); // Return the song to play it
  }

  Widget _buildSongInfoCard() {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Song Image
            widget.song.images.isNotEmpty
                ? Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.song.images.first.url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.music_note, size: 60),
                        );
                      },
                    ),
                  ),
                )
                : Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.music_note, size: 60),
                ),

            SizedBox(height: 20),

            // Song Title
            Text(
              widget.song.title,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            SizedBox(height: 8),

            // Artist
            if (widget.song.primaryArtists != null)
              Text(
                widget.song.primaryArtists!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

            SizedBox(height: 4),

            // Album
            if (widget.song.album.isNotEmpty)
              Text(
                "Album: ${widget.song.album}",
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

            SizedBox(height: 16),

            // Divider
            Divider(color: Colors.grey[300]),

            // AI Analysis Section
            if (aiAnalysis != null && aiAnalysis!.isNotEmpty)
              Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.psychology, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        "AI Analysis",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      aiAnalysis!,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      textAlign: TextAlign.justify,
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayableSongCard(Song song) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[200],
          ),
          child:
              song.images.isNotEmpty
                  ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      song.images.first.url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.music_note);
                      },
                    ),
                  )
                  : Icon(Icons.music_note),
        ),
        title: Text(
          song.title,
          style: TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song.primaryArtists ?? 'Unknown Artist',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.play_arrow, color: Colors.green),
        onTap: () => _playSong(song),
      ),
    );
  }

  Widget _buildAiRecommendationCard(MusicRecommendation rec) {
    IconData icon = Icons.music_note;
    Color color = Colors.green;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.grey[50],
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          rec.title,
          style: TextStyle(fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle:
            rec.description.isNotEmpty
                ? Text(
                  rec.description,
                  style: TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
                : null,
        trailing: Text(
          "AI",
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Song Details & Recommendations",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[300],
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: isLoading ? null : _fetchRecommendations,
          ),
        ],
      ),
      body:
          isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.green),
                    SizedBox(height: 16),
                    Text(
                      "Finding similar songs...",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
              : isError
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Couldn't load recommendations",
                      style: TextStyle(color: Colors.grey),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchRecommendations,
                      child: Text("Try Again"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[300],
                      ),
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Song Info
                    _buildSongInfoCard(),

                    // Playable Recommendations Section
                    if (playableRecommendations.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 8,
                          bottom: 8,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.recommend, color: Colors.green),
                                SizedBox(width: 8),
                                Text(
                                  "Similar Songs to Play (${playableRecommendations.length})",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Click any song to play it",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 16),
                            ...playableRecommendations
                                .map((song) => _buildPlayableSongCard(song))
                                .toList(),
                          ],
                        ),
                      ),

                    // AI Recommendations Section
                    if (aiRecommendations.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome, color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  "AI Discoveries",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              "AI found these related songs:",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 16),
                            ...aiRecommendations
                                .take(5) // Show top 5 AI recommendations
                                .map((rec) => _buildAiRecommendationCard(rec))
                                .toList(),
                          ],
                        ),
                      ),

                    // Empty State
                    if (playableRecommendations.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.music_off,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            SizedBox(height: 16),
                            Text(
                              "No similar songs found",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Try playing this song first, then check again",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
    );
  }
}
