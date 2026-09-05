class Album {
  final String id;
  final String title;
  final String artist;
  final String? artworkUri;
  final int? year;
  final int songCount;
  final Duration totalDuration;
  final List<String> songIds;

  const Album({
    required this.id,
    required this.title,
    required this.artist,
    this.artworkUri,
    this.year,
    this.songCount = 0,
    this.totalDuration = Duration.zero,
    this.songIds = const [],
  });

  Album copyWith({
    String? id,
    String? title,
    String? artist,
    String? artworkUri,
    int? year,
    int? songCount,
    Duration? totalDuration,
    List<String>? songIds,
  }) {
    return Album(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artworkUri: artworkUri ?? this.artworkUri,
      year: year ?? this.year,
      songCount: songCount ?? this.songCount,
      totalDuration: totalDuration ?? this.totalDuration,
      songIds: songIds ?? this.songIds,
    );
  }
}
