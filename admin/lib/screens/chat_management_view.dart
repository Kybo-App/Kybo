import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      child: Scaffold(
        body: const _ChatManagementContent(),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton.extended(
            onPressed: () {
              context.read<AdminChatProvider>().debugCreateTestChat();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tentativo creazione chat test...')),
              );
            },
            label: const Text('Crea Chat Test'),
            icon: const Icon(Icons.add_comment),
            backgroundColor: Colors.orange,
          ),
        ),
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
        // LEFT PANEL: Client List
        // ════════════════════════════════════════════════════════════════
        SizedBox(
          width: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Messaggi',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: KyboColors.textPrimary,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _ClientList()),
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
}

// ════════════════════════════════════════════════════════════════════════
// CLIENT LIST
// ════════════════════════════════════════════════════════════════════════
class _ClientList extends StatefulWidget {
  @override
  State<_ClientList> createState() => _ClientListState();
}

class _ClientListState extends State<_ClientList> {
  late Stream<List<Chat>> _chatsStream;

  @override
  void initState() {
    super.initState();
    // Cache the stream to prevent recreation on rebuilds
    _chatsStream = context.read<AdminChatProvider>().getChatsForNutritionist();
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
            child: Text('Errore: ${snapshot.error}'),
          );
        }

        final chats = snapshot.data ?? [];

        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Nessun messaggio',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
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
    final hasUnread = chat.unreadCountNutritionist > 0;

    // Determine correct display name based on context
    String displayName = chat.clientName;
    bool isSupportChat = false;
    
    // If I am a nutritionist and this is an admin chat, the "clientName" is ME.
    // So I should see "Supporto Admin" instead.
    if (provider.userRole != 'admin' && chat.chatType == 'admin-nutritionist') {
      displayName = "Supporto Admin";
      isSupportChat = true;
    }

    return Material(
      color: isSelected ? KyboColors.primary.withValues(alpha: 0.1) : Colors.transparent,
      child: InkWell(
        onTap: () => provider.selectChat(chat.id),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: KyboColors.border.withValues(alpha: 0.3)),
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
                    ? const Icon(Icons.security_rounded, size: 20, color: KyboColors.roleAdmin)
                    : Text(
                        displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?',
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
                              fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTime(chat.lastMessageTime),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chat.lastMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
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
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Text(
                    chat.unreadCountNutritionist > 9
                        ? '9+'
                        : '${chat.unreadCountNutritionist}',
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final provider = context.read<AdminChatProvider>();
    final chatId = provider.selectedChatId;
    final message = _messageController.text.trim();

    if (chatId != null && message.isNotEmpty) {
      provider.sendMessage(chatId, message);
      _messageController.clear();
      
      // Scroll to bottom after sending
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
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
            Icon(Icons.chat_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Seleziona una chat per iniziare',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
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
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              }

              // Auto-scroll to bottom when messages change
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
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
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Scrivi un messaggio...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: KyboColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [KyboColors.primary, KyboColors.primary.withValues(alpha: 0.8)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
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

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AdminChatProvider>();
    final isMe = message.senderId == provider.currentUserId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person, size: 18, color: Colors.grey),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? KyboColors.primary
                    : (KyboColors.isDark ? Colors.grey[800] : Colors.grey[200]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.message,
                    style: TextStyle(
                      color: isMe 
                          ? Colors.white 
                          : KyboColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      color: isMe
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey[600],
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
}
