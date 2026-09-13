/// Mirrors the Message shape from api.ts / /messages/:otherUserId
class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;

  /// Photo messages: where the image lives. A remote https URL once the
  /// upload has landed, or a local file path while it is still in flight.
  final String? attachmentUrl;

  /// What kind of attachment this is — currently only "image".
  final String? attachmentType;

  final String? roomId;
  final String createdAt;

  /// Read receipt — true once the recipient has seen this message.
  final bool seen;

  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.attachmentUrl,
    this.attachmentType,
    this.roomId,
    required this.createdAt,
    this.seen = false,
  });

  bool isOwnMessage(String myId) => senderId == myId;

  /// True when this message should render as a photo rather than as text.
  bool get isImage =>
      attachmentType == 'image' &&
      attachmentUrl != null &&
      attachmentUrl!.isNotEmpty;

  /// While an upload is in flight the attachment points at a file on disk
  /// rather than at S3.
  bool get isLocalAttachment =>
      attachmentUrl != null && !attachmentUrl!.startsWith('http');

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      senderId: (json['sender_id'] ?? json['from'] ?? '').toString(),
      receiverId: (json['receiver_id'] ?? json['to'] ?? '').toString(),
      content: (json['content'] ?? json['text'] ?? '').toString(),
      attachmentUrl: (json['attachment_url'] as Object?)?.toString(),
      attachmentType: (json['attachment_type'] as Object?)?.toString(),
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
        'attachment_url': attachmentUrl,
        'attachment_type': attachmentType,
        'room_id': roomId,
        'created_at': createdAt,
        'seen': seen,
      };

  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? content,
    String? attachmentUrl,
    String? attachmentType,
    String? roomId,
    String? createdAt,
    bool? seen,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentType: attachmentType ?? this.attachmentType,
      roomId: roomId ?? this.roomId,
      createdAt: createdAt ?? this.createdAt,
      seen: seen ?? this.seen,
    );
  }
}
