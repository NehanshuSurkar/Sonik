import 'package:just_audio/just_audio.dart';

class MusicPlayerService {
  static final MusicPlayerService _instance = MusicPlayerService._internal();
  factory MusicPlayerService() => _instance;
  MusicPlayerService._internal() {
    _initPlayer();
  }

  final AudioPlayer player = AudioPlayer();
  bool _isInitialized = false;
  bool _isDisposed = false;
  void _initPlayer() {
    if (_isInitialized) return;
    _isDisposed = false;

    player.playbackEventStream.listen(
      (event) {
        print("🎵 Playback Event: ProcessingState: ${event.processingState}");
      },
      onError: (error) {
        print("🎵 Playback Error: $error");
      },
    );

    player.playerStateStream.listen((state) {
      print(
        "🎵 Player State: ${state.processingState} - Playing: ${state.playing}",
      );
    });

    _isInitialized = true;
  }

  Future<void> playSong(String url) async {
    try {
      print("🎵 Attempting to play URL: $url");

      // Check if URL is valid
      if (!url.startsWith('http')) {
        throw Exception('Invalid URL format: $url');
      }
      await player.stop();

      await Future.delayed(Duration(milliseconds: 100));

      // Create a proper audio source
      final audioSource = AudioSource.uri(
        Uri.parse(url),
        tag: AudioMetadata(
          title: 'Playing from App library',
          album: 'Music App',
          artist: 'Unknown Artist',
        ),
      );

      print("🎵 Setting audio source...");
      await player.setAudioSource(audioSource);

      print("🎵 Preparing player...");
      await player.setLoopMode(LoopMode.off);

      print("🎵 Starting playback...");
      await player.play();

      print("✅ Playback started successfully!");
    } catch (e, stackTrace) {
      print("❌ Error playing song: $e");
      print("Stack trace: $stackTrace");
      rethrow;
    }
  }

  Future<void> play() async {
    try {
      await player.play();
    } catch (e) {
      print("Play error: $e");
    }
  }

  void pause() {
    try {
      player.pause();
    } catch (e) {
      print("Pause error: $e");
    }
  }

  void stop() {
    try {
      player.stop();
    } catch (e) {
      print("Stop error: $e");
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await player.seek(position);
    } catch (e) {
      print("Seek error: $e");
    }
  }

  Future<void> dispose() async {
    if (!_isDisposed) {
      _isDisposed = true;
      _isInitialized = false;
      await player.dispose();
    }
  }

  bool get isDisposed => _isDisposed;
}

// Simple metadata class
class AudioMetadata {
  final String title;
  final String album;
  final String artist;

  AudioMetadata({
    required this.title,
    required this.album,
    required this.artist,
  });
}
