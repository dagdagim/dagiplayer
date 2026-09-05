import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/song.dart';
import '../services/lyrics/online_lyrics_service.dart';

final onlineLyricsServiceProvider = Provider<OnlineLyricsService>((ref) {
  return OnlineLyricsService.instance;
});

class LyricsQueryState {
  final String? manualQuery;
  final int refreshId;

  const LyricsQueryState({this.manualQuery, this.refreshId = 0});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricsQueryState &&
          other.manualQuery == manualQuery &&
          other.refreshId == refreshId;

  @override
  int get hashCode => manualQuery.hashCode ^ refreshId.hashCode;
}

final songLyricsQueryProvider = StateProvider.family<LyricsQueryState, String>((ref, songId) {
  return const LyricsQueryState();
});

final lyricsProvider = FutureProvider.family<ParsedLyrics?, Song>((ref, song) async {
  final queryState = ref.watch(songLyricsQueryProvider(song.id));
  final service = ref.watch(onlineLyricsServiceProvider);

  return await service.getLyrics(
    song,
    manualQuery: queryState.manualQuery,
    forceRefresh: queryState.refreshId > 0,
  );
});
