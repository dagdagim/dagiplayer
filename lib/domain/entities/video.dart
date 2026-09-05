class Video {
  final String id;
  final String title;
  final Duration duration;
  final String uri;
  final String? thumbnailUri;
  final String category; // 'Movies', 'TV', 'Music Videos', 'Vlogs', 'All'
  final int? year;
  final String? resolution;
  final Duration lastPosition;
  final DateTime dateAdded;
  final bool isFavorite;
  final int fileSize;
  final String? folderPath;
  final double playbackSpeed;
  final String? audioTrack;
  final String? selectedSubtitle;

  const Video({
    required this.id,
    required this.title,
    required this.duration,
    required this.uri,
    this.thumbnailUri,
    this.category = 'All',
    this.year,
    this.resolution,
    this.lastPosition = Duration.zero,
    required this.dateAdded,
    this.isFavorite = false,
    this.fileSize = 0,
    this.folderPath,
    this.playbackSpeed = 1.0,
    this.audioTrack,
    this.selectedSubtitle,
  });

  bool get hasResumePosition => lastPosition.inSeconds > 5 && lastPosition < duration;

  Video copyWith({
    String? id,
    String? title,
    Duration? duration,
    String? uri,
    String? thumbnailUri,
    String? category,
    int? year,
    String? resolution,
    Duration? lastPosition,
    DateTime? dateAdded,
    bool? isFavorite,
    int? fileSize,
    String? folderPath,
    double? playbackSpeed,
    String? audioTrack,
    String? selectedSubtitle,
  }) {
    return Video(
      id: id ?? this.id,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      uri: uri ?? this.uri,
      thumbnailUri: thumbnailUri ?? this.thumbnailUri,
      category: category ?? this.category,
      year: year ?? this.year,
      resolution: resolution ?? this.resolution,
      lastPosition: lastPosition ?? this.lastPosition,
      dateAdded: dateAdded ?? this.dateAdded,
      isFavorite: isFavorite ?? this.isFavorite,
      fileSize: fileSize ?? this.fileSize,
      folderPath: folderPath ?? this.folderPath,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      audioTrack: audioTrack ?? this.audioTrack,
      selectedSubtitle: selectedSubtitle ?? this.selectedSubtitle,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'duration_ms': duration.inMilliseconds,
      'uri': uri,
      'thumbnail_uri': thumbnailUri,
      'category': category,
      'year': year,
      'resolution': resolution,
      'last_position_ms': lastPosition.inMilliseconds,
      'date_added': dateAdded.millisecondsSinceEpoch,
      'is_favorite': isFavorite ? 1 : 0,
      'file_size': fileSize,
      'folder_path': folderPath,
      'playback_speed': playbackSpeed,
      'audio_track': audioTrack,
      'selected_subtitle': selectedSubtitle,
    };
  }

  factory Video.fromMap(Map<String, dynamic> map) {
    return Video(
      id: map['id'] as String,
      title: map['title'] as String,
      duration: Duration(milliseconds: (map['duration_ms'] as int?) ?? 0),
      uri: map['uri'] as String,
      thumbnailUri: map['thumbnail_uri'] as String?,
      category: (map['category'] as String?) ?? 'All',
      year: map['year'] as int?,
      resolution: map['resolution'] as String?,
      lastPosition: Duration(milliseconds: (map['last_position_ms'] as int?) ?? 0),
      dateAdded: DateTime.fromMillisecondsSinceEpoch((map['date_added'] as int?) ?? DateTime.now().millisecondsSinceEpoch),
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      fileSize: (map['file_size'] as int?) ?? 0,
      folderPath: map['folder_path'] as String?,
      playbackSpeed: (map['playback_speed'] as num?)?.toDouble() ?? 1.0,
      audioTrack: map['audio_track'] as String?,
      selectedSubtitle: map['selected_subtitle'] as String?,
    );
  }
}
