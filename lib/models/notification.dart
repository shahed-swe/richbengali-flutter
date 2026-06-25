class NotificationActor {
  final String id;
  final String? name;
  final String? profilePictureUrl;

  const NotificationActor({
    required this.id,
    this.name,
    this.profilePictureUrl,
  });

  factory NotificationActor.fromJson(Map<String, dynamic> json) {
    return NotificationActor(
      id: (json['id'] ?? '').toString(),
      name: json['name']?.toString(),
      profilePictureUrl: json['profile_picture_url']?.toString(),
    );
  }
}

class NotificationItem {
  final String id;
  final String type; // 'like' | 'favorite' | 'message' | ...
  final Map<String, dynamic>? payload;
  final bool isRead;
  final String? readAt;
  final String createdAt;
  final String userId;
  final String actorId;
  final NotificationActor? actor;

  const NotificationItem({
    required this.id,
    required this.type,
    this.payload,
    required this.isRead,
    this.readAt,
    required this.createdAt,
    required this.userId,
    required this.actorId,
    this.actor,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : null,
      isRead: json['is_read'] == true,
      readAt: json['read_at']?.toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      actorId: (json['actor_id'] ?? '').toString(),
      actor: json['actor'] is Map
          ? NotificationActor.fromJson(
              Map<String, dynamic>.from(json['actor'] as Map))
          : null,
    );
  }

  NotificationItem copyWith({bool? isRead, String? readAt}) {
    return NotificationItem(
      id: id,
      type: type,
      payload: payload,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
      userId: userId,
      actorId: actorId,
      actor: actor,
    );
  }
}
