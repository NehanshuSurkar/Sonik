import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:rythmx/Screens/recommendations_screen.dart';
import 'package:rythmx/Services/autoplay_service.dart';
import 'package:rythmx/Services/tavily_service.dart';
import 'package:rythmx/Models/music_player.dart';
import 'package:rythmx/Models/songs.dart';
import 'package:rythmx/Services/api_service.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

// ==================== PlaybackQueue Class ====================
class PlaybackQueue {
  List<Song> _queue = [];
  int _currentIndex = -1;

  void addToQueue(Song song) {
    _queue.add(song);
  }

  void addToQueueNext(Song song) {
    if (_currentIndex == -1) {
      _queue.add(song);
    } else {
      _queue.insert(_currentIndex + 1, song);
    }
  }

  void setQueue(List<Song> songs, {int startIndex = 0}) {
    _queue = List.from(songs);
    _currentIndex = startIndex;
  }

  void clearQueue() {
    _queue.clear();
    _currentIndex = -1;
  }

  Song? getCurrentSong() {
    if (_currentIndex >= 0 && _currentIndex < _queue.length) {
      return _queue[_currentIndex];
    }
    return null;
  }

  Song? getNextSong() {
    if (_currentIndex < _queue.length - 1) {
      return _queue[_currentIndex + 1];
    }
    return null;
  }

  Song? getPreviousSong() {
    if (_currentIndex > 0) {
      return _queue[_currentIndex - 1];
    }
    return null;
  }

  bool moveToNext() {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      return true;
    }
    return false;
  }

  bool moveToPrevious() {
    if (_currentIndex > 0) {
      _currentIndex--;
      return true;
    }
    return false;
  }

  List<Song> getQueue() => List.from(_queue);
  int getCurrentIndex() => _currentIndex;

  void removeFromQueue(int index) {
    if (index >= 0 && index < _queue.length) {
      if (index < _currentIndex) {
        _currentIndex--;
      } else if (index == _currentIndex) {
        _queue.removeAt(index);
        if (_queue.isNotEmpty && _currentIndex >= _queue.length) {
          _currentIndex = _queue.length - 1;
        }
      } else {
        _queue.removeAt(index);
      }
    }
  }
}

// ==================== END OF CLASS ====================

class SearchScreen extends StatefulWidget {
  final MusicPlayerService playerService;

  const SearchScreen({Key? key, required this.playerService}) : super(key: key);

  @override
  SearchScreenState createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  final controller = TextEditingController();
  List<Song> songs = [];
  bool isLoading = false;
  final PlaybackQueue queue = PlaybackQueue();

  final TavilyService tavilyService = TavilyService(
    apiKey: "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",
  );

  // Player control variables
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isPlayerReady = false;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;
  late AutoPlayService autoPlayService;
  bool _autoPlayEnabled = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    autoPlayService = AutoPlayService(
      apiService: ApiService(),
      onPlaySong: (song) => playSong(song),
    );

    _initPlayerListeners();

