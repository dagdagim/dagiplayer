class Playlist {
  final String id;
  final String title;
  final String? description;
  final String? coverArtUri;
  final String? iconName;
  final int songCount;
  final Duration totalDuration;
  final DateTime dateCreated;
  final DateTime dateModified;
  final bool isPinned;
  final List<String> songIds;

  const Playlist({
    required this.id,
    required this.title,
    this.description,
    this.coverArtUri,
    this.iconName,
    this.songCount = 0,
    this.totalDuration = Duration.zero,
    required this.dateCreated,
    required this.dateModified,
    this.isPinned = false,
    this.songIds = const [],
  });

  Playlist copyWith({
    String? id,
    String? title,
    String? description,
    String? coverArtUri,
    String? iconName,
    int? songCount,
    Duration? totalDuration,
    DateTime? dateCreated,
    DateTime? dateModified,
    bool? isPinned,
    List<String>? songIds,
  }) {
    return Playlist(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      coverArtUri: coverArtUri ?? this.coverArtUri,
      iconName: iconName ?? this.iconName,
      songCount: songCount ?? this.songCount,
      totalDuration: totalDuration ?? this.totalDuration,
      dateCreated: dateCreated ?? this.dateCreated,
      dateModified: dateModified ?? this.dateModified,
      isPinned: isPinned ?? this.isPinned,
      songIds: songIds ?? this.songIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'cover_art_uri': coverArtUri,
      'icon_name': iconName,
      'date_created': dateCreated.millisecondsSinceEpoch,
      'date_modified': dateModified.millisecondsSinceEpoch,
      'is_pinned': isPinned ? 1 : 0,
    };
  }

  factory Playlist.fromMap(Map<String, dynamic> map, {List<String> songIds = const [], Duration totalDuration = Duration.zero}) {
    return Playlist(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      coverArtUri: map['cover_art_uri'] as String?,
      iconName: map['icon_name'] as String?,
      songCount: songIds.length,
      totalDuration: totalDuration,
      dateCreated: DateTime.fromMillisecondsSinceEpoch((map['date_created'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
      dateModified: DateTime.fromMillisecondsSinceEpoch((map['date_modified'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      songIds: songIds,
    );
  }
}
