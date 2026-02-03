import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';

/// Provider for managing chat with nutritionist
class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  String? _currentChatId;
  String? get chatId => _currentChatId;

  /// Initialize chat for current user
  /// Chat ID format: {userId}_nutritionist
  void initializeChat() {
    final user = _auth.currentUser;
    if (user != null) {
      _currentChatId = '${user.uid}_nutritionist';
      _listenToUnreadCount();
    }
  }

  /// Listen to unread count changes
  void _listenToUnreadCount() {
    if (_currentChatId == null) return;

    _firestore.collection('chats').doc(_currentChatId).snapshots().listen(
      (snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final unreadData = data['unreadCount'] as Map<String, dynamic>?;
          _unreadCount = unreadData?['client'] ?? 0;
          notifyListeners();
        }
      },
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

  /// Send a new message
  Future<void> sendMessage(String text) async {
    if (_currentChatId == null || text.trim().isEmpty) return;

    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final message = ChatMessage(
        id: '', // Firestore will generate
        text: text.trim(),
        senderId: user.uid,
        senderType: 'client',
        timestamp: DateTime.now(),
        read: false,
      );

      // Add message to subcollection
      await _firestore
          .collection('chats')
          .doc(_currentChatId)
          .collection('messages')
          .add(message.toFirestore());

      // Update chat metadata
      await _firestore.collection('chats').doc(_currentChatId).set({
        'participants': {
          'clientId': user.uid,
          'nutritionistId': 'nutritionist', // Placeholder, will be set by admin
        },
        'lastMessage': text.trim(),
        'lastMessageTime': Timestamp.now(),
        'lastMessageSender': 'client',
        'unreadCount': {
          'client': 0,
          'nutritionist': FieldValue.increment(1),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  /// Mark all messages as read
  Future<void> markAsRead() async {
    if (_currentChatId == null) return;

    try {
      await _firestore.collection('chats').doc(_currentChatId).update({
        'unreadCount.client': 0,
      });

      // Mark individual messages as read
      final messagesSnapshot = await _firestore
          .collection('chats')
          .doc(_currentChatId)
          .collection('messages')
          .where('read', isEqualTo: false)
          .where('senderType', isEqualTo: 'nutritionist')
          .get();

      final batch = _firestore.batch();
      for (var doc in messagesSnapshot.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  /// Clear chat data (on logout)
  void clearChat() {
    _currentChatId = null;
    _unreadCount = 0;
    notifyListeners();
  }
}
