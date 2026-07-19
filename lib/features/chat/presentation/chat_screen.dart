import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_user.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/member_avatar.dart';
import '../data/chat_repository.dart';
import '../domain/message_model.dart';

/// Family group chat per the mockup: emerald header, ivory bubble
/// background, sender-coloured accents, bottom input bar.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String chatId) async {
    final text = _inputController.text.trim();
    // Guards against the input clearing before a send actually lands: if
    // sendText throws (RLS rejection, dropped connection, whatever), the
    // typed text must still be sitting in the box afterwards rather than
    // silently vanishing with nothing sent and no error shown.
    if (text.isEmpty || _sending) return;
    // Set the guard synchronously, before the first await, so two calls
    // fired in the same frame (double Enter, Enter racing the send
    // button) can't both slip past the _sending check before either one
    // sets it — that gap used to let a single tap send the message twice.
    setState(() => _sending = true);
    final me = await ref.read(currentAppUserProvider.future);
    if (me == null) {
      setState(() => _sending = false);
      return;
    }
    try {
      await ref.read(chatRepositoryProvider).sendText(chatId: chatId, senderId: me.id, body: text);
      _inputController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message not sent: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final chatIdAsync = ref.watch(familyChatIdProvider);

    return Scaffold(
      backgroundColor: colors.ivory,
      appBar: AppBar(title: const Text('Family Chat')),
      body: chatIdAsync.when(
        data: (chatId) {
          if (chatId == null) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline,
              message: 'Your family chat appears once your family is set up.',
            );
          }
          return _ChatBody(
            chatId: chatId,
            inputController: _inputController,
            scrollController: _scrollController,
            sending: _sending,
            onSend: () => _send(chatId),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            EmptyState(icon: Icons.error_outline, message: 'Could not open chat: $error'),
      ),
    );
  }
}

class _ChatBody extends ConsumerWidget {
  const _ChatBody({
    required this.chatId,
    required this.inputController,
    required this.scrollController,
    required this.sending,
    required this.onSend,
  });

  final String chatId;
  final TextEditingController inputController;
  final ScrollController scrollController;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final membersAsync = ref.watch(familyMembersProvider);
    final meAsync = ref.watch(currentAppUserProvider);
    final members = {
      for (final m in membersAsync.value ?? <AppUser>[]) m.id: m,
    };
    final me = meAsync.value;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<MessageModel>>(
            stream: ref.watch(chatRepositoryProvider).messageStream(chatId),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? const <MessageModel>[];
              if (snapshot.connectionState == ConnectionState.waiting && messages.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (messages.isEmpty) {
                return const EmptyState(
                  icon: Icons.waving_hand_outlined,
                  message: 'Say hello — this is your family\'s space.',
                );
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (scrollController.hasClients) {
                  scrollController.jumpTo(scrollController.position.maxScrollExtent);
                }
              });
              return ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final msg = messages[i];
                  final sender = members[msg.senderId];
                  final isMine = me != null && msg.senderId == me.id;
                  return _MessageBubble(
                    message: msg,
                    sender: sender,
                    isMine: isMine,
                    canModerate: isMine || (me != null && me.role == UserRole.parent),
                    onDelete: () => ref.read(chatRepositoryProvider).deleteMessage(msg.id),
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: inputController,
                    enabled: !sending,
                    decoration: const InputDecoration(hintText: 'Message'),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: colors.emerald700),
                  icon: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                  onPressed: sending ? null : onSend,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.sender,
    required this.isMine,
    required this.canModerate,
    required this.onDelete,
  });

  final MessageModel message;
  final AppUser? sender;
  final bool isMine;
  final bool canModerate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = context.appTypography;

    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Center(
          child: Text(
            message.body ?? '',
            style: typography.caption.copyWith(color: colors.gray[5]),
          ),
        ),
      );
    }

    final accent = sender != null ? memberColor(sender!.avatarColor) : colors.emerald500;
    final time =
        '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine && sender != null) ...[
            MemberAvatar(user: sender!, radius: 14),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: canModerate && !message.isDeleted
                  ? () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Remove message?'),
                          content: const Text('It will show as removed for everyone.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Remove')),
                          ],
                        ),
                      );
                      if (confirmed == true) onDelete();
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isMine ? colors.emerald700 : colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: isMine ? null : Border(left: BorderSide(color: accent, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMine && sender != null)
                      Text(sender!.displayName,
                          style: typography.caption
                              .copyWith(color: accent, fontWeight: FontWeight.w600)),
                    Text(
                      message.isDeleted ? 'Message removed' : (message.body ?? ''),
                      style: typography.body.copyWith(
                        color: isMine ? colors.ivory : null,
                        fontStyle: message.isDeleted ? FontStyle.italic : null,
                      ),
                    ),
                    Text(time,
                        style: typography.caption.copyWith(
                            color: isMine ? colors.ivory.withValues(alpha: 0.7) : colors.gray[5])),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
