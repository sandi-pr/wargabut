import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/event_companion_model.dart';
import '../../../models/companion_message_model.dart';
import '../../../models/user_profile_model.dart';
import '../../../provider/auth_provider.dart';
import '../../../provider/companion_provider.dart';
import '../../../provider/profile_provider.dart';
import '../community/member_card_dialog.dart';

class CompanionChatDialog extends StatefulWidget {
  final EventCompanionModel companion;

  const CompanionChatDialog({super.key, required this.companion});

  static Future<void> show(BuildContext context, {required EventCompanionModel companion}) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    if (isDesktop) {
      return showDialog(
        context: context,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: SizedBox(
            width: 520,
            height: 620,
            child: CompanionChatDialog(companion: companion),
          ),
        ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollController) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: CompanionChatDialog(companion: companion),
          ),
        ),
      );
    }
  }

  @override
  State<CompanionChatDialog> createState() => _CompanionChatDialogState();
}

class _CompanionChatDialogState extends State<CompanionChatDialog> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _resolveAvatar(String uid, String rawAvatarUrl, ProfileProvider profileProvider) {
    if (rawAvatarUrl.trim().isNotEmpty) return rawAvatarUrl.trim();
    if (profileProvider.currentProfile?.uid == uid &&
        profileProvider.currentProfile?.avatarUrl.isNotEmpty == true) {
      return profileProvider.currentProfile!.avatarUrl;
    }
    final cached = profileProvider.getCachedProfile(uid);
    if (cached != null && cached.avatarUrl.isNotEmpty) {
      return cached.avatarUrl;
    }
    return '';
  }

  Future<void> _openMemberCard(
    BuildContext context,
    String uid,
    String username,
    String displayName,
    String avatarUrl,
  ) async {
    final profileProvider = context.read<ProfileProvider>();
    final authProvider = context.read<AuthProvider>();

    UserProfileModel? targetProfile;

    if (authProvider.user?.uid == uid && profileProvider.currentProfile != null) {
      targetProfile = profileProvider.currentProfile;
    } else {
      targetProfile = await profileProvider.getProfileByUid(uid);
      if (targetProfile == null && username.isNotEmpty) {
        targetProfile = await profileProvider.getProfileByUsername(username);
      }
    }

    targetProfile ??= UserProfileModel(
      uid: uid,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );

    if (context.mounted) {
      MemberCardDialog.show(
        context,
        profile: targetProfile,
        isSelf: authProvider.user?.uid == uid,
        isLoggedIn: authProvider.isLoggedIn,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isLoggedIn || authProvider.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Silakan login terlebih dahulu untuk mengirim pesan koordinasi.'),
          action: SnackBarAction(
            label: 'Login',
            onPressed: () => context.push('/login'),
          ),
        ),
      );
      return;
    }

    final user = authProvider.user!;
    final profileProvider = context.read<ProfileProvider>();
    final currentProfile = profileProvider.currentProfile;

    final senderName = (currentProfile?.displayName.trim().isNotEmpty == true)
        ? currentProfile!.displayName.trim()
        : (user.displayName ?? user.email?.split('@').first ?? 'Member');
    final senderUsername = (currentProfile?.username.trim().isNotEmpty == true)
        ? currentProfile!.username.trim()
        : (user.displayName ?? user.email?.split('@').first ?? 'member');
    final senderAvatar = (currentProfile?.avatarUrl.trim().isNotEmpty == true)
        ? currentProfile!.avatarUrl.trim()
        : (user.photoURL ?? '');

    setState(() => _isSending = true);

    final msg = CompanionMessageModel(
      id: '',
      companionId: widget.companion.id,
      senderUid: user.uid,
      senderName: senderName,
      senderUsername: senderUsername,
      senderAvatar: senderAvatar,
      message: text,
      createdAt: DateTime.now(),
    );

    final companionProvider = context.read<CompanionProvider>();
    final success = await companionProvider.sendMessage(widget.companion.id, msg);

    if (mounted) {
      setState(() => _isSending = false);
      if (success) {
        _messageController.clear();
        Future.delayed(const Duration(milliseconds: 150), _scrollToBottom);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final currentUid = authProvider.user?.uid;
    final isLoggedIn = authProvider.isLoggedIn;
    final companionProvider = context.watch<CompanionProvider>();
    final profileProvider = context.watch<ProfileProvider>();

    return Column(
      children: [
        // Header Rombongan
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.companion.isTransit ? Colors.blue.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.companion.isTransit ? Icons.directions_railway_rounded : Icons.place_rounded,
                  color: widget.companion.isTransit ? Colors.blue : Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.companion.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${widget.companion.meetingPoint} • ${widget.companion.meetingTime}',
                      style: TextStyle(fontSize: 11, color: theme.hintColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Daftar Pesan Chat
        Expanded(
          child: StreamBuilder<List<CompanionMessageModel>>(
            stream: companionProvider.getMessagesStream(widget.companion.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data ?? [];

              if (messages.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined, size: 48, color: theme.hintColor.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada obrolan koordinasi.',
                          style: TextStyle(fontWeight: FontWeight.bold, color: theme.hintColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sapa teman rombongan atau tanyakan titik kumpul di sini!',
                          style: TextStyle(fontSize: 12, color: theme.hintColor),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

              // Pre-fetch sender profiles in background for cached avatars & member cards
              for (final msg in messages) {
                if (msg.senderUid.isNotEmpty && profileProvider.getCachedProfile(msg.senderUid) == null) {
                  profileProvider.getProfileByUid(msg.senderUid);
                }
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.senderUid == currentUid;
                  final resolvedAvatar = _resolveAvatar(msg.senderUid, msg.senderAvatar, profileProvider);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!isMe) ...[
                          GestureDetector(
                            onTap: () => _openMemberCard(
                              context,
                              msg.senderUid,
                              msg.senderUsername,
                              msg.senderName,
                              resolvedAvatar,
                            ),
                            child: Tooltip(
                              message: 'Lihat profil ${msg.senderName}',
                              child: CircleAvatar(
                                radius: 14,
                                backgroundImage: resolvedAvatar.isNotEmpty ? NetworkImage(resolvedAvatar) : null,
                                child: resolvedAvatar.isEmpty ? const Icon(Icons.person, size: 14) : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? colorScheme.primary
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(14),
                                topRight: const Radius.circular(14),
                                bottomLeft: isMe ? const Radius.circular(14) : const Radius.circular(2),
                                bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(14),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (!isMe)
                                  GestureDetector(
                                    onTap: () => _openMemberCard(
                                      context,
                                      msg.senderUid,
                                      msg.senderUsername,
                                      msg.senderName,
                                      resolvedAvatar,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(
                                        msg.senderName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                Text(
                                  msg.message,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isMe ? colorScheme.onPrimary : colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (msg.createdAt != null)
                                  Text(
                                    DateFormat('HH:mm').format(msg.createdAt!),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: (isMe ? colorScheme.onPrimary : colorScheme.onSurface).withValues(alpha: 0.7),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Input Pengiriman Pesan
        if (!isLoggedIn)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 18, color: theme.hintColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Login untuk ikut berdiskusi dan berkoordinasi.',
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/login');
                  },
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  child: const Text('Login Sekarang', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              border: Border(top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Tulis pesan koordinasi...',
                      hintStyle: TextStyle(fontSize: 13, color: theme.hintColor),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSending ? null : _sendMessage,
                  icon: _isSending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
