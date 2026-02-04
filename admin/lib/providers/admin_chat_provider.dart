import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../models/chat.dart';
import '../admin_repository.dart';

/// Provider for managing chat functionality in admin dashboard
///
/// Visibilità chat per ruolo:
/// - ADMIN: vede solo chat admin-nutritionist dove è partecipante (clientId)
/// - NUTRITIONIST: vede tutte le chat dove è nutritionistId
///   (sia nutritionist-client che admin-nutritionist)
class AdminChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AdminRepository _repo = AdminRepository();

  String? _selectedChatId;
  String? _userRole;

  String? get selectedChatId => _selectedChatId;
  String? get userRole => _userRole;
  String? get currentUserId => _auth.currentUser?.uid;

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Initialize: fetch user role
  Future<void> _ensureRole() async {
    if (_userRole != null) return;
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (_isDisposed) return;
      _userRole = userDoc.data()?['role'] as String?;
      notifyListeners(); // Notify UI that role is now available
    } catch (e) {
      debugPrint('Error fetching user role: $e');
      if (_isDisposed) return;
      _userRole = 'nutritionist';
      notifyListeners();
    }
  }

  /// Get chats for current user, filtered by role
  Stream<List<Chat>> getChatsForCurrentUser() async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield [];
      return;
    }

    await _ensureRole();

    Query query;
    if (_userRole == 'admin') {
      // Admin vede SOLO le chat admin-nutritionist dove è clientId
      query = _firestore
          .collection('chats')
          .where('chatType', isEqualTo: 'admin-nutritionist')
          .where('participants.clientId', isEqualTo: user.uid)
          .orderBy('lastMessageTime', descending: true);
    } else {
      // Nutritionist vede tutte le chat dove è nutritionistId
      query = _firestore
          .collection('chats')
          .where('participants.nutritionistId', isEqualTo: user.uid)
          .orderBy('lastMessageTime', descending: true);
    }

    yield* query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Chat.fromFirestore(doc)).toList();
    });
  }

  /// Get the correct unread count for current user based on role + chatType
  int getMyUnreadCount(Chat chat) {
    if (_userRole == 'admin') {
      // Admin: unread stored in 'client' field (admin is clientId)
      return chat.unreadCountClient;
    } else {
      // Nutritionist: unread stored in 'nutritionist' field
      return chat.unreadCountNutritionist;
    }
  }

  /// Get messages for a specific chat
  Stream<List<ChatMessage>> getMessagesForChat(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList());
  }

  /// Send a message as nutritionist or admin
  Future<void> sendMessage(
    String chatId, 
    String messageText, {
    String? attachmentUrl,
    String? attachmentType,
    String? fileName,
  }) async {
    final user = _auth.currentUser;
    if (user == null || (messageText.trim().isEmpty && attachmentUrl == null)) return;

    try {
      final senderType = _userRole == 'admin' ? 'admin' : 'nutritionist';

      final message = ChatMessage(
        id: '',
        senderId: user.uid,
        senderType: senderType,
        message: messageText.trim(),
        timestamp: DateTime.now(),
        read: false,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        fileName: fileName,
      );

      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add(message.toMap());

      // Determine unread update based on chatType
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final chatType = chatDoc.data()?['chatType'] ?? 'nutritionist-client';

      Map<String, dynamic> unreadUpdate;
      if (chatType == 'admin-nutritionist') {
        if (_userRole == 'admin') {
          unreadUpdate = {
            'client': 0,
            'nutritionist': FieldValue.increment(1),
          };
        } else {
          unreadUpdate = {
            'client': FieldValue.increment(1),
            'nutritionist': 0,
          };
        }
      } else {
        // nutritionist-client: nutri sends -> increment client, reset nutri
        unreadUpdate = {
          'client': FieldValue.increment(1),
          'nutritionist': 0,
        };
      }

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

  /// Mark messages as read for current user
  Future<void> markAsRead(String chatId) async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final chatData = chatDoc.data();
      if (chatData == null) return;

      final chatType = chatData['chatType'] ?? 'nutritionist-client';

      List<String> otherSenderTypes;
      String unreadField;

      if (chatType == 'admin-nutritionist') {
        if (_userRole == 'admin') {
          otherSenderTypes = ['nutritionist'];
          unreadField = 'unreadCount.client';
        } else {
          otherSenderTypes = ['admin'];
          unreadField = 'unreadCount.nutritionist';
        }
      } else {
        otherSenderTypes = ['client'];
        unreadField = 'unreadCount.nutritionist';
      }

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

      await _firestore.collection('chats').doc(chatId).update({
        unreadField: 0,
      });
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  /// Select a chat
  void selectChat(String? chatId) {
    _selectedChatId = chatId;
    notifyListeners();

    if (chatId != null) {
      markAsRead(chatId);
    }
  }

  /// Get list of nutritionists for creating a new chat (admin only)
  Future<List<Map<String, dynamic>>> getNutritionists() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'nutritionist')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          'name':
              '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim(),
          'email': data['email'] ?? '',
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetching nutritionists: $e');
      return [];
    }
  }

  /// Create a new admin-nutritionist chat
  Future<void> createChatWithNutritionist({
    required String nutritionistId,
    required String nutritionistName,
    required String nutritionistEmail,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Check if chat already exists
      final existing = await _firestore
          .collection('chats')
          .where('chatType', isEqualTo: 'admin-nutritionist')
          .where('participants.clientId', isEqualTo: user.uid)
          .where('participants.nutritionistId', isEqualTo: nutritionistId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        // Chat already exists, select it
        selectChat(existing.docs.first.id);
        return;
      }

      // Create new chat
      final chatRef = _firestore.collection('chats').doc();
      await chatRef.set({
        'chatType': 'admin-nutritionist',
        'participants': {
          'clientId': user.uid,
          'nutritionistId': nutritionistId,
        },
        'clientName': nutritionistName,
        'clientEmail': nutritionistEmail,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': '',
        'unreadCount': {
          'client': 0,
          'nutritionist': 0,
        },
      });

      selectChat(chatRef.id);
    } catch (e) {
      debugPrint('Error creating chat: $e');
      rethrow;
    }
  }

  /// Upload a file attachment
  Future<Map<String, dynamic>> uploadAttachment(PlatformFile file) async {
    return await _repo.uploadChatAttachment(file);
  }
}
