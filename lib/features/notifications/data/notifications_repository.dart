import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';

/// One row of the persistent in-app notification inbox — the fallback the
/// spec requires regardless of OS push state (product spec §7).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    this.relatedType,
    this.relatedId,
    required this.scheduledFor,
    this.sentAt,
    this.readAt,
    this.escalationLevel = 1,
  });

  final String id;
  final String category;
  final String title;
  final String body;
  final String? relatedType;
  final String? relatedId;
  final DateTime scheduledFor;
  final DateTime? sentAt;
  final DateTime? readAt;
  final int escalationLevel;

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        category: json['category'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        relatedType: json['related_type'] as String?,
        relatedId: json['related_id'] as String?,
        scheduledFor: DateTime.parse(json['scheduled_for'] as String).toLocal(),
        sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at'] as String).toLocal() : null,
        readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String).toLocal() : null,
        escalationLevel: json['escalation_level'] as int? ?? 1,
      );
}

class NotificationsRepository {
  NotificationsRepository(this._client);

  final SupabaseClient _client;

  Future<List<AppNotification>> inbox(String userId) async {
    final rows = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .lte('scheduled_for', DateTime.now().toUtc().toIso8601String())
        .order('scheduled_for', ascending: false)
        .limit(100);
    return (rows as List).map((r) => AppNotification.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> markRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', notificationId);
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(supabase);
});
