class RelationStatus {
  final String targetId;
  final bool isLiked;
  final bool isFavorited;
  final bool isSuperliked;
  final bool likedMe;
  final bool favoritedMe;
  final bool superlikedMe;
  final bool? visited;
  final bool? visitedMe;
  final String? lastVisitAt;
  final String? lastVisitedMeAt;

  const RelationStatus({
    required this.targetId,
    this.isLiked = false,
    this.isFavorited = false,
    this.isSuperliked = false,
    this.likedMe = false,
    this.favoritedMe = false,
    this.superlikedMe = false,
    this.visited,
    this.visitedMe,
    this.lastVisitAt,
    this.lastVisitedMeAt,
  });

  factory RelationStatus.fromJson(Map<String, dynamic> json) {
    return RelationStatus(
      targetId: (json['target_id'] ?? '').toString(),
      isLiked: json['is_liked'] == true,
      isFavorited: json['is_favorited'] == true,
      isSuperliked: json['is_superliked'] == true,
      likedMe: json['liked_me'] == true,
      favoritedMe: json['favorited_me'] == true,
      superlikedMe: json['superliked_me'] == true,
      visited: json['visited'] as bool?,
      visitedMe: json['visited_me'] as bool?,
      lastVisitAt: json['last_visit_at']?.toString(),
      lastVisitedMeAt: json['last_visited_me_at']?.toString(),
    );
  }

  RelationStatus copyWith({
    bool? isLiked,
    bool? isFavorited,
    bool? isSuperliked,
  }) {
    return RelationStatus(
      targetId: targetId,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
      isSuperliked: isSuperliked ?? this.isSuperliked,
      likedMe: likedMe,
      favoritedMe: favoritedMe,
      superlikedMe: superlikedMe,
      visited: visited,
      visitedMe: visitedMe,
      lastVisitAt: lastVisitAt,
      lastVisitedMeAt: lastVisitedMeAt,
    );
  }
}
