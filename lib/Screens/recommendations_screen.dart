// recommendations_screen.dart
import 'package:flutter/material.dart';
import 'package:rythmx/Services/tavily_service.dart';
import 'package:rythmx/Models/songs.dart';

import 'package:shimmer/shimmer.dart';

class RecommendationsScreen extends StatefulWidget {
  final Song currentSong;
  final TavilyService tavilyService;

  const RecommendationsScreen({
    required this.currentSong,
    required this.tavilyService,
  });

  @override
  _RecommendationsScreenState createState() => _RecommendationsScreenState();
}

class _RecommendationsScreenState extends State<RecommendationsScreen> {
  List<MusicRecommendation> recommendations = [];
  bool isLoading = true;
  bool isError = false;
  String? researchContent;

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

      // Try quick search first
      final quickResult = await widget.tavilyService.quickMusicSearch(
        "${widget.currentSong.title} by ${widget.currentSong.primaryArtists ?? 'Unknown Artist'}",
      );

      if (quickResult.containsKey('answer') ||
          quickResult.containsKey('results')) {
        final parsedRecs = widget.tavilyService.parseMusicRecommendations(
          quickResult,
        );

        setState(() {
          recommendations = parsedRecs;
          researchContent =
              quickResult['answer'] ?? quickResult['content']?.toString();
          isLoading = false;
        });

        // Start background research for more detailed info
        // _startDetailedResearch();
      } else {
        setState(() {
          isError = true;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching recommendations: $e');
      setState(() {
        isError = true;
        isLoading = false;
      });
    }
  }

  Future<void> _startDetailedResearch() async {
    try {
      final requestId = await widget.tavilyService.startMusicResearch(
        "Detailed music analysis of '${widget.currentSong.title}' by ${widget.currentSong.primaryArtists ?? 'Unknown Artist'}: "
        "Include similar artists, songs from same genre, cultural impact, awards, and critical reception",
      );

      if (requestId != null) {
        // Poll for results (simplified - in real app, use proper async handling)
        await Future.delayed(Duration(seconds: 5));

        final result = await widget.tavilyService.getResearchResult(requestId);

        if (result['status'] == 'completed') {
          final detailedRecs = widget.tavilyService.parseMusicRecommendations(
            result,
          );

          setState(() {
            // Merge with existing recommendations
            final existingTitles = recommendations.map((r) => r.title).toSet();
            for (var rec in detailedRecs) {
              if (!existingTitles.contains(rec.title)) {
                recommendations.add(rec);
              }
            }
            researchContent = result['content']?.toString();
          });
        }
      }
    } catch (e) {
      print('Background research error: $e');
      // Fail silently - we already have quick results
    }
  }

  Widget _buildRecommendationCard(MusicRecommendation recommendation) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.music_note, color: Colors.green),
        ),
        title: Text(
          recommendation.title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          recommendation.description,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.play_arrow, color: Colors.green),
        onTap: () {
          Navigator.pop(context, {
            'title': recommendation.title,
            'description': recommendation.description,
            'isRecommendation': true,
          });
        },
      ),
    );
  }

  void _searchRecommendation(MusicRecommendation recommendation) {
    Navigator.pop(context, recommendation.title);
  }

  Widget _buildShimmerCard() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        title: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(height: 20, width: 200, color: Colors.white),
        ),
        subtitle: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 15,
            width: 150,
            color: Colors.white,
            margin: EdgeInsets.only(top: 8),
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
          "Recommendations",
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
              ? ListView.builder(
                padding: EdgeInsets.only(top: 16),
                itemCount: 6,
                itemBuilder: (context, index) => _buildShimmerCard(),
              )
              : isError
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Couldn't load recommendations",
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Check your internet connection",
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                    SizedBox(height: 20),
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
              : Column(
                children: [
                  // Current song info
                  Container(
                    padding: EdgeInsets.all(16),
                    color: Colors.green[50],
                    child: Row(
                      children: [
                        widget.currentSong.images.isNotEmpty
                            ? Image.network(
                              widget.currentSong.images.first.url,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                            )
                            : Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[200],
                              child: Icon(Icons.music_note),
                            ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Based on:",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                widget.currentSong.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (widget.currentSong.primaryArtists != null)
                                Text(
                                  widget.currentSong.primaryArtists!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Recommendations count
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.recommend, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          "${recommendations.length} Recommendations Found",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Categories tabs
                  Container(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      children:
                          ['All']
                              .map(
                                (category) => Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: FilterChip(
                                    label: Text(category),
                                    selected: category == 'All',
                                    onSelected: (selected) {
                                      // Filter logic would go here
                                    },
                                    backgroundColor:
                                        category == 'All'
                                            ? Colors.green[100]
                                            : Colors.grey[200],
                                    selectedColor: Colors.green[300],
                                    labelStyle: TextStyle(
                                      color:
                                          category == 'All'
                                              ? Colors.green[800]
                                              : Colors.grey[700],
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),

                  // Recommendations list
                  Expanded(
                    child:
                        recommendations.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.music_off,
                                    size: 80,
                                    color: Colors.grey[300],
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    "No recommendations found",
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : ListView.builder(
                              padding: EdgeInsets.only(top: 8, bottom: 16),
                              itemCount: recommendations.length,
                              itemBuilder:
                                  (context, index) => _buildRecommendationCard(
                                    recommendations[index],
                                  ),
                            ),
                  ),
                ],
              ),
    );
  }
}
