import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat.dart';

/// Provider for managing chat functionality in admin dashboard
/// Supporta sia chat admin-nutritionist che nutritionist-client
class AdminChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _selectedChatId;
  String? _userRole;

  String? get selectedChatId => _selectedChatId;
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
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        _userRole = userDoc.data()?['role'] as String?;
      } catch (e) {
        debugPrint('Error fetching user role: $e');
        _userRole = 'nutritionist';
      }
    }

    // Filter chats based on role
    Query query;
    if (_userRole == 'admin') {
      // Admin sees all chats (both admin-nutritionist and nutritionist-client)
      // For now, show admin-nutritionist chats + all nutritionist-client chats for oversight
      query = _firestore
          .collection('chats')
          .orderBy('lastMessageTime', descending: true);
    } else {
      // Nutritionist sees chats where they are the nutritionistId
      // This includes: nutritionist-client chats AND admin-nutritionist chats
      query = _firestore
          .collection('chats')
          .where('participants.nutritionistId', isEqualTo: user.uid)
          .orderBy('lastMessageTime', descending: true);
    }

    yield* query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Chat.fromFirestore(doc))
          .toList();
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
            snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList());
  }

  /// Send a message as nutritionist or admin
  Future<void> sendMessage(String chatId, String messageText) async {
    final user = _auth.currentUser;
    if (user == null || messageText.trim().isEmpty) return;

    try {
      // Determine sender type based on role
      final senderType = _userRole == 'admin' ? 'admin' : 'nutritionist';

      final message = ChatMessage(
        id: '',
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

      // Determine who the "other side" is for unread count
      // Read the chat doc to understand the structure
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final chatData = chatDoc.data();
      final chatType = chatData?['chatType'] ?? 'nutritionist-client';

      Map<String, dynamic> unreadUpdate;
      if (chatType == 'admin-nutritionist') {
        // In admin-nutritionist chats:
        // - admin is the "client" (clientId)
        // - nutritionist is the "nutritionist" (nutritionistId)
        if (_userRole == 'admin') {
          // Admin sends -> reset admin's unread, increment nutritionist's
          unreadUpdate = {
            'client': 0, // admin's count reset
            'nutritionist': FieldValue.increment(1),
          };
        } else {
          // Nutritionist sends -> reset nutritionist's unread, increment admin's
          unreadUpdate = {
            'client': FieldValue.increment(1), // admin's count incremented
            'nutritionist': 0,
          };
        }
      } else {
        // In nutritionist-client chats:
        // - client is the "client" (clientId)
        // - nutritionist is the "nutritionist" (nutritionistId)
        // Nutritionist/admin sends -> increment client's unread, reset own
        unreadUpdate = {
          'client': FieldValue.increment(1),
          'nutritionist': 0,
        };
      }

      // Update chat metadata
      await _firestore.collection('chats').doc(chatId).set({
        'lastMessage': messageText.trim(),
        'lastMessageTime': Timestamp.now(),
        'lastMessageSender': senderType,
        'unreadCount': unreadUpdate,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Mark all messages in a chat as read for current user
  Future<void> markAsRead(String chatId) async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final chatData = chatDoc.data();
      final chatType = chatData?['chatType'] ?? 'nutritionist-client';

      // Determine which senderTypes to mark as read
      // (messages from the OTHER side)
      List<String> otherSenderTypes;
      String unreadField;

      if (chatType == 'admin-nutritionist') {
        if (_userRole == 'admin') {
          otherSenderTypes = ['nutritionist'];
          unreadField = 'unreadCount.client'; // admin's unread
        } else {
          otherSenderTypes = ['admin'];
          unreadField = 'unreadCount.nutritionist';
        }
      } else {
        // nutritionist-client: nutritionist reads client messages
        otherSenderTypes = ['client'];
        unreadField = 'unreadCount.nutritionist';
      }

      // Get unread messages from the other side
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('read', isEqualTo: false)
          .where('senderType', whereIn: otherSenderTypes)
          .get();

      if (messagesSnapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in messagesSnapshot.docs) {
          batch.update(doc.reference, {'read': true});
        }
        await batch.commit();
      }

      // Reset unread count
      await _firestore.collection('chats').doc(chatId).update({
        unreadField: 0,
      });
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
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

  /// Create a test admin-nutritionist chat (DEBUG only)
  Future<void> debugCreateTestChat() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final nutriSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'nutritionist')
          .limit(1)
          .get();

      if (nutriSnapshot.docs.isEmpty) {
        debugPrint('No nutritionist found to chat with');
        return;
      }

      final nutriDoc = nutriSnapshot.docs.first;
      final nutriData = nutriDoc.data();
      final nutriId = nutriDoc.id;
      final nutriName = nutriData['name'] ?? nutriData['first_name'] ?? 'Nutrizionista';
      final nutriEmail = nutriData['email'] ?? '';

      final chatRef = _firestore.collection('chats').doc();
      await chatRef.set({
        'chatType': 'admin-nutritionist',
        'participants': {
          'clientId': user.uid,
          'nutritionistId': nutriId,
        },
        'clientName': nutriName,
        'clientEmail': nutriEmail,
        'lastMessage': 'Chat di test admin-nutrizionista',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': 'admin',
        'unreadCount': {
          'client': 0,
          'nutritionist': 1,
        },
      });

      await chatRef.collection('messages').add({
        'senderId': user.uid,
        'senderType': 'admin',
        'message': 'Benvenuto nella chat di supporto Admin!',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      debugPrint('Test chat created: ${chatRef.id}');
      notifyListeners();
    } catch (e) {
      debugPrint('Error creating test chat: $e');
    }
  }
}
