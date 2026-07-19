/// Mirrors `public.calls`.
class CallModel {
  const CallModel({
    required this.id,
    required this.familyId,
    required this.chatId,
    required this.roomName,
    required this.roomUrl,
    required this.type,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.endedAt,
  });

  final String id;
  final String familyId;
  final String? chatId;
  final String roomName;
  final String roomUrl;
  final String type; // audio | video
  final String status; // ringing | active | ended | declined
  final String createdBy;
  final DateTime createdAt;
  final DateTime? endedAt;

  bool get isRinging => status == 'ringing';
  bool get isActive => status == 'active';
  bool get isEnded => status == 'ended' || status == 'declined';
  bool get isJoinable => isRinging || isActive;
  bool get isVideo => type == 'video';

  factory CallModel.fromJson(Map<String, dynamic> json) => CallModel(
        id: json['id'] as String,
        familyId: json['family_id'] as String,
        chatId: json['chat_id'] as String?,
        roomName: json['room_name'] as String,
        roomUrl: json['room_url'] as String,
        type: json['type'] as String,
        status: json['status'] as String,
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at'] as String).toLocal() : null,
      );
}
