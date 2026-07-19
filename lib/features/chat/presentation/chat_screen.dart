import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/app_user.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/member_avatar.dart';
import '../data/calls_repository.dart';
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
  bool _uploadingImage = false;

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

  Future<void> _pickAndSendImage(String chatId) async {
    if (_uploadingImage) return;
    final me = await ref.read(currentAppUserProvider.future);
    if (me == null || me.familyId == null) return;
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open photo picker: $e')));
      }
      return;
    }
    if (picked == null) return;
    setState(() => _uploadingImage = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
      final path = await ref.read(chatRepositoryProvider).uploadChatImage(
            familyId: me.familyId!,
            chatId: chatId,
            bytes: bytes,
            fileExt: ext,
            contentType: picked.mimeType,
          );
      await ref.read(chatRepositoryProvider).sendImage(chatId: chatId, senderId: me.id, storagePath: path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo not sent: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _startCall(BuildContext context, String chatId, String type) async {
    try {
      final call = await ref.read(callsRepositoryProvider).startCall(chatId: chatId, type: type);
      if (context.mounted) {
        context.push('/call/${call.id}?roomUrl=${Uri.encodeComponent(call.roomUrl)}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start call: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final chatIdAsync = ref.watch(familyChatIdProvider);

    return Scaffold(
      backgroundColor: colors.ivory,
      appBar: AppBar(
        title: const Text('Family Chat'),
        actions: chatIdAsync.maybeWhen(
          data: (chatId) => chatId == null
              ? const []
              : [
                  IconButton(
                    icon: const Icon(Icons.call_outlined),
                    tooltip: 'Voice call',
                    onPressed: () => _startCall(context, chatId, 'audio'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.videocam_outlined),
                    tooltip: 'Video call',
                    onPressed: () => _startCall(context, chatId, 'video'),
                  ),
                ],
          orElse: () => const [],
        ),
      ),
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
            uploadingImage: _uploadingImage,
            onSend: () => _send(chatId),
            onAttachImage: () => _pickAndSendImage(chatId),
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
    required this.uploadingImage,
    required this.onSend,
    required this.onAttachImage,
  });

  final String chatId;
  final TextEditingController inputController;
  final ScrollController scrollController;
  final bool sending;
  final bool uploadingImage;
  final VoidCallback onSend;
  final VoidCallback onAttachImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final membersAsync = ref.watch(familyMembersProvider);
    final meAsync = ref.watch(currentAppUserProvider);
    final members = {
      for (final m in membersAsync.value ?? <AppUser>[]) m.id: m,
    };
    final me = meAsync.value;

    final messagesAsync = ref.watch(chatMessagesProvider(chatId));

    return Column(
      children: [
        Expanded(
          child: messagesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                EmptyState(icon: Icons.error_outline, message: 'Could not load messages: $error'),
            data: (messages) {
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
                IconButton(
                  icon: uploadingImage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file),
                  tooltip: 'Attach a photo',
                  onPressed: uploadingImage ? null : onAttachImage,
                ),
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

class _MessageBubble extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
                    if (message.isDeleted)
                      Text(
                        'Message removed',
                        style: typography.body.copyWith(
                          color: isMine ? colors.ivory : null,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else if (message.type == 'image' && message.mediaUrl != null)
                      _ImageAttachment(storagePath: message.mediaUrl!, caption: message.body)
                    else
                      Text(
                        message.body ?? '',
                        style: typography.body.copyWith(color: isMine ? colors.ivory : null),
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

/// The `chat-media` bucket is private (family-privacy requirement, per
/// CLAUDE.md), so every render needs a freshly signed URL rather than a
/// stored public one.
class _ImageAttachment extends ConsumerWidget {
  const _ImageAttachment({required this.storagePath, this.caption});

  final String storagePath;
  final String? caption;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typography = context.appTypography;
    return FutureBuilder<String>(
      future: ref.read(chatRepositoryProvider).signedUrlForPath(storagePath),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 160,
            height: 160,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError) {
          return const SizedBox(
            width: 160,
            height: 80,
            child: Center(child: Icon(Icons.broken_image_outlined)),
          );
        }
        final url = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => showDialog<void>(
                context: context,
                builder: (ctx) => Dialog(
                  backgroundColor: Colors.black,
                  insetPadding: const EdgeInsets.all(AppSpacing.sm),
                  child: InteractiveViewer(child: Image.network(url)),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                child: Image.network(
                  url,
                  width: 200,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : const SizedBox(width: 200, height: 200),
                ),
              ),
            ),
            if (caption != null && caption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(caption!, style: typography.body),
              ),
          ],
        );
      },
    );
  }
}
