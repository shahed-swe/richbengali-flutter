/// Mirrors the shape returned by GET /messages (conversations list).
/// The backend returns an array of User objects who have exchanged messages
/// with the current user, with extra fields for last message + unread count.
class ConversationUser {
  final String id;
  final String? name;
  final String? city;
  final String? profilePictureUrl;
  final bool isOnline;
  final bool isInCall;
  final String? gender;

  const ConversationUser({
    required this.id,
    this.name,
    this.city,
    this.profilePictureUrl,
    this.isOnline = false,
    this.isInCall = false,
    this.gender,
  });

  factory ConversationUser.fromJson(Map<String, dynamic> json) {
    return ConversationUser(
      id: (json['id'] ?? '').toString(),
      name: json['name']?.toString(),
      city: json['city']?.toString(),
      profilePictureUrl: (json['profile_picture_url'] ??
              json['primary_photo_url'] ??
              json['avatar'])
          ?.toString(),
      isOnline: json['is_online'] == true,
      isInCall: json['is_in_call'] == true,
      gender: json['gender']?.toString(),
    );
  }

  ConversationUser copyWith({
    bool? isOnline,
    bool? isInCall,
  }) {
    return ConversationUser(
      id: id,
      name: name,
      city: city,
      profilePictureUrl: profilePictureUrl,
      isOnline: isOnline ?? this.isOnline,
      isInCall: isInCall ?? this.isInCall,
      gender: gender,
    );
  }
}

class Conversation {
  final ConversationUser otherUser;
  /// Last message snippet (optional — not always present from backend)
  final String? lastMessage;
  final int unreadCount;
  final String? lastMessageAt;

  const Conversation({
    required this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
    this.lastMessageAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      otherUser: ConversationUser.fromJson(json),
      lastMessage: json['last_message']?.toString(),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      lastMessageAt: json['last_message_at']?.toString(),
    );
  }

  Conversation copyWith({
    ConversationUser? otherUser,
    int? unreadCount,
  }) {
    return Conversation(
      otherUser: otherUser ?? this.otherUser,
      lastMessage: lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessageAt: lastMessageAt,
    );
  }
}