    // Listen for song completion and state changes
    _playerStateSubscription = widget.playerService.player.playerStateStream.listen(
      (state) {
        print(
          "🎵 Player State Update - Processing: ${state.processingState}, Playing: ${state.playing}",
        );
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            if (state.processingState == ProcessingState.ready) {
              _isPlayerReady = true;
            }
          });
        }

        if (state.processingState == ProcessingState.completed) {
          print("🎵 Song completed, triggering auto-play");
          if (_autoPlayEnabled) {
            autoPlayService.onSongEnded();
          } else {
            _playNextInQueue();
          }
        }
      },
      onError: (error) {
        print("🎵 Player State Error: $error");
      },
      cancelOnError: false,
    );
  }

  // ==================== Snackbars ====================
  void _showSuccessSnackBar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: Duration(seconds: 2),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void skipToNext() {
    _skipToNext();
  }

  void skipToPrevious() {
    _skipToPrevious();
  }

  void _showInfoSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: Duration(seconds: 2),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  // ==================== Player Listeners ====================
  void _initPlayerListeners() {
    _durationSubscription = widget.playerService.player.durationStream.listen(
      (duration) {
        if (mounted) {
          setState(() {
            _duration = duration ?? Duration.zero;
          });
        }
      },
      onError: (error) {
        print("Duration stream error: $error");
      },
    );

    _positionSubscription = widget.playerService.player.positionStream.listen((
      position,
    ) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _playerStateSubscription = widget.playerService.player.playerStateStream
        .listen(
          (state) {
            if (mounted) {
              setState(() {
                _isPlaying = state.playing;
              });
            }
          },
          onError: (error) {
            print("Position stream error: $error");
          },
        );
  }

  // ==================== Search Function ====================
  Future<void> search(String query) async {
    if (query.isEmpty) {
      setState(() => songs = []);
      return;
    }
    setState(() {
      isLoading = true;
      songs = [];
    });

    try {
      final results = await ApiService().searchSongs(query);
      print("🔍 Found ${results.length} songs for '$query'");

      if (mounted) {
        setState(() {
          songs = results;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      print("Search error: $e");
    }
  }

  // ==================== Play Song Function ====================
  // Future<void> _downloadCurrentSong() async {
  //   final currentSong = queue.getCurrentSong();
  //   if (currentSong == null) {
  //     _showErrorSnackBar("No song playing", Icons.error);
  //     return;
  //   }

  //   // Show loading indicator
  //   _showInfoSnackBar("Preparing download...", Icons.downloading, Colors.blue);

  //   String? downloadUrl;
  //   if (currentSong.downloadUrls != null &&
  //       currentSong.downloadUrls!.isNotEmpty) {
  //     downloadUrl = currentSong.downloadUrls!.last.url;
  //   } else {
  //     downloadUrl = await ApiService().fetchAudioUrl(currentSong.id);
  //   }

  //   if (downloadUrl == null) {
  //     _showErrorSnackBar("No download URL available", Icons.error);
  //     return;
  //   }

  //   // Handle permissions based on Android version
  //   bool permissionGranted = false;

  //   try {
  //     if (await Permission.storage.isGranted) {
  //       permissionGranted = true;
  //     } else {
  //       // Request permission and wait for result
  //       PermissionStatus status = await Permission.storage.request();
  //       permissionGranted = status.isGranted;

  //       if (status.isPermanentlyDenied) {
  //         // User permanently denied permission - open app settings
  //         _showPermissionDialog();
  //         return;
  //       }
  //     }
  //   } catch (e) {
  //     print("Permission check error: $e");
  //     // For Android 13+, we might need different permissions
  //     if (await Permission.manageExternalStorage.isGranted) {
  //       permissionGranted = true;
  //     } else {
  //       PermissionStatus status =
  //           await Permission.manageExternalStorage.request();
  //       permissionGranted = status.isGranted;
  //     }
  //   }

  //   if (!permissionGranted) {
  //     _showPermissionDialog();
  //     return;
  //   }

  //   // Proceed with download
  //   await _startDownload(downloadUrl, currentSong);
  // }

  // void _showPermissionDialog() {
  //   showDialog(
  //     context: context,
  //     builder:
  //         (context) => AlertDialog(
  //           title: Row(
  //             children: [
  //               Icon(Icons.warning, color: Colors.orange),
  //               SizedBox(width: 8),
  //               Text('Storage Permission'),
  //             ],
  //           ),
  //           content: Text(
  //             'Storage permission is needed to download songs. '
  //             'Please grant permission in app settings.',
  //             style: TextStyle(fontSize: 16, color: Colors.grey[800]),
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.pop(context),
  //               child: Text(
  //                 'Cancel',
  //                 style: TextStyle(
  //                   color: Colors.grey[700],
  //                   fontWeight: FontWeight.bold,
  //                 ),
  //               ),
  //             ),
  //             ElevatedButton(
  //               style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
  //               onPressed: () {
  //                 Navigator.pop(context);
  //                 openAppSettings(); // Open app settings
  //               },
  //               child: Text(
  //                 'Open Settings',
  //                 style: TextStyle(color: Colors.white),
  //               ),
  //             ),
  //           ],
  //         ),
  //   );
  // }

  // Future<void> _startDownload(String url, Song song) async {
  //   try {
  //     // Get download directory
  //     final directory = await getExternalStorageDirectory();
  //     String downloadsDir;

  //     if (directory != null) {
  //       downloadsDir = directory.path;
  //     } else {
  //       // Fallback to public Download folder
  //       downloadsDir = '/storage/emulated/0/Download';
  //     }

  //     // Create a safe filename
  //     String artistPart =
  //         song.primaryArtists != null ? " - ${song.primaryArtists}" : "";

  //     String fileName = "${song.title}$artistPart.mp3"
  //         .replaceAll(RegExp(r'[<>:"/\\|?*]'), '') // Remove invalid characters
  //         .replaceAll(
  //           RegExp(r'\s+'),
  //           ' ',
  //         ); // Replace multiple spaces with single space

  //     print("Downloading to: $downloadsDir/$fileName");
  //     print("URL: $url");

  //     // Enqueue download
  //     final taskId = await FlutterDownloader.enqueue(
  //       url: url,
  //       savedDir: downloadsDir,
  //       fileName: fileName,
  //       showNotification: true,
  //       openFileFromNotification: true,
  //     );

  //     if (taskId != null) {
  //       _showSuccessSnackBar(
  //         "Download started: ${song.title}",
  //         Icons.download_done,
  //       );

  //       // Optionally track download progress
  //       FlutterDownloader.registerCallback((id, status, progress) {
  //         print("Download $id: $status - $progress%");
  //         if (status == DownloadTaskStatus.complete && mounted) {
  //           _showSuccessSnackBar(
  //             "Download complete: ${song.title}",
  //             Icons.check_circle,
  //           );
  //         }
  //       });
  //     } else {
  //       _showErrorSnackBar("Failed to start download", Icons.error);
  //     }
  //   } catch (e) {
  //     print("Download error: $e");
  //     _showErrorSnackBar("Download failed: ${e.toString()}", Icons.error);
  //   }
  // }
  // -------------------------------------------------------------------
  // Future<void> _downloadCurrentSong() async {
  //   final currentSong = queue.getCurrentSong();
  //   if (currentSong == null) {
  //     _showErrorSnackBar("No song playing", Icons.error);
  //     return;
  //   }

  //   _showInfoSnackBar(
  //     "Downloading ${currentSong.title}...",
  //     Icons.downloading,
  //     Colors.blue,
  //   );

  //   String? downloadUrl;
  //   if (currentSong.downloadUrls != null &&
  //       currentSong.downloadUrls!.isNotEmpty) {
  //     downloadUrl = currentSong.downloadUrls!.last.url;
  //   } else {
  //     downloadUrl = await ApiService().fetchAudioUrl(currentSong.id);
  //   }

  //   if (downloadUrl == null) {
  //     _showErrorSnackBar("No download URL available", Icons.error);
  //     return;
  //   }

  //   try {
  //     // Save to app's documents directory (NO PERMISSION NEEDED)
  //     final directory = await getApplicationDocumentsDirectory();

  //     // Create a safe filename
  //     String artistPart =
  //         currentSong.primaryArtists != null
  //             ? " - ${currentSong.primaryArtists}"
  //             : "";

  //     String fileName = "${currentSong.title}$artistPart.mp3"
  //         .replaceAll(RegExp(r'[<>:"/\\|?*]'), '') // Remove invalid characters
  //         .replaceAll(
  //           RegExp(r'\s+'),
  //           ' ',
  //         ); // Replace multiple spaces with single space

  //     final filePath = '${directory.path}/$fileName';

  //     print("📥 Downloading to: $filePath");
  //     print("📥 From URL: $downloadUrl");

  //     // Download the file
  //     var httpClient = http.Client();
  //     var request = http.Request('GET', Uri.parse(downloadUrl));
  //     var response = await httpClient.send(request);

  //     if (response.statusCode != 200) {
  //       throw Exception("Failed to download: ${response.statusCode}");
  //     }

  //     var file = File(filePath);
  //     var sink = file.openWrite();

  //     await response.stream.pipe(sink);
  //     await sink.flush();
  //     await sink.close();
  //     httpClient.close();

  //     print("✅ Download complete: $filePath");

  //     _showSuccessSnackBar(
  //       "Downloaded: ${currentSong.title}",
  //       Icons.download_done,
  //     );
  //   } catch (e) {
  //     print("❌ Download error: $e");
  //     _showErrorSnackBar("Download failed: ${e.toString()}", Icons.error);
  //   }
  // }

  void _showDownloadsFolder() async {
    final directory = Directory('/storage/emulated/0/Download/RythmX');

    if (!await directory.exists()) {
      _showInfoSnackBar("No downloads yet", Icons.info, Colors.blue);
      return;
    }

    final files = directory.listSync();
    final audioFiles =
        files
            .where(
              (file) =>
                  file.path.endsWith('.mp3') || file.path.endsWith('.m4a'),
            )
            .toList();

    if (audioFiles.isEmpty) {
      _showInfoSnackBar("No downloaded songs", Icons.info, Colors.blue);
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.download_done, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Downloaded Songs',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                itemCount: audioFiles.length,
                itemBuilder: (context, index) {
                  final file = audioFiles[index];
                  final fileName = file.path.split('/').last;

                  return ListTile(
                    leading: Icon(Icons.audio_file, color: Colors.green),
                    title: Text(
                      fileName.replaceAll('.mp3', ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('In Downloads/RythmX'),
                    trailing: IconButton(
                      icon: Icon(Icons.folder_open, color: Colors.blue),
                      onPressed: () async {
                        // Open the folder containing the file
                        // You can use the open_file package
                      },
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: TextStyle(color: Colors.grey[700], fontSize: 16),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _downloadCurrentSong() async {
    final currentSong = queue.getCurrentSong();
    if (currentSong == null) {
      _showErrorSnackBar("No song playing", Icons.error);
      return;
    }

    _showInfoSnackBar("Preparing download...", Icons.downloading, Colors.blue);

    String? downloadUrl;
    if (currentSong.downloadUrls != null &&
        currentSong.downloadUrls!.isNotEmpty) {
      downloadUrl = currentSong.downloadUrls!.last.url;
    } else {
      downloadUrl = await ApiService().fetchAudioUrl(currentSong.id);
    }

    if (downloadUrl == null) {
      _showErrorSnackBar("No download URL available", Icons.error);
      return;
    }

    // Check and request permissions
    bool hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      _showPermissionDialog();
      return;
    }

    try {
      // Get public Downloads directory
      final directory = Directory('/storage/emulated/0/Download/RythmX');

      // Create app folder if it doesn't exist
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Create a safe filename
      String artistPart =
          currentSong.primaryArtists != null
              ? " - ${currentSong.primaryArtists}"
              : "";

      // Clean filename - remove invalid characters
      String fileName = "${currentSong.title}$artistPart.mp3"
          .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
          .replaceAll(RegExp(r'\s+'), ' ');

      final filePath = '${directory.path}/$fileName';

      // Check if file already exists
      if (File(filePath).existsSync()) {
        // Show option to overwrite
        bool overwrite = await _showOverwriteDialog(fileName);
        if (!overwrite) {
          return;
        }
      }

      _showInfoSnackBar(
        "Downloading ${currentSong.title}...",
        Icons.downloading,
        Colors.blue,
      );

      print("📥 Downloading to: $filePath");
      print("📥 From URL: $downloadUrl");

      // Download the file
      var httpClient = http.Client();
      var request = http.Request('GET', Uri.parse(downloadUrl));
      var response = await httpClient.send(request);

      if (response.statusCode != 200) {
        throw Exception("Failed to download: ${response.statusCode}");
      }

      var file = File(filePath);
      var sink = file.openWrite();

      await response.stream.pipe(sink);
      await sink.flush();
      await sink.close();
      httpClient.close();

      print("✅ Download complete: $filePath");

      // Make file visible to media scanner (Android)
      if (Platform.isAndroid) {
        await _scanFile(filePath);
      }

      _showSuccessSnackBar(
        "Downloaded to Downloads/RythmX folder",
        Icons.download_done,
      );
    } catch (e) {
      print("❌ Download error: $e");
      _showErrorSnackBar("Download failed: ${e.toString()}", Icons.error);
    }
  }

  // Request storage permission based on Android version
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+)
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }

      if (await Permission.storage.isGranted) {
        return true;
      }

      // For Android 11+ (API 30+)
      if (await Permission.manageExternalStorage.request().isGranted) {
        return true;
      }

      // For older Android versions
      PermissionStatus status = await Permission.storage.request();
      return status.isGranted;
    }
    return false; // iOS handling if needed
  }

  // Show permission dialog
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('Storage Permission'),
              ],
            ),
            content: Text(
              'Storage permission is needed to save songs to your Downloads folder.\n\n'
              'Please grant permission in app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  // Show overwrite dialog
  Future<bool> _showOverwriteDialog(String fileName) async {
    return await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('File already exists'),
                content: Text('$fileName already exists. Overwrite?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('No'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('Yes'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  // Scan file to make it visible in file manager (Android)
  Future<void> _scanFile(String filePath) async {
    try {
      if (Platform.isAndroid) {
        // Using MediaScannerConnection on Android
        final result = await _mediaScannerScanFile(filePath);
        print("📱 Media scan result: $result");
      }
    } catch (e) {
      print("Media scan error: $e");
    }
  }

  // Method to trigger media scanner
  Future<bool> _mediaScannerScanFile(String path) async {
    // This uses a platform channel to trigger media scanner
    // You can also use the device_info_plus package to handle this
    try {
      // Alternative: Use the share_plus package which includes media scanning
      // For now, just return true as the file will be visible after reboot
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> playSong(Song song) async {
    print("🎵 Tapped song: ${song.title} (ID: ${song.id})");

    final currentSong = queue.getCurrentSong();

    // Check if this song is the same as currently playing
    if (currentSong?.id == song.id) {
      if (_isPlaying) {
        widget.playerService.pause();
        print("⏸️ Paused current song");
        if (mounted) setState(() {});
      } else {
        await widget.playerService.play();
        print("▶️ Resumed current song");
        if (mounted) setState(() {});
      }
      return;
    }

    // Set new queue starting with this song
    queue.setQueue([song]);

    if (mounted) setState(() {});

    _showInfoSnackBar(
      "Loading ${song.title}...",
      Icons.downloading,
      Colors.green[700]!,
    );

    // First check if song has direct download URLs
    if (song.downloadUrls != null && song.downloadUrls!.isNotEmpty) {
      print("🎵 Available qualities for ${song.title}:");
      for (var dl in song.downloadUrls!) {
        print("   • ${dl.quality}");
      }
      print("🎯 Selected: ${song.downloadUrls!.last.quality}");

      var audioUrl = song.downloadUrls!.last.url;

      bool success = await _playAudioUrl(audioUrl, song);

      if (success && _autoPlayEnabled && mounted) {
        print("🎵 Notifying auto-play service: song started");
        await autoPlayService.onSongStarted(song);
      }
    } else {
      // Otherwise fetch from API
      print("🔗 Fetching audio URL from API...");
      final audioUrl = await ApiService().fetchAudioUrl(song.id);

      if (audioUrl != null) {
        bool success = await _playAudioUrl(audioUrl, song);

        if (success && _autoPlayEnabled && mounted) {
          print("🎵 Notifying auto-play service: song started");
          await autoPlayService.onSongStarted(song);
          _refreshQueueUI();
        }
      } else {
        print("❌ No audio URL found");
        if (mounted) {
          setState(() => queue.clearQueue());
          _showErrorSnackBar(
            "No audio available for ${song.title}",
            Icons.error_outline,
          );
        }
      }
    }
  }

  Future<bool> _playAudioUrl(String url, Song song) async {
    print("▶️ Playing URL: $url");

    try {
      await widget.playerService.playSong(url);
      print("✅ Playback started successfully!");

      // Force UI update after playback starts
      if (mounted) {
        setState(() {
          _isPlayerReady = true;
        });
      }

      return true;
    } catch (e) {
      print("❌ Playback error: $e");
      if (mounted) {
        setState(() => queue.clearQueue());
        _showErrorSnackBar(
          "Error playing ${song.title}",
          Icons.warning_amber_rounded,
        );
      }
      return false;
    }
  }

  void _refreshQueueUI() {
    if (mounted) {
      setState(() {});
    }
  }

  // ==================== Auto-play controls ====================
  void _toggleAutoPlay() {
    setState(() {
      _autoPlayEnabled = !_autoPlayEnabled;
      autoPlayService.setEnabled(_autoPlayEnabled);
    });

    _showInfoSnackBar(
      _autoPlayEnabled ? "Auto-play enabled " : "Auto-play disabled",
      _autoPlayEnabled ? Icons.auto_awesome : Icons.auto_awesome_outlined,
      _autoPlayEnabled ? Colors.green : Colors.grey,
    );
  }

  void _showAutoPlayQueue() {
    final queue = autoPlayService.getQueue();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.playlist_play, color: Colors.green),
                SizedBox(width: 8),
                Text('Up Next (Auto-play)'),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              child:
                  queue.isEmpty
                      ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No upcoming songs'),
                        ),
                      )
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: queue.length,
                        itemBuilder: (context, index) {
                          final song = queue[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green[300],
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                            title: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              song.primaryArtists ?? 'Unknown',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.green[300],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // ==================== Queue controls ====================
  Future<void> addToQueue(Song song) async {
    queue.addToQueue(song);
    if (mounted) setState(() {});

    _showInfoSnackBar(
      "Added ${song.title} to queue",
      Icons.queue_music,
      Colors.teal[600]!,
    );
  }

  Future<void> addToQueueNext(Song song) async {
    queue.addToQueueNext(song);
    if (mounted) setState(() {});

    _showInfoSnackBar(
      "${song.title} will play next",
      Icons.queue_play_next,
      Colors.blue[600]!,
    );
  }

  void _playNextInQueue() async {
    if (queue.moveToNext()) {
      final nextSong = queue.getCurrentSong();
      if (nextSong != null) {
        await _playSongFromQueue(nextSong);
      }
    } else {
      if (mounted) setState(() {});
    }
  }

  Future<void> _playSongFromQueue(Song song) async {
    print("🎵 Playing from queue: ${song.title}");

    if (mounted) setState(() {});

    if (song.downloadUrls != null && song.downloadUrls!.isNotEmpty) {
      var audioUrl = song.downloadUrls!.last.url;
      await _playAudioUrl(audioUrl, song);
      return;
    }

    final audioUrl = await ApiService().fetchAudioUrl(song.id);

    if (audioUrl != null) {
      await _playAudioUrl(audioUrl, song);
    } else {
      print("❌ No audio URL found for queued song");
      _playNextInQueue();
    }
  }

  // ==================== Navigation controls ====================
  void _skipToNext() {
    if (!_autoPlayEnabled) {
      _playNextInQueue();
      return;
    }

    final autoPlayQueue = autoPlayService.getQueue();
    if (autoPlayQueue.isNotEmpty) {
      final nextSong = autoPlayQueue.first;
      print("🎵 Skipping to next from auto-play queue: ${nextSong.title}");
      playSong(nextSong);
    } else {
      print("🎵 Auto-play queue empty, checking regular queue");
      if (queue.getQueue().length > queue.getCurrentIndex() + 1) {
        _playNextInQueue();
      } else {
        _showInfoSnackBar("No more songs in queue", Icons.info, Colors.orange);
      }
    }
  }

  void _skipToPrevious() {
    final currentPosition = widget.playerService.player.position;
    if (currentPosition > Duration(seconds: 3)) {
      widget.playerService.player.seek(Duration.zero);
      _showInfoSnackBar("Restarting song", Icons.replay, Colors.grey);
      return;
    }

    if (!_autoPlayEnabled) {
      if (queue.moveToPrevious()) {
        final prevSong = queue.getCurrentSong();
        if (prevSong != null) {
          _playSongFromQueue(prevSong);
        }
      }
      return;
    }

    widget.playerService.player.seek(Duration.zero);
    _showInfoSnackBar("Restarting current song", Icons.replay, Colors.grey);
  }

  // ==================== Helper Functions ====================
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  void _seekToPosition(Duration position) {
    widget.playerService.player.seek(position);
  }

  void _showQueueDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Playback Queue',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Container(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: queue.getQueue().length,
                itemBuilder: (context, index) {
                  final song = queue.getQueue()[index];
                  final isCurrent = index == queue.getCurrentIndex();

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          isCurrent ? Colors.green : Colors.grey[300],
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isCurrent ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    title: Text(
                      song.title,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      song.primaryArtists ?? 'Unknown',
                      style: TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.close, size: 18),
                          onPressed: () {
                            queue.removeFromQueue(index);
                            if (mounted) setState(() {});
                          },
                        ),
                        if (isCurrent)
                          Icon(Icons.equalizer, color: Colors.green)
                        else
                          IconButton(
                            icon: Icon(Icons.play_arrow, size: 20),
                            onPressed: () {
                              queue.setQueue(
                                queue.getQueue(),
                                startIndex: index,
                              );
                              _playSongFromQueue(song);
                              Navigator.pop(context);
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  queue.clearQueue();
                  if (mounted) setState(() {});
                  Navigator.pop(context);
                },
                child: Text(
                  'Clear Queue',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  void _showRecommendations(Song song) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => RecommendationsScreen(
              currentSong: song,
              tavilyService: tavilyService,
            ),
      ),
    ).then((result) {
      if (result != null && result is Map) {
        String songTitle = result['title'];
        _showInfoSnackBar(
          "Searching for: $songTitle",
          Icons.search,
          Colors.blue,
        );
        controller.text = songTitle;
        search(songTitle).then((_) {
          _showSuccessSnackBar(
            "Found songs for: $songTitle",
            Icons.check_circle,
          );
        });
      }
    });
  }

  // ==================== UI Builders ====================
  Widget _buildPlayerUI(Song song) {
    final bool isActuallyPlaying = _isPlaying && _isPlayerReady;

    return Container(
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border(
          top: BorderSide(color: Colors.green[200] ?? Colors.green, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.green[400],
                    inactiveTrackColor: Colors.green[100],
                    thumbColor: Colors.teal[400],
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    min: 0,
                    max:
                        _duration.inSeconds.toDouble() > 0
                            ? _duration.inSeconds.toDouble()
                            : 1.0,
                    value:
                        _position.inSeconds.toDouble() >
                                _duration.inSeconds.toDouble()
                            ? _duration.inSeconds.toDouble()
                            : _position.inSeconds.toDouble(),
                    onChanged: (value) {
                      _seekToPosition(Duration(seconds: value.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 21.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: Colors.grey[200],
                        ),
                        child:
                            song.images.isNotEmpty
                                ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    song.images.first.url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(Icons.music_note, size: 20);
                                    },
                                  ),
                                )
                                : Icon(Icons.music_note, size: 20),
                      ),
                      SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                overflow: TextOverflow.ellipsis,
                              ),
                              maxLines: 1,
                            ),
                            Text(
                              song.primaryArtists ?? 'Unknown Artist',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                overflow: TextOverflow.ellipsis,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.skip_previous,
                        color: Colors.green,
                        size: 30,
                      ),
                      onPressed: _skipToPrevious,
                      tooltip: 'Previous',
                    ),
                    SizedBox(width: 4),
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                      ),
                      child: IconButton(
                        icon: Icon(
                          isActuallyPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () async {
                          if (isActuallyPlaying) {
                            widget.playerService.pause();
                          } else {
                            await widget.playerService.play();
                          }
                          if (mounted) setState(() {});
                        },
                        tooltip: isActuallyPlaying ? 'Pause' : 'Play',
                      ),
                    ),
                    SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.skip_next,
                        color: Colors.green,
                        size: 30,
                      ),
                      onPressed: _skipToNext,
                      tooltip: 'Next',
                    ),
                    SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.download, color: Colors.green, size: 28),
                      onPressed: _downloadCurrentSong,
                      tooltip: 'Download Song',
                    ),
                    IconButton(
                      icon: Icon(Icons.folder, color: Colors.orange, size: 28),
                      onPressed: _showDownloadsFolder,
                      tooltip: 'My Downloads',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Lifecycle ====================
  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();

    _durationSubscription = null;
    _positionSubscription = null;
    _playerStateSubscription = null;
    controller.dispose();
    // Don't dispose playerService here as it's managed by parent
    super.dispose();
  }

  // ==================== Build ====================
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentSong = queue.getCurrentSong();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("🎧", style: TextStyle(fontSize: 28)),
            SizedBox(width: 8),
            Text(
              "Sonik",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 27,
                letterSpacing: 1.2,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        flexibleSpace: ClipRRect(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[400]!, Colors.teal[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        elevation: 4,
        shadowColor: Colors.green[800]?.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: controller,
              onSubmitted: search,
              decoration: InputDecoration(
                hintText: "Search songs...",
                prefixIcon: Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    setState(() => songs = []);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                    color: Colors.green[200] ?? Colors.green,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                    color: Colors.green[200] ?? Colors.green,
                    width: 3,
                  ),
                ),
              ),
            ),
          ),

          if (isLoading)
            LinearProgressIndicator(
              color: Colors.green,
              backgroundColor: Colors.white,
            ),

          if (queue.getQueue().length > 1)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.green[100],
              child: Row(
                children: [
                  Icon(Icons.queue_music, size: 16, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    '${queue.getQueue().length - (queue.getCurrentIndex() + 1)} songs in queue',
                    style: TextStyle(fontSize: 12, color: Colors.green[800]),
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: _showQueueDialog,
                    child: Text('View Queue', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

          Expanded(
            child:
                songs.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.music_note,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                          SizedBox(height: 16),
                          Text(
                            "Search for songs",
                            style: TextStyle(color: Colors.grey, fontSize: 20),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: songs.length,
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        final isPlaying = currentSong?.id == song.id;

                        return Card(
                          margin: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          color: isPlaying ? Colors.green[100] : null,
                          child: ListTile(
                            leading:
                                song.images.isNotEmpty
                                    ? Image.network(
                                      song.images.first.url,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return Container(
                                          width: 50,
                                          height: 50,
                                          color: Colors.grey[200],
                                          child: Icon(Icons.music_note),
                                        );
                                      },
                                    )
                                    : Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey[200],
                                      child: Icon(Icons.music_note),
                                    ),
                            title: Text(
                              song.title,
                              style: TextStyle(
                                fontWeight:
                                    isPlaying
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(song.primaryArtists ?? 'Unknown'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert, size: 20),
                                  onSelected: (value) {
                                    if (value == 'play') {
                                      playSong(song);
                                    } else if (value == 'play_next') {
                                      addToQueueNext(song);
                                    } else if (value == 'add_to_queue') {
                                      addToQueue(song);
                                    } else if (value == 'recommendations') {
                                      _showRecommendations(song);
                                    }
                                  },
                                  itemBuilder:
                                      (context) => [
                                        PopupMenuItem(
                                          value: 'play',
                                          child: Row(
                                            children: [
                                              Icon(Icons.play_arrow, size: 20),
                                              SizedBox(width: 8),
                                              Text('Play Now'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'play_next',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.queue_play_next,
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text('Play Next'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'add_to_queue',
                                          child: Row(
                                            children: [
                                              Icon(Icons.queue_music, size: 20),
                                              SizedBox(width: 8),
                                              Text('Add to Queue'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuDivider(),
                                        PopupMenuItem(
                                          value: 'recommendations',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.recommend,
                                                size: 20,
                                                color: Colors.green,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Get Recommendations',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                ),
                                SizedBox(width: 8),
                                isPlaying
                                    ? Icon(Icons.equalizer, color: Colors.green)
                                    : IconButton(
                                      icon: Icon(Icons.play_arrow),
                                      onPressed: () => playSong(song),
                                    ),
                              ],
                            ),
                            onTap: () => playSong(song),
                          ),
                        );
                      },
                    ),
          ),

          if (currentSong != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.green[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _toggleAutoPlay,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            _autoPlayEnabled ? Colors.green : Colors.grey[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _autoPlayEnabled
                                ? Icons.auto_awesome
                                : Icons.auto_awesome_outlined,
                            color:
                                _autoPlayEnabled
                                    ? Colors.white
                                    : Colors.grey[700],
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _autoPlayEnabled ? 'Auto-play ON' : 'Auto-play OFF',
                            style: TextStyle(
                              color:
                                  _autoPlayEnabled
                                      ? Colors.white
                                      : Colors.grey[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  GestureDetector(
                    onTap: _showAutoPlayQueue,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.queue_music,
                            color: Colors.blue[700],
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Up Next',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (autoPlayService.getQueue().isNotEmpty) ...[
                            SizedBox(width: 4),
                            Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.blue[700],
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${autoPlayService.getQueue().length}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (currentSong != null) _buildPlayerUI(currentSong),
        ],
      ),
    );
  }
}
