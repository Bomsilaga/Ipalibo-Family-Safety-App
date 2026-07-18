/// Mirrors `public.messages` (docs/02-data-model.md "Chat").
class MessageModel {
  const MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    this.body,
    this.mediaUrl,
    this.replyToId,
    this.editedAt,
    this.deletedAt,
    required this.createdAt,
  });

  final String id;
  final String chatId;
  final String senderId;
  final String type; // text | image | video | voice | document | system
  final String? body;
  final String? mediaUrl;
  final String? replyToId;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final DateTime createdAt;

  bool get isDeleted => deletedAt != null;
  bool get isSystem => type == 'system';

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: json['id'] as String,
        chatId: json['chat_id'] as String,
        senderId: json['sender_id'] as String,
        type: json['type'] as String,
        body: json['body'] as String?,
        mediaUrl: json['media_url'] as String?,
        replyToId: json['reply_to_id'] as String?,
        editedAt: json['edited_at'] != null
            ? DateTime.parse(json['edited_at'] as String).toLocal()
            : null,
        deletedAt: json['deleted_at'] != null
            ? DateTime.parse(json['deleted_at'] as String).toLocal()
            : null,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}
