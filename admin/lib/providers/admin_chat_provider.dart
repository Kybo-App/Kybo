import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../models/chat.dart';
import '../admin_repository.dart';

// Provider per la gestione chat dell'admin.
// Admin vede solo chat admin-nutritionist (come clientId); nutritionist vede tutte le sue chat.
// resolveUserName — recupera nome da Firestore con caching; prefetchNamesForChats — pre-carica nomi in bulk.
class AdminChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AdminRepository _repo = AdminRepository();

  String? _selectedChatId;
  String? _userRole;

  String? get selectedChatId => _selectedChatId;
  String? get userRole => _userRole;
  String? get currentUserId => _auth.currentUser?.uid;

  final Map<String, String> _userNameCache = {};

  String? getCachedName(String uid) => _userNameCache[uid];

  Future<String> resolveUserName(String uid, {String fallback = ''}) async {
    if (_userNameCache.containsKey(uid)) return _userNameCache[uid]!;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        final first = (data['first_name'] as String? ?? '').trim();
        final last  = (data['last_name']  as String? ?? '').trim();
        final full  = [first, last].where((s) => s.isNotEmpty).join(' ');
        _userNameCache[uid] = full.isNotEmpty
            ? full
            : (data['email'] as String? ?? fallback);
      } else {
        _userNameCache[uid] = fallback;
      }
    } catch (_) {
      _userNameCache[uid] = fallback;
    }
    if (!_isDisposed) notifyListeners();
    return _userNameCache[uid]!;
  }

  Future<void> prefetchNamesForChats(List<Chat> chats) async {
    final uids = chats
        .where((c) =>
            c.chatType == 'nutritionist-client' &&
            !_userNameCache.containsKey(c.clientId) &&
            c.clientId.isNotEmpty)
        .map((c) => c.clientId)
        .toSet();
    for (final uid in uids) {
      await resolveUserName(uid);
    }
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _ensureRole() async {
    if (_userRole != null) return;
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (_isDisposed) return;
      _userRole = userDoc.data()?['role'] as String?;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching user role: $e');
      if (_isDisposed) return;
      _userRole = 'nutritionist';
      notifyListeners();
    }
  }

  Stream<List<Chat>> getChatsForCurrentUser() async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield [];
      return;
    }

    await _ensureRole();

    Query query;
    if (_userRole == 'admin') {
      query = _firestore
          .collection('chats')
          .where('chatType', isEqualTo: 'admin-nutritionist')
          .where('participants.clientId', isEqualTo: user.uid)
          .orderBy('lastMessageTime', descending: true);
    } else {
      query = _firestore
          .collection('chats')
          .where('participants.nutritionistId', isEqualTo: user.uid)
          .orderBy('lastMessageTime', descending: true);
    }

    yield* query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Chat.fromFirestore(doc)).toList();
    });
  }

  int getMyUnreadCount(Chat chat) {
    if (_userRole == 'admin') {
      return chat.unreadCountClient;
    } else {
      return chat.unreadCountNutritionist;
    }
  }

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

  Future<void> sendMessage(
    String chatId, 
    String messageText, {
    String? attachmentUrl,
    String? attachmentType,
    String? fileName,
  }) async {
    final user = _auth.currentUser;
    if (user == null || (messageText.trim().isEmpty && attachmentUrl == null)) return;

    // Azzera subito il typing: il messaggio è in volo.
    clearTyping(chatId);

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

  void selectChat(String? chatId) {
    // Cambio chat: azzera l'eventuale typing precedente
    if (_selectedChatId != null && _selectedChatId != chatId) {
      clearTyping(_selectedChatId!);
    }
    _selectedChatId = chatId;
    notifyListeners();

    if (chatId != null) {
      markAsRead(chatId);
    }
  }

  // --- TYPING INDICATOR ---
  // Stato locale: scriviamo su Firestore al massimo una volta a inizio
  // burst e una dopo 3s di inattività.
  bool _isTypingLocal = false;
  Timer? _typingTimer;

  /// Stream del flag "sta scrivendo" della controparte (cliente o admin a
  /// seconda del chatType).
  Stream<bool> watchOtherTyping(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return false;
      final typing = data['typing'] as Map<String, dynamic>? ?? const {};
      final chatType = data['chatType'] ?? 'nutritionist-client';
      // Sono nutrizionista → mostro typing del client; sono admin in chat
      // admin-nutritionist → mostro typing del nutrizionista (chiave 'nutritionist').
      if (chatType == 'admin-nutritionist' && _userRole == 'admin') {
        return typing['nutritionist'] == true;
      }
      return typing['client'] == true;
    });
  }

  /// Da chiamare a ogni TextField.onChanged.
  void notifyTyping(String chatId) {
    if (!_isTypingLocal) {
      _isTypingLocal = true;
      _setTypingRemote(chatId, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _isTypingLocal = false;
      _setTypingRemote(chatId, false);
    });
  }

  void clearTyping(String chatId) {
    _typingTimer?.cancel();
    if (_isTypingLocal) {
      _isTypingLocal = false;
      _setTypingRemote(chatId, false);
    }
  }

  Future<void> _setTypingRemote(String chatId, bool value) async {
    try {
      // La chiave dipende dal proprio ruolo: nutritionist scrive su
      // typing.nutritionist; admin in chat admin-nutritionist scrive su
      // typing.client (perché lì admin gioca il ruolo "client").
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final chatType = chatDoc.data()?['chatType'] ?? 'nutritionist-client';
      String key;
      if (chatType == 'admin-nutritionist' && _userRole == 'admin') {
        key = 'client';
      } else {
        key = 'nutritionist';
      }
      await _firestore.collection('chats').doc(chatId).set(
        {'typing': {key: value}},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('admin typing update error: $e');
    }
  }

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

  Future<void> createChatWithNutritionist({
    required String nutritionistId,
    required String nutritionistName,
    required String nutritionistEmail,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final existing = await _firestore
          .collection('chats')
          .where('chatType', isEqualTo: 'admin-nutritionist')
          .where('participants.clientId', isEqualTo: user.uid)
          .where('participants.nutritionistId', isEqualTo: nutritionistId)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        selectChat(existing.docs.first.id);
        return;
      }

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

  Future<Map<String, dynamic>> uploadAttachment(PlatformFile file) async {
    return await _repo.uploadChatAttachment(file);
  }

  Future<Map<String, dynamic>> broadcastMessage(String message) async {
    return await _repo.broadcastMessage(message);
  }
}
