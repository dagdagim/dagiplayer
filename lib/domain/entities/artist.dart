class Artist {
  final String id;
  final String name;
  final String? imageUri;
  final int songCount;
  final int albumCount;
  final bool isFollowed;
  final String? bio;

  const Artist({
    required this.id,
    required this.name,
    this.imageUri,
    this.songCount = 0,
    this.albumCount = 0,
    this.isFollowed = false,
    this.bio,
  });

  Artist copyWith({
    String? id,
    String? name,
    String? imageUri,
    int? songCount,
    int? albumCount,
    bool? isFollowed,
    String? bio,
  }) {
    return Artist(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUri: imageUri ?? this.imageUri,
      songCount: songCount ?? this.songCount,
      albumCount: albumCount ?? this.albumCount,
      isFollowed: isFollowed ?? this.isFollowed,
      bio: bio ?? this.bio,
    );
  }
}
