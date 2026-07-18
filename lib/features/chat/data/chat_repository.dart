import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../domain/message_model.dart';

/// Chat data access. Live updates come from Supabase Realtime's
/// `.stream()` on messages (docs/05-build-sequence.md Module 5).
///
/// NOTE on encryption: the spec calls for application-layer encryption of
/// `messages.body` (libsodium sealed boxes per chat). That requires a
/// per-family key-distribution scheme tied to device provisioning, which
/// isn't in place yet — bodies currently travel TLS-encrypted and sit
/// behind family-scoped RLS, but are not E2E-encrypted. Tracked in
/// docs/06-deviations.md; do not silently remove this note.
class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  /// The family group chat is auto-created by a DB trigger on family
  /// creation, so for v1 every family has exactly one.
  Future<String?> familyGroupChatId() async {
    final row = await _client
        .from('chats')
        .select('id')
        .eq('type', 'family_group')
        .maybeSingle();
    return row?['id'] as String?;
  }

  Stream<List<MessageModel>> messageStream(String chatId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at')
        .map((rows) => rows.map(MessageModel.fromJson).toList());
  }

  Future<void> sendText({
    required String chatId,
    required String senderId,
    required String body,
    String? replyToId,
  }) async {
    await _client.from('messages').insert({
      'chat_id': chatId,
      'sender_id': senderId,
      'type': 'text',
      'body': body,
      if (replyToId != null) 'reply_to_id': replyToId,
    });
  }

  /// Tombstone, never hard-delete (product spec §9). Sender removes their
  /// own; a parent may remove any message in the family chat.
  Future<void> deleteMessage(String messageId) async {
    await _client
        .from('messages')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()}).eq('id', messageId);
  }

  Future<void> react({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    await _client.from('message_reactions').upsert({
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
    });
  }

  /// System messages (task completed, appointment created) post into the
  /// family chat via this hook (product spec §9 "Integrations").
  Future<void> postSystemMessage({required String chatId, required String senderId, required String body}) async {
    await _client.from('messages').insert({
      'chat_id': chatId,
      'sender_id': senderId,
      'type': 'system',
      'body': body,
    });
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(supabase);
});

final familyChatIdProvider = FutureProvider<String?>((ref) async {
  return ref.watch(chatRepositoryProvider).familyGroupChatId();
});
