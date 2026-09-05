class Song {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? albumArtist;
  final Duration duration;
  final String uri;
  final String? artworkUri;
  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final int fileSize;
  final DateTime dateAdded;
  final bool isFavorite;
  final int playCount;
  final DateTime? lastPlayedAt;
  final String? lyrics;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.albumArtist,
    required this.duration,
    required this.uri,
    this.artworkUri,
    this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.fileSize = 0,
    required this.dateAdded,
    this.isFavorite = false,
    this.playCount = 0,
    this.lastPlayedAt,
    this.lyrics,
  });

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    Duration? duration,
    String? uri,
    String? artworkUri,
    String? genre,
    int? year,
    int? trackNumber,
    int? discNumber,
    int? fileSize,
    DateTime? dateAdded,
    bool? isFavorite,
    int? playCount,
    DateTime? lastPlayedAt,
    String? lyrics,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      duration: duration ?? this.duration,
      uri: uri ?? this.uri,
      artworkUri: artworkUri ?? this.artworkUri,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      fileSize: fileSize ?? this.fileSize,
      dateAdded: dateAdded ?? this.dateAdded,
      isFavorite: isFavorite ?? this.isFavorite,
      playCount: playCount ?? this.playCount,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      lyrics: lyrics ?? this.lyrics,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'albumArtist': albumArtist,
      'duration_ms': duration.inMilliseconds,
      'uri': uri,
      'artwork_uri': artworkUri,
      'genre': genre,
      'year': year,
      'track_number': trackNumber,
      'disc_number': discNumber,
      'file_size': fileSize,
      'date_added': dateAdded.millisecondsSinceEpoch,
      'is_favorite': isFavorite ? 1 : 0,
      'play_count': playCount,
      'last_played_at': lastPlayedAt?.millisecondsSinceEpoch,
      'lyrics': lyrics,
    };
  }

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String?,
      albumArtist: map['albumArtist'] as String?,
      duration: Duration(milliseconds: (map['duration_ms'] as int?) ?? 0),
      uri: map['uri'] as String,
      artworkUri: map['artwork_uri'] as String?,
      genre: map['genre'] as String?,
      year: map['year'] as int?,
      trackNumber: map['track_number'] as int?,
      discNumber: map['disc_number'] as int?,
      fileSize: (map['file_size'] as int?) ?? 0,
      dateAdded: DateTime.fromMillisecondsSinceEpoch((map['date_added'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      playCount: (map['play_count'] as int?) ?? 0,
      lastPlayedAt: map['last_played_at'] != null ? DateTime.fromMillisecondsSinceEpoch(map['last_played_at'] as int) : null,
      lyrics: map['lyrics'] as String?,
    );
  }
}
