import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../data/database/app_database.dart';
import '../../domain/entities/song.dart';

/// Single line in parsed lyrics with timestamp for synchronized playback.
class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({
    required this.timestamp,
    required this.text,
  });

  @override
  String toString() => '[${timestamp.inSeconds}s] $text';
}

/// Parsed lyrics representation containing all lines and sync metadata.
class ParsedLyrics {
  final List<LyricLine> lines;
  final bool isSynced;
  final String rawText;

  const ParsedLyrics({
    required this.lines,
    required this.isSynced,
    required this.rawText,
  });

  /// Finds the active line index for a given audio playback position.
  int getActiveIndex(Duration currentPosition) {
    if (lines.isEmpty) return 0;
    if (!isSynced) return 0;

    int activeIndex = 0;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].timestamp <= currentPosition) {
        activeIndex = i;
      } else {
        break;
      }
    }
    return activeIndex;
  }
}

/// Service that fetches online synchronized LRC and plain lyrics,
/// normalizes track metadata, reads local .lrc files, and caches results.
class OnlineLyricsService {
  static final OnlineLyricsService instance = OnlineLyricsService();

  final Map<String, ParsedLyrics> _memoryCache = {};

  static const String _lrclibBase = 'https://lrclib.net/api';
  static const String _userAgent = 'DagiPlayer/1.0 (https://github.com/dagiplayer)';

  /// Clean extraneous clutter from song titles to dramatically improve online lyrics match rate.
  static String cleanTitle(String rawTitle) {
    var title = rawTitle.trim();

    // Strip leading track numbers: e.g. "01 - ", "01. ", "1 "
    title = title.replaceAll(RegExp(r'^\d+[\s.-]+'), '');

    // Strip file extensions if present in title
    title = title.replaceAll(RegExp(r'\.(mp3|m4a|flac|wav|ogg|opus|aac)$', caseSensitive: false), '');

    // Strip (feat. XYZ) or [feat. XYZ]
    title = title.replaceAll(
      RegExp(
        r'[\(\[\{]\s*(feat\.?|ft\.?).*?[\)\]\}]',
        caseSensitive: false,
      ),
      '',
    );

    // Strip common metadata brackets/parentheses
    title = title.replaceAll(
      RegExp(
        r'[\(\[\{]\s*(official\s*(music\s*)?video|official\s*audio|lyrics?(\s*video)?|audio|remaster(ed)?(\s*\d+)?|live(\s*at\s*.*)?|deluxe(\s*edition)?|bonus\s*track|hd|4k|1080p|128kbps|256kbps|320kbps|explicit).*?[\)\]\}]',
        caseSensitive: false,
      ),
      '',
    );

    // Remove feat/ft if trailing without parentheses
    title = title.replaceAll(RegExp(r'\s+(feat\.|ft\.)\s+.*$', caseSensitive: false), '');

    // Normalize multiple spaces
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    return title.isEmpty ? rawTitle : title;
  }

  /// Clean artist string by removing featured artists for primary search query.
  static String cleanArtist(String rawArtist) {
    var artist = rawArtist.trim();
    artist = artist.replaceAll(RegExp(r'\s+(feat\.|ft\.|&|x|\/)\s+.*$', caseSensitive: false), '');
    artist = artist.replaceAll(RegExp(r'\s+'), ' ').trim();
    return artist.isEmpty ? rawArtist : artist;
  }

  /// Retrieve lyrics for a song. Checks memory cache, database cache, local .lrc, then online APIs.
  Future<ParsedLyrics?> getLyrics(
    Song song, {
    String? manualQuery,
    bool forceRefresh = false,
  }) async {
    final cacheKey = song.id;

    if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }

    // 1. Check if song already has cached lyrics in database
    if (!forceRefresh && song.lyrics != null && song.lyrics!.trim().isNotEmpty) {
      final parsed = parseLyrics(song.lyrics!);
      _memoryCache[cacheKey] = parsed;
      return parsed;
    }

    // 2. Check for local .lrc file next to the audio file on storage
    final localLrc = await _checkLocalLrcFile(song.uri);
    if (localLrc != null && localLrc.trim().isNotEmpty) {
      final parsed = parseLyrics(localLrc);
      _memoryCache[cacheKey] = parsed;
      await _persistLyrics(song.id, localLrc);
      return parsed;
    }

