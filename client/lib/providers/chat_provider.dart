import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../core/env.dart';
import '../models/chat_message.dart';

/// Provider for managing chat with nutritionist
/// Struttura Firestore unificata con admin:
///   /chats/{chatId}
///     - chatType: 'nutritionist-client'
///     - participants: { clientId, nutritionistId }
///     - clientName, clientEmail
///     - lastMessage, lastMessageTime, lastMessageSender
///     - unreadCount: { client, nutritionist }
///   /chats/{chatId}/messages/{msgId}
///     - senderId, senderType, message, timestamp, read
///     - attachmentUrl, attachmentType, fileName (opzionali)
class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  String? _currentChatId;
  String? get chatId => _currentChatId;

  String? _nutritionistId;
  String? _clientName;
  String? _clientEmail;
  bool _initialized = false;

  StreamSubscription? _unreadSubscription;

  /// Initialize chat: resolve nutritionist from user document
  Future<void> initializeChat() async {
    final user = _auth.currentUser;
    if (user == null || _initialized) return;

    try {
      // Fetch user document to get parent_id (nutritionist UID)
      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        debugPrint('Chat: User document not found');
        return;
      }

      final userData = userDoc.data()!;
      _nutritionistId = userData['parent_id'] as String?;
      _clientName =
          '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}'
              .trim();
      _clientEmail = userData['email'] as String? ?? user.email ?? '';

      if (_clientName == null || _clientName!.isEmpty) {
        _clientName = user.email?.split('@').first ?? 'Utente';
      }

      if (_nutritionistId == null || _nutritionistId!.isEmpty) {
        debugPrint('Chat: No nutritionist assigned (parent_id is null)');
        // User is independent or not yet assigned - no chat available
        return;
      }

      // Chat ID: deterministic format based on client UID
      _currentChatId = '${user.uid}_chat';
      _initialized = true;

      // Ensure chat document exists with correct metadata
      await _ensureChatDocument();

      // Listen to unread count
      _listenToUnreadCount();

      debugPrint(
          'Chat initialized: chatId=$_currentChatId, nutritionist=$_nutritionistId');
    } catch (e) {
      debugPrint('Error initializing chat: $e');
    }
  }

  /// Ensure the chat document exists with all required fields
  Future<void> _ensureChatDocument() async {
    if (_currentChatId == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final chatRef = _firestore.collection('chats').doc(_currentChatId);
    final chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
      // Create chat document with full metadata
      await chatRef.set({
        'chatType': 'nutritionist-client',
        'participants': {
          'clientId': user.uid,
          'nutritionistId': _nutritionistId,
        },
        'clientName': _clientName ?? 'Utente',
        'clientEmail': _clientEmail ?? '',
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': '',
        'unreadCount': {
          'client': 0,
          'nutritionist': 0,
        },
      });
    } else {
      // Update metadata if changed (name, nutritionist reassignment)
      final data = chatDoc.data()!;
      final existingNutriId =
          (data['participants'] as Map<String, dynamic>?)?['nutritionistId'];

      if (existingNutriId != _nutritionistId ||
          data['clientName'] != _clientName) {
        await chatRef.update({
          'participants.nutritionistId': _nutritionistId,
          'clientName': _clientName ?? 'Utente',
          'clientEmail': _clientEmail ?? '',
          'chatType': 'nutritionist-client',
        });
      }
    }
  }

  /// Listen to unread count changes
  void _listenToUnreadCount() {
    _unreadSubscription?.cancel();
    if (_currentChatId == null) return;

    _unreadSubscription =
        _firestore.collection('chats').doc(_currentChatId).snapshots().listen(
      (snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final unreadData = data['unreadCount'] as Map<String, dynamic>?;
          final newCount = unreadData?['client'] ?? 0;
          if (_unreadCount != newCount) {
            _unreadCount = newCount is int ? newCount : 0;
            notifyListeners();
          }
        }
      },
      onError: (e) => debugPrint('Error listening to unread count: $e'),
    );
  }

  /// Get messages stream for current chat
  Stream<List<ChatMessage>> getMessages() {
    if (_currentChatId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('chats')
        .doc(_currentChatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .toList();
    });
  }

  /// Upload attachment via backend API, returns {url, fileType, fileName}
  Future<Map<String, dynamic>> uploadAttachment(PlatformFile file) async {
    final token = await _auth.currentUser?.getIdToken();
    if (token == null) throw Exception('Non autenticato');

    final uri = Uri.parse('${Env.apiUrl}/chat/upload-attachment');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    if (file.bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
        contentType: _getMediaType(file.extension),
      ));
    } else if (file.path != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path!,
        filename: file.name,
        contentType: _getMediaType(file.extension),
      ));
    } else {
      throw Exception('File vuoto o invalido');
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Upload fallito: ${response.statusCode}');
    }
  }

  MediaType? _getMediaType(String? extension) {
    if (extension == null) return null;
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'pdf':
        return MediaType('application', 'pdf');
      default:
        return null;
    }
  }

  /// Send a new message (with optional attachment)
  Future<void> sendMessage(
    String text, {
    String? attachmentUrl,
    String? attachmentType,
    String? fileName,
  }) async {
    if (_currentChatId == null) return;
    if (text.trim().isEmpty && attachmentUrl == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final message = ChatMessage(
        id: '',
        message: text.trim(),
        senderId: user.uid,
        senderType: 'client',
        timestamp: DateTime.now(),
        read: false,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        fileName: fileName,
      );

      // Add message to subcollection
      await _firestore
          .collection('chats')
          .doc(_currentChatId)
          .collection('messages')
          .add(message.toFirestore());

      // Build lastMessage preview
      String lastMessagePreview = text.trim();
      if (lastMessagePreview.isEmpty && attachmentType != null) {
        lastMessagePreview = attachmentType == 'pdf' ? '📄 Documento' : '📷 Immagine';
      }

      // Update chat metadata
      await _firestore.collection('chats').doc(_currentChatId).set({
        'chatType': 'nutritionist-client',
        'participants': {
          'clientId': user.uid,
          'nutritionistId': _nutritionistId,
        },
        'clientName': _clientName ?? 'Utente',
        'clientEmail': _clientEmail ?? '',
        'lastMessage': lastMessagePreview,
        'lastMessageTime': Timestamp.now(),
        'lastMessageSender': 'client',
        'unreadCount': {
          'client': 0, // Reset own unread
          'nutritionist': FieldValue.increment(1), // Increment other side
        },
        'messageCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Mark all messages as read (messages from nutritionist/admin)
  Future<void> markAsRead() async {
    if (_currentChatId == null) return;

    try {
      // Reset client unread count
      await _firestore.collection('chats').doc(_currentChatId).update({
        'unreadCount.client': 0,
      });

      // Mark individual messages from nutritionist/admin as read
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(_currentChatId)
          .collection('messages')
          .where('read', isEqualTo: false)
          .where('senderType', whereIn: ['nutritionist', 'admin']).get();

      if (messagesSnapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in messagesSnapshot.docs) {
          batch.update(doc.reference, {'read': true});
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  /// Check if chat is available (user has a nutritionist assigned)
  bool get isChatAvailable => _currentChatId != null && _nutritionistId != null;

  /// Clear chat data (on logout)
  void clearChat() {
    _unreadSubscription?.cancel();
    _currentChatId = null;
    _nutritionistId = null;
    _clientName = null;
    _clientEmail = null;
    _unreadCount = 0;
    _initialized = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _unreadSubscription?.cancel();
    super.dispose();
  }
}
