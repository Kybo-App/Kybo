import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat.dart';

/// Provider for managing chat functionality in admin dashboard
class AdminChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _selectedChatId;
  int _totalUnreadCount = 0;
  String? _userRole; // 'admin' or 'nutritionist'

  String? get selectedChatId => _selectedChatId;
  int get totalUnreadCount => _totalUnreadCount;
  String? get userRole => _userRole;
  String? get currentUserId => _auth.currentUser?.uid;

  /// Get all chats for current user (filtered by role)
  Stream<List<Chat>> getChatsForNutritionist() async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield [];
      return;
    }

    // Detect user role from Firestore
    if (_userRole == null) {
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        _userRole = userDoc.data()?['role'] as String?;
      } catch (e) {
        debugPrint('❌ Error fetching user role: $e');
        _userRole = 'nutritionist'; // default
      }
    }

    // Filter chats based on role
    Query query;
    if (_userRole == 'admin') {
      // Admin sees chats with nutritionists
      query = _firestore
          .collection('chats')
          .where('chatType', isEqualTo: 'admin-nutritionist')
          .where('participants.clientId', isEqualTo: user.uid) // admin is "client" in admin-nutritionist chat
          .orderBy('lastMessageTime', descending: true);
    } else {
      // Nutritionist sees ALL chats where they are the nutritionistID.
      // This includes:
      // 1. 'nutritionist-client' chats (conversations with their clients)
      // 2. 'admin-nutritionist' chats (conversations with admin)
      // 3. Legacy chats (missing chatType)
      query = _firestore
          .collection('chats')
          .where('participants.nutritionistId', isEqualTo: user.uid)
          .orderBy('lastMessageTime', descending: true);
    }

    yield* query.snapshots().map((snapshot) {
      final chats = snapshot.docs.map((doc) => Chat.fromFirestore(doc)).toList();
      
      // Note: We cannot call notifyListeners() here as it causes rebuild loops
      // if the UI is watching this provider.
      // Total unread count should be calculated by the UI or a separate stream.
      
      return chats;
    });
  }

  /// Get messages for a specific chat
  Stream<List<ChatMessage>> getMessagesForChat(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => 
          snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList()
        );
  }

  /// Send a message as nutritionist or admin
  Future<void> sendMessage(String chatId, String messageText) async {
    final user = _auth.currentUser;
    if (user == null || messageText.trim().isEmpty) return;

    try {
      // Determine sender type based on role
      final senderType = _userRole == 'admin' ? 'admin' : 'nutritionist';

      final message = ChatMessage(
        id: '', // Firestore will generate
        senderId: user.uid,
        senderType: senderType,
        message: messageText.trim(),
        timestamp: DateTime.now(),
        read: false,
      );

      // Add message to subcollection
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(message.toMap());

      // Update chat metadata
      await _firestore.collection('chats').doc(chatId).set({
        'lastMessage': messageText.trim(),
        'lastMessageTime': Timestamp.now(),
        'lastMessageSender': senderType,
        'unreadCount': {
          'client': FieldValue.increment(1),
          'nutritionist': 0, // Reset sender's unread when they send
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      rethrow;
    }
  }

  /// DEBUG: Create a test admin-nutritionist chat
  Future<void> debugCreateTestChat() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // 1. Find a nutritionist
      final nutriSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'nutritionist')
          .limit(1)
          .get();

      if (nutriSnapshot.docs.isEmpty) {
        debugPrint('❌ No nutritionist found to chat with');
        // Fallback: Create a dummy nutritionist if none exists
        return;
      }

      final nutriDoc = nutriSnapshot.docs.first;
      final nutriData = nutriDoc.data();
      final nutriId = nutriDoc.id;
      final nutriName = nutriData['name'] ?? 'Nutrizionista Test';
      final nutriEmail = nutriData['email'] ?? 'nutri@test.com';

      // 2. Create Chat
      final chatRef = _firestore.collection('chats').doc();
      await chatRef.set({
        'chatType': 'admin-nutritionist',
        'participants': {
          'clientId': user.uid,       // Admin acts as "client" in this relationship (initiator)
          'nutritionistId': nutriId,
        },
        'clientName': nutriName,       // Display name for the chat (The nutritionist's name)
        'clientEmail': nutriEmail,
        'lastMessage': 'Chat di test admin-nutrizionista',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': 'admin',
        'unreadCount': {
          'client': 0,
          'nutritionist': 1,
        },
      });

      // 3. Create initial message
      await chatRef.collection('messages').add({
        'senderId': user.uid,
        'senderType': 'admin',
        'message': 'Benvenuto nella chat di supporto Admin!',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      debugPrint('✅ Test chat created: ${chatRef.id}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error creating test chat: $e');
    }
  }

  /// Mark all messages in a chat as read for nutritionist
  Future<void> markAsRead(String chatId) async {
    try {
      // Get all unread messages sent by client
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('senderType', isEqualTo: 'client')
          .where('read', isEqualTo: false)
          .get();

      // Mark each as read
      final batch = _firestore.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      // Update chat unread count
      await _firestore.collection('chats').doc(chatId).update({
        'unreadCount.nutritionist': 0,
      });
    } catch (e) {
      debugPrint('❌ Error marking messages as read: $e');
    }
  }

  /// Select a chat (for UI state)
  void selectChat(String? chatId) {
    _selectedChatId = chatId;
    notifyListeners();
    
    // Mark as read when selected
    if (chatId != null) {
      markAsRead(chatId);
    }
  }
}
