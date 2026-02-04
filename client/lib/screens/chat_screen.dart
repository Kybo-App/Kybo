import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import '../widgets/design_system.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  PlatformFile? _pickedFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().markAsRead();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
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

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  void _removeFile() {
    setState(() => _pickedFile = null);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final provider = context.read<ChatProvider>();
      String? attachmentUrl;
      String? attachmentType;
      String? fileName;

      if (_pickedFile != null) {
        final uploadResult = await provider.uploadAttachment(_pickedFile!);
        attachmentUrl = uploadResult['url'];
        attachmentType = uploadResult['fileType'];
        fileName = uploadResult['fileName'];
      }

      await provider.sendMessage(
        text,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        fileName: fileName,
      );

      _messageController.clear();
      _removeFile();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore invio: $e'),
            backgroundColor: KyboColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KyboColors.background(context),
      appBar: AppBar(
        backgroundColor: KyboColors.surface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: KyboColors.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: KyboColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: KyboColors.primary, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nutrizionista',
                  style: TextStyle(
                    color: KyboColors.textPrimary(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Online',
                  style: TextStyle(
                    color: KyboColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: context.watch<ChatProvider>().getMessages(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: KyboColors.primary),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Errore caricamento messaggi',
                      style: TextStyle(color: KyboColors.error),
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: KyboColors.textMuted(context)),
                        const SizedBox(height: 16),
                        Text(
                          'Nessun messaggio',
                          style: TextStyle(color: KyboColors.textSecondary(context), fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Invia un messaggio al\ntuo nutrizionista!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: KyboColors.textMuted(context), fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => _MessageBubble(message: messages[index]),
                );
              },
            ),
          ),

          // File preview
          if (_pickedFile != null) _buildFilePreview(),

          // Input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildFilePreview() {
    final isImage = ['jpg', 'jpeg', 'png'].contains(_pickedFile!.extension?.toLowerCase());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: KyboColors.surface(context),
        border: Border(top: BorderSide(color: KyboColors.border(context), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isImage
                  ? KyboColors.primary.withValues(alpha: 0.1)
                  : KyboColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isImage ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
              color: isImage ? KyboColors.primary : KyboColors.error,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _pickedFile!.name,
                  style: TextStyle(color: KyboColors.textPrimary(context), fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB',
                  style: TextStyle(color: KyboColors.textMuted(context), fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: KyboColors.textMuted(context), size: 20),
            onPressed: _removeFile,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KyboColors.surface(context),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attachment button
            Container(
              decoration: BoxDecoration(
                color: KyboColors.background(context),
                shape: BoxShape.circle,
                border: Border.all(color: KyboColors.border(context)),
              ),
              child: IconButton(
                icon: Icon(Icons.attach_file_rounded, color: KyboColors.textSecondary(context), size: 22),
                onPressed: _isUploading ? null : _pickFile,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Scrivi un messaggio...',
                  hintStyle: TextStyle(color: KyboColors.textMuted(context)),
                  filled: true,
                  fillColor: KyboColors.background(context),
                  border: OutlineInputBorder(
                    borderRadius: KyboBorderRadius.pill,
                    borderSide: BorderSide(color: KyboColors.border(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: KyboBorderRadius.pill,
                    borderSide: BorderSide(color: KyboColors.border(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: KyboBorderRadius.pill,
                    borderSide: BorderSide(color: KyboColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [KyboColors.primary, KyboColors.primaryDark]),
                shape: BoxShape.circle,
              ),
              child: _isUploading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
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
    );
  }
}

// =============================================================================
// MESSAGE BUBBLE
// =============================================================================

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isClient = message.senderType == 'client';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isClient ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isClient) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: KyboColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: KyboColors.primary, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isClient ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isClient
                        ? LinearGradient(colors: [KyboColors.primary, KyboColors.primaryDark])
                        : null,
                    color: isClient ? null : KyboColors.surface(context),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isClient ? 16 : 4),
                      bottomRight: Radius.circular(isClient ? 4 : 16),
                    ),
                    border: isClient ? null : Border.all(color: KyboColors.border(context), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.hasAttachment) _buildAttachmentPreview(context, isClient),
                      if (message.hasAttachment && message.message.isNotEmpty) const SizedBox(height: 8),
                      if (message.message.isNotEmpty)
                        Text(
                          message.message,
                          style: TextStyle(
                            color: isClient ? Colors.white : KyboColors.textPrimary(context),
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.timestamp),
                  style: TextStyle(color: KyboColors.textMuted(context), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview(BuildContext context, bool isClient) {
    final isImage = message.attachmentType == 'image';

    if (isImage) {
      return GestureDetector(
        onTap: () => _openUrl(message.attachmentUrl!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            message.attachmentUrl!,
            height: 180,
            width: 220,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 80,
              width: 220,
              decoration: BoxDecoration(
                color: isClient ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.broken_image_rounded,
                color: isClient ? Colors.white70 : KyboColors.textMuted(context),
              ),
            ),
            loadingBuilder: (_, child, prog) {
              if (prog == null) return child;
              return Container(
                height: 180,
                width: 220,
                decoration: BoxDecoration(
                  color: isClient ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isClient ? Colors.white : KyboColors.primary,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // PDF
    return GestureDetector(
      onTap: () => _openUrl(message.attachmentUrl!),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isClient ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isClient ? Colors.white.withValues(alpha: 0.3) : KyboColors.border(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: isClient ? Colors.white : KyboColors.error, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message.fileName ?? 'Documento',
                style: TextStyle(
                  color: isClient ? Colors.white : KyboColors.textPrimary(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
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

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    String timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

    if (messageDate == today) {
      return timeStr;
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Ieri, $timeStr';
    } else {
      return '${timestamp.day}/${timestamp.month}, $timeStr';
    }
  }
}