    // 3. Fetch from Online APIs (LRCLIB & Fallback)
    final onlineLyrics = await fetchOnlineLyrics(
      title: manualQuery ?? cleanTitle(song.title),
      artist: manualQuery != null ? '' : cleanArtist(song.artist),
      durationSeconds: song.duration.inSeconds > 0 ? song.duration.inSeconds : null,
      album: song.album,
    );

    if (onlineLyrics != null && onlineLyrics.trim().isNotEmpty) {
      final parsed = parseLyrics(onlineLyrics);
      _memoryCache[cacheKey] = parsed;
      await _persistLyrics(song.id, onlineLyrics);
      return parsed;
    }

    return null;
  }

  /// Fetches lyrics from online providers (LRCLIB exact -> LRCLIB search -> Lyrics.ovh).
  Future<String?> fetchOnlineLyrics({
    required String title,
    required String artist,
    int? durationSeconds,
    String? album,
  }) async {
    final cleanedTitle = cleanTitle(title);
    final cleanedArtist = cleanArtist(artist);

    // Tier 1: LRCLIB exact get
    final exact = await _fetchLrclibGet(cleanedTitle, cleanedArtist, durationSeconds, album);
    if (exact != null) return exact;

    // Tier 2: LRCLIB general search
    final searchQuery = '$cleanedTitle $cleanedArtist'.trim();
    final searchResult = await _fetchLrclibSearch(searchQuery, durationSeconds);
    if (searchResult != null) return searchResult;

    // Tier 3: Lyrics.ovh fallback (plain lyrics)
    if (cleanedArtist.isNotEmpty && cleanedArtist.toLowerCase() != 'unknown artist') {
      final ovh = await _fetchLyricsOvh(cleanedTitle, cleanedArtist);
      if (ovh != null) return ovh;
    }

    return null;
  }

  /// Tier 1: LRCLIB /api/get with exact parameters
  Future<String?> _fetchLrclibGet(
    String trackName,
    String artistName,
    int? durationSeconds,
    String? albumName,
  ) async {
    try {
      final queryParams = <String, String>{
        'track_name': trackName,
        'artist_name': artistName,
      };
      if (durationSeconds != null && durationSeconds > 0) {
        queryParams['duration'] = durationSeconds.toString();
      }
      if (albumName != null && albumName.isNotEmpty && albumName.toLowerCase() != 'unknown album') {
        queryParams['album_name'] = albumName;
      }

      final uri = Uri.parse('$_lrclibBase/get').replace(queryParameters: queryParams);
      final json = await _httpGetJson(uri);
      if (json != null && json is Map) {
        final synced = json['syncedLyrics'] as String?;
        if (synced != null && synced.trim().isNotEmpty) return synced;

        final plain = json['plainLyrics'] as String?;
        if (plain != null && plain.trim().isNotEmpty) return plain;
      }
    } catch (e) {
      debugPrint('LRCLIB get error: $e');
    }
    return null;
  }

  /// Tier 2: LRCLIB /api/search with query string
  Future<String?> _fetchLrclibSearch(String query, int? durationSeconds) async {
    try {
      final uri = Uri.parse('$_lrclibBase/search').replace(queryParameters: {'q': query});
      final json = await _httpGetJson(uri);
      if (json != null && json is List && json.isNotEmpty) {
        // Prioritize results with synced lyrics
        Map? bestItem;
        for (final item in json) {
          if (item is Map) {
            final synced = item['syncedLyrics'] as String?;
            if (synced != null && synced.trim().isNotEmpty) {
              if (durationSeconds != null && item['duration'] is num) {
                final diff = ((item['duration'] as num) - durationSeconds).abs();
                if (diff <= 5) {
                  bestItem = item;
                  break;
                }
              }
              bestItem ??= item;
            }
          }
        }
        bestItem ??= json.first as Map;

        final synced = bestItem['syncedLyrics'] as String?;
        if (synced != null && synced.trim().isNotEmpty) return synced;

        final plain = bestItem['plainLyrics'] as String?;
        if (plain != null && plain.trim().isNotEmpty) return plain;
      }
    } catch (e) {
      debugPrint('LRCLIB search error: $e');
    }
    return null;
  }

  /// Tier 3: Lyrics.ovh fallback
  Future<String?> _fetchLyricsOvh(String title, String artist) async {
    try {
      final uri = Uri.parse(
        'https://api.lyrics.ovh/v1/${Uri.encodeComponent(artist)}/${Uri.encodeComponent(title)}',
      );
      final json = await _httpGetJson(uri);
      if (json != null && json is Map && json['lyrics'] != null) {
        final text = (json['lyrics'] as String).trim();
        if (text.isNotEmpty) return text;
      }
    } catch (_) {}
    return null;
  }

  /// Check if a local .lrc file exists next to the music file on the device.
  Future<String?> _checkLocalLrcFile(String uri) async {
    try {
      if (uri.startsWith('content://') || uri.startsWith('http://') || uri.startsWith('https://')) {
        return null;
      }
      final filePath = uri.replaceFirst('file://', '');
      final lastDot = filePath.lastIndexOf('.');
      if (lastDot == -1) return null;

      final lrcPath = '${filePath.substring(0, lastDot)}.lrc';
      final file = File(lrcPath);
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return null;
  }

  /// Execute an HTTP GET request and parse the response JSON.
  Future<dynamic> _httpGetJson(Uri uri) async {
    // 1. On Android physical devices, use native HttpURLConnection via MethodChannel
    // to bypass bionic getaddrinfo/DNS quirks and guarantee 100% network reliability.
    if (!kIsWeb && Platform.isAndroid && !Platform.environment.containsKey('FLUTTER_TEST')) {
      try {
        const channel = MethodChannel('com.dagi.dagiplayer/http');
        final response = await channel.invokeMethod<String>('get', {'url': uri.toString()});
        if (response != null && response.trim().isNotEmpty) {
          return jsonDecode(response);
        }
        return null;
      } catch (e) {
        debugPrint('Native HTTP channel error: $e, trying Dart fallback');
      }
    }

    // 2. Standard Dart HttpClient fallback (for desktop, tests, etc.)
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 6));
      request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close().timeout(const Duration(seconds: 6));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body);
      }
    } catch (e) {
      debugPrint('HTTP error for $uri: $e');
    } finally {
      client?.close();
    }
    return null;
  }

  /// Persist lyrics to database so subsequent loads are instantaneous.
  Future<void> _persistLyrics(String songId, String rawLyrics) async {
    try {
      await AppDatabase.instance.updateSongLyrics(songId, rawLyrics);
    } catch (e) {
      debugPrint('Failed to persist song lyrics: $e');
    }
  }

  /// Parses raw text into ParsedLyrics with timestamps if in LRC format.
  static ParsedLyrics parseLyrics(String raw) {
    final lines = <LyricLine>[];
    final rawLines = raw.split('\n');

    // LRC timestamp regex: [mm:ss.xx] or [mm:ss.xxx] or [mm:ss]
    final tagRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');
    bool hasSyncedLines = false;

    for (final line in rawLines) {
      final matches = tagRegex.allMatches(line);
      if (matches.isNotEmpty) {
        hasSyncedLines = true;
        final cleanText = line.replaceAll(tagRegex, '').trim();

        for (final match in matches) {
          final minutes = int.parse(match.group(1)!);
          final seconds = int.parse(match.group(2)!);
          final msStr = match.group(3);
          int millis = 0;
          if (msStr != null) {
            millis = msStr.length == 2 ? int.parse(msStr) * 10 : int.parse(msStr);
          }
          final timestamp = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: millis,
          );

          if (cleanText.isNotEmpty || matches.length == 1) {
            lines.add(LyricLine(timestamp: timestamp, text: cleanText));
          }
        }
      } else {
        // Plain text line without timestamp
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          lines.add(LyricLine(timestamp: Duration.zero, text: trimmed));
        }
      }
    }

    if (hasSyncedLines) {
      lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }

    return ParsedLyrics(
      lines: lines,
      isSynced: hasSyncedLines,
      rawText: raw,
    );
  }
}
