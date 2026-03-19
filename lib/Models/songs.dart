import 'package:rythmx/Utils/text_utils.dart';

class Song {
  String id;
  String title;
  String album;
  String? url;
  String? description;
  String? primaryArtists;
  String? singers;
  String? language;
  List<SongImage> images;
  List<DownloadUrl>? downloadUrls;
  int? duration;
  List<String>? similarArtists;
  List<String>? similarSongs;
  List<String>? genres;
  String? recommendationInfo;

  Song({
    required this.id,
    required this.title,
    required this.album,
    this.url,
    this.description,
    this.primaryArtists,
    this.singers,
    this.language,
    required this.images,
    this.downloadUrls,
    this.duration,
    this.similarArtists,
    this.similarSongs,
    this.genres,
    this.recommendationInfo,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    List<SongImage> imageList = [];
    if (json['image'] is List) {
      imageList = List<SongImage>.from(
        json['image'].map((x) => SongImage.fromJson(x)),
      );
    } else if (json['image'] is Map) {
      imageList = [SongImage.fromJson(json['image'])];
    }

    // Handle downloadUrls
    List<DownloadUrl>? downloadUrlList;
    if (json['downloadUrl'] != null && json['downloadUrl'] is List) {
      downloadUrlList = List<DownloadUrl>.from(
        json['downloadUrl'].map((x) => DownloadUrl.fromJson(x)),
      );
    }

    List<String>? genres;
    if (json['genre'] != null) {
      if (json['genre'] is List) {
        genres = List<String>.from(json['genre']);
      } else if (json['genre'] is String) {
        genres = [json['genre']];
      }
    }
    // Get raw values
    String rawTitle = json['title'] ?? json['name'] ?? '';
    String rawAlbum =
        json['album'] is String
            ? json['album']
            : (json['album']?['name'] ?? '');
    String rawArtists =
        json['primaryArtists'] ??
        (json['artists']?['primary']?[0]?['name'] ?? '');

    return Song(
      id: json['id'] ?? '',
      title: TextUtils.cleanSongTitle(rawTitle),
      // json['title'] ??
      // json['name'] ??
      // '', // Support both 'title' and 'name'
      album: TextUtils.cleanSongTitle(rawAlbum),
      url: json['url'],
      description: json['description'],
      //     json['album'] is String
      //         ? json['album']
      //         : (json['album']?['name'] ?? ''),
      // url: json['url'],
      // description: json['description'],
      primaryArtists: TextUtils.cleanArtistName(rawArtists),
      // json['primaryArtists'] ??
      // (json['artists']?['primary']?[0]?['name'] ?? ''),
      singers:
          json['singers'] != null
              ? TextUtils.cleanArtistName(json['singers'])
              : null,
      language: json['language'],
      images: imageList,
      downloadUrls: downloadUrlList,
      duration: json['duration'],
      genres: genres,
    );
  }
}

class SongImage {
  String quality;
  String url;

  SongImage({required this.quality, required this.url});

  factory SongImage.fromJson(Map<String, dynamic> json) =>
      SongImage(quality: json['quality'] ?? '', url: json['url'] ?? '');
}

class DownloadUrl {
  String quality;
  String url;

  DownloadUrl({required this.quality, required this.url});

  factory DownloadUrl.fromJson(Map<String, dynamic> json) =>
      DownloadUrl(quality: json['quality'] ?? '', url: json['url'] ?? '');
}
