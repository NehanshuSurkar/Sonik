// lib/utils/text_utils.dart
import 'package:html/parser.dart' show parseFragment;

class TextUtils {
  /// Decode HTML entities like &quot; &amp; &apos; etc.
  static String decodeHtmlEntities(String text) {
    if (text.isEmpty) return text;

    try {
      // Using html parser to decode entities
      final document = parseFragment(text);
      return document.text?.trim() ?? text;
    } catch (e) {
      // Fallback: manual replacement if parser fails
      return text
          .replaceAll('&quot;', '"')
          .replaceAll('&amp;', '&')
          .replaceAll('&apos;', "'")
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&copy;', '©')
          .replaceAll('&reg;', '®')
          .replaceAll('&euro;', '€')
          .replaceAll('&pound;', '£')
          .replaceAll('&yen;', '¥');
    }
  }

  /// Clean song title by removing extra brackets and formatting
  static String cleanSongTitle(String title) {
    if (title.isEmpty) return title;

    // First decode HTML entities
    String clean = decodeHtmlEntities(title);

    // Remove common patterns like "(From "Something")"
    clean = clean.replaceAll(RegExp(r'\s*\(From "[^"]+"\)\s*'), ' ');
    clean = clean.replaceAll(RegExp(r'\s*\(From [^)]+\)\s*'), ' ');

    // Remove multiple spaces
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();

    return clean;
  }

  /// Clean artist name
  static String cleanArtistName(String artist) {
    if (artist == null || artist.isEmpty) return artist;

    // Decode HTML entities
    String clean = decodeHtmlEntities(artist);

    // Remove any bracketed content if needed
    clean = clean.replaceAll(RegExp(r'\s*\([^)]+\)\s*'), ' ').trim();

    return clean;
  }
}
