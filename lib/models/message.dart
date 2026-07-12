/// Mirrors the Message shape from api.ts / /messages/:otherUserId
class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final String? roomId;
  final String createdAt;

  /// Read receipt — true once the recipient has seen this message.
  final bool seen;

  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.roomId,
    required this.createdAt,
    this.seen = false,
  });

  bool isOwnMessage(String myId) => senderId == myId;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      senderId: (json['sender_id'] ?? json['from'] ?? '').toString(),
      receiverId: (json['receiver_id'] ?? json['to'] ?? '').toString(),
      content: (json['content'] ?? json['text'] ?? '').toString(),
      roomId: json['room_id']?.toString(),
      createdAt: (json['created_at'] ?? json['createdAt'] ?? '').toString(),
      seen: json['seen'] == true ||
          json['is_read'] == true ||
          json['read_at'] != null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'content': content,
        'room_id': roomId,
        'created_at': createdAt,
        'seen': seen,
      };

  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    String? roomId,
    String? createdAt,
    bool? seen,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      roomId: roomId ?? this.roomId,
      createdAt: createdAt ?? this.createdAt,
      seen: seen ?? this.seen,
    );
  }
}
