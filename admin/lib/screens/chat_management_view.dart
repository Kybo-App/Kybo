import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat.dart';
import '../providers/admin_chat_provider.dart';
import '../widgets/design_system.dart';
import 'package:intl/intl.dart';

class ChatManagementView extends StatelessWidget {
  const ChatManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminChatProvider(),
      child: const Scaffold(
        body: _ChatManagementContent(),
      ),
    );
  }
}

class _ChatManagementContent extends StatelessWidget {
  const _ChatManagementContent();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ════════════════════════════════════════════════════════════════
        // LEFT PANEL: Chat List
        // ════════════════════════════════════════════════════════════════
        SizedBox(
          width: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with new chat button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Messaggi',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: KyboColors.textPrimary,
                      ),
                    ),
                    Builder(
                      builder: (ctx) {
                        // watch per ricostruire quando userRole diventa disponibile
                        final provider = ctx.watch<AdminChatProvider>();
                        if (provider.userRole == 'admin') {
                          return PillIconButton(
                            icon: Icons.add_comment_rounded,
                            tooltip: 'Nuova chat',
                            color: KyboColors.primary,
                            onPressed: () => _showNewChatDialog(ctx),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: KyboColors.border),
              Expanded(child: _ChatList()),
            ],
          ),
        ),

        // ════════════════════════════════════════════════════════════════
        // DIVIDER
        // ════════════════════════════════════════════════════════════════
        VerticalDivider(width: 1, color: KyboColors.border),

        // ════════════════════════════════════════════════════════════════
        // RIGHT PANEL: Chat Interface
        // ════════════════════════════════════════════════════════════════
        Expanded(child: _ChatInterface()),
      ],
    );
  }

  void _showNewChatDialog(BuildContext context) async {
    final provider = context.read<AdminChatProvider>();
    final nutritionists = await provider.getNutritionists();

    if (!context.mounted) return;

    if (nutritionists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Nessun nutrizionista trovato'),
          backgroundColor: KyboColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: KyboColors.surface,
        shape: RoundedRectangleBorder(borderRadius: KyboBorderRadius.large),
        title: Text(
          'Nuova Chat',
          style: TextStyle(color: KyboColors.textPrimary),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seleziona un nutrizionista',
                style: TextStyle(
                  color: KyboColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              ...nutritionists.map((nutri) => _NutritionistTile(
                    name: nutri['name'] ?? 'N/A',
                    email: nutri['email'] ?? '',
                    onTap: () async {
                      Navigator.pop(dialogCtx);
                      try {
                        await provider.createChatWithNutritionist(
                          nutritionistId: nutri['uid'],
                          nutritionistName: nutri['name'] ?? 'Nutrizionista',
                          nutritionistEmail: nutri['email'] ?? '',
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Errore: $e'),
                              backgroundColor: KyboColors.error,
                            ),
                          );
                        }
                      }
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutritionistTile extends StatefulWidget {
  final String name;
  final String email;
  final VoidCallback onTap;

  const _NutritionistTile({
    required this.name,
    required this.email,
    required this.onTap,
  });

  @override
  State<_NutritionistTile> createState() => _NutritionistTileState();
}

class _NutritionistTileState extends State<_NutritionistTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isHovered
                ? KyboColors.primary.withValues(alpha: 0.08)
                : KyboColors.surfaceElevated,
            borderRadius: KyboBorderRadius.medium,
            border: Border.all(color: KyboColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    KyboColors.roleNutritionist.withValues(alpha: 0.2),
                child: Icon(
                  Icons.health_and_safety,
                  color: KyboColors.roleNutritionist,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name.isEmpty ? 'Nutrizionista' : widget.name,
                      style: TextStyle(
                        color: KyboColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (widget.email.isNotEmpty)
                      Text(
                        widget.email,
                        style: TextStyle(
                          color: KyboColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chat_bubble_outline,
                color: KyboColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// CHAT LIST
// ════════════════════════════════════════════════════════════════════════
class _ChatList extends StatefulWidget {
  @override
  State<_ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<_ChatList> {
  late Stream<List<Chat>> _chatsStream;

  @override
  void initState() {
    super.initState();
    _chatsStream = context.read<AdminChatProvider>().getChatsForCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Chat>>(
      stream: _chatsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Errore: ${snapshot.error}',
                style: TextStyle(color: KyboColors.error),
              ),
            ),
          );
        }

        final chats = snapshot.data ?? [];

        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 64, color: KyboColors.textMuted),
                const SizedBox(height: 16),
                Text(
                  'Nessun messaggio',
                  style:
                      TextStyle(color: KyboColors.textSecondary, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) => _ChatListTile(chat: chats[index]),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// CHAT LIST TILE
// ════════════════════════════════════════════════════════════════════════
class _ChatListTile extends StatelessWidget {
  final Chat chat;

  const _ChatListTile({required this.chat});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminChatProvider>();
    final isSelected = provider.selectedChatId == chat.id;
    final unread = provider.getMyUnreadCount(chat);
    final hasUnread = unread > 0;

    // Determine display name and type
    String displayName = chat.clientName;
    bool isSupportChat = false;

    if (provider.userRole != 'admin' &&
        chat.chatType == 'admin-nutritionist') {
      displayName = 'Supporto Admin';
      isSupportChat = true;
    }

    // For nutritionist viewing a nutritionist-client chat, show client name
    if (provider.userRole != 'admin' &&
        chat.chatType == 'nutritionist-client') {
      displayName =
          chat.clientName.isNotEmpty ? chat.clientName : chat.clientEmail;
    }

    return Material(
      color: isSelected
          ? KyboColors.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      child: InkWell(
        onTap: () => provider.selectChat(chat.id),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom:
                  BorderSide(color: KyboColors.border.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                backgroundColor: isSupportChat
                    ? KyboColors.roleAdmin.withValues(alpha: 0.2)
                    : KyboColors.primary.withValues(alpha: 0.2),
                child: isSupportChat
                    ? const Icon(Icons.security_rounded,
                        size: 20, color: KyboColors.roleAdmin)
                    : Text(
                        displayName.isNotEmpty
                            ? displayName.substring(0, 1).toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: KyboColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontWeight:
                                  hasUnread ? FontWeight.bold : FontWeight.w500,
                              fontSize: 15,
                              color: KyboColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(chat.lastMessageTime),
                          style: TextStyle(
                            fontSize: 12,
                            color: KyboColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chat.lastMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: KyboColors.textSecondary,
                        fontWeight:
                            hasUnread ? FontWeight.w500 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Unread badge
              if (hasUnread) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: KyboColors.primary,
                    shape: BoxShape.circle,
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(time);
    } else if (diff.inDays == 1) {
      return 'Ieri';
    } else if (diff.inDays < 7) {
      return DateFormat('EEE').format(time);
    } else {
      return DateFormat('dd/MM').format(time);
    }
  }
}

// ════════════════════════════════════════════════════════════════════════
// CHAT INTERFACE
// ════════════════════════════════════════════════════════════════════════
class _ChatInterface extends StatefulWidget {
  @override
  State<_ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends State<_ChatInterface> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  PlatformFile? _pickedFile;
  bool _isUploading = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result != null) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  void _removeFile() {
    setState(() => _pickedFile = null);
  }

  Future<void> _sendMessage() async {
    final provider = context.read<AdminChatProvider>();
    final chatId = provider.selectedChatId;
    final message = _messageController.text.trim();

    if (chatId == null) return;
    if (message.isEmpty && _pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      String? attachmentUrl;
      String? attachmentType;
      String? fileName;

      if (_pickedFile != null) {
        final uploadResult = await provider.uploadAttachment(_pickedFile!);
        attachmentUrl = uploadResult['url'];
        attachmentType = uploadResult['fileType']; // 'image' or 'pdf'
        fileName = uploadResult['fileName'];
      }

      await provider.sendMessage(
        chatId, 
        message,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        fileName: fileName,
      );
      
      _messageController.clear();
      _removeFile();

      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore invio: $e'), backgroundColor: KyboColors.error),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AdminChatProvider>();
    final selectedChatId = provider.selectedChatId;

    if (selectedChatId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_rounded, size: 64, color: KyboColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'Seleziona una chat per iniziare',
              style: TextStyle(color: KyboColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Messages list
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: provider.getMessagesForChat(selectedChatId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data ?? [];

              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    'Nessun messaggio',
                    style: TextStyle(color: KyboColors.textSecondary),
                  ),
                );
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController
                      .jumpTo(_scrollController.position.maxScrollExtent);
                }
              });

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) =>
                    _MessageBubble(message: messages[index]),
              );
            },
          ),
        ),

        // Message input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: KyboColors.surface,
            border: Border(top: BorderSide(color: KyboColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     if (_pickedFile != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: KyboColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: KyboColors.primary),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.attach_file, size: 16, color: KyboColors.primary),
                              const SizedBox(width: 8),
                              Flexible(child: Text(_pickedFile!.name, overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: _removeFile,
                                child: Icon(Icons.close, size: 16, color: KyboColors.textMuted),
                              )
                            ],
                          ),
                        ),
                     TextField(
                      controller: _messageController,
                  style: TextStyle(color: KyboColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Scrivi un messaggio...',
                    hintStyle: TextStyle(color: KyboColors.textMuted),
                    filled: true,
                    fillColor: KyboColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: KyboColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: KyboColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide:
                          BorderSide(color: KyboColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  onSubmitted: (_) => _sendMessage(),
                ),
                   ],
                ),
              ),
              const SizedBox(width: 12),
              // Attachment Button
              IconButton(
                icon: const Icon(Icons.attach_file_rounded),
                color: _pickedFile != null ? KyboColors.primary : KyboColors.textSecondary,
                onPressed: _isUploading ? null : _pickFile,
              ),
              const SizedBox(width: 8),
              // Send Button
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      KyboColors.primary,
                      KyboColors.primary.withValues(alpha: 0.8)
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: _isUploading 
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 24, 
                        height: 24, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      ),
                    )
                  : IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// MESSAGE BUBBLE
// ════════════════════════════════════════════════════════════════════════
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AdminChatProvider>();
    final isMe = message.senderId == provider.currentUserId;
    final hasAttachment = message.attachmentUrl != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: KyboColors.surfaceElevated,
              child: Icon(Icons.person,
                  size: 18, color: KyboColors.textSecondary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? KyboColors.primary
                    : KyboColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasAttachment) ...[
                    _buildAttachmentPreview(context, isMe),
                    if (message.message.isNotEmpty) const SizedBox(height: 8),
                  ],
                  if (message.message.isNotEmpty)
                    Text(
                      message.message,
                      style: TextStyle(
                        color: isMe ? Colors.white : KyboColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : KyboColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: KyboColors.primary.withValues(alpha: 0.2),
              child: Icon(Icons.person, size: 18, color: KyboColors.primary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview(BuildContext context, bool isMe) {
    final isImage = message.attachmentType == 'image';
    
    if (isImage) {
      return GestureDetector(
        onTap: () => _launchUrl(message.attachmentUrl!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            message.attachmentUrl!,
            height: 150,
            width: 200,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
            loadingBuilder: (_, child, prog) {
              if (prog == null) return child;
              return Container(
                height: 150,
                width: 200,
                color: Colors.black12,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
          ),
        ),
      );
    } else {
      // PDF or other
      return InkWell(
        onTap: () => _launchUrl(message.attachmentUrl!),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isMe ? Colors.white.withValues(alpha: 0.3) : KyboColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.picture_as_pdf, 
                color: isMe ? Colors.white : KyboColors.error,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.fileName ?? 'Documento',
                  style: TextStyle(
                    color: isMe ? Colors.white : KyboColors.textPrimary,
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
