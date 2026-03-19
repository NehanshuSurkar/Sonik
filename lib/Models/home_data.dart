// lib/models/home_data.dart
import 'package:rythmx/Models/songs.dart';

class HomeSection {
  final String title;
  final String subtitle;
  final List<HomeItem> items;
  final SectionType type;

  HomeSection({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.type,
  });
}

enum SectionType {
  trending,
  newReleases,
  featuredPlaylists,
  popularArtists,
  recommendedForYou,
  topCharts,
}

class HomeItem {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final ItemType type;
  final dynamic data; // Can be Song, Artist, Playlist, etc.

  HomeItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.type,
    this.data,
  });
}

enum ItemType { song, artist, playlist, album }

class Artist {
  final String id;
  final String name;
  final String imageUrl;
  final String? genre;
  final int? songCount;

  Artist({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.genre,
    this.songCount,
  });
}

class Playlist {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final int songCount;
  final List<Song> songs;

  Playlist({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.songCount,
    required this.songs,
  });
}
