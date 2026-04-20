// Provider per la chat con il nutrizionista.
// initializeChat — risolve il nutrizionista dal documento utente e crea il documento chat se assente.
// runSmartSyncCheck — non usato qui, ma il pattern Firestore unificato è: /chats/{uid}_chat/messages/{id}.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/env.dart';
import '../models/chat_message.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  String? _currentChatId;
  String? get chatId => _currentChatId;

  String? _nutritionistId;
  String? _nutritionistName;
  String? _studioName;
  String? _clientName;
  String? _clientEmail;
  bool _initialized = false;

  String get nutritionistName => _nutritionistName ?? 'Nutrizionista';
  String? get studioName => _studioName;
  String? get nutritionistId => _nutritionistId;

  StreamSubscription? _unreadSubscription;

  static const _kCacheKey = 'chat_professional_cache';

  Future<void> _loadFromCache() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('${_kCacheKey}_${user.uid}');
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _nutritionistId = data['nutritionistId'] as String?;
      _nutritionistName = data['nutritionistName'] as String?;
      _studioName = data['studioName'] as String?;
      _clientName = data['clientName'] as String?;
      _clientEmail = data['clientEmail'] as String?;
      if (_nutritionistId != null && _nutritionistId!.isNotEmpty) {
        _currentChatId = '${user.uid}_chat';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Chat: cache load failed: $e');
    }
  }

  Future<void> _saveToCache() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${_kCacheKey}_${user.uid}',
        jsonEncode({
          'nutritionistId': _nutritionistId,
          'nutritionistName': _nutritionistName,
          'studioName': _studioName,
          'clientName': _clientName,
          'clientEmail': _clientEmail,
        }),
      );
    } catch (e) {
      debugPrint('Chat: cache save failed: $e');
    }
  }

  Future<void> initializeChat() async {
    final user = _auth.currentUser;
    if (user == null || _initialized) return;

    // Carica subito dalla cache locale così il nome del professionista
    // è disponibile anche offline / prima che Firestore risponda.
    await _loadFromCache();

    try {
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
        return;
      }

      try {
        final nutriDoc = await _firestore
            .collection('users')
            .doc(_nutritionistId)
            .get();
        if (nutriDoc.exists) {
          final nd = nutriDoc.data()!;
          final firstName = nd['first_name'] as String? ?? '';
          final lastName  = nd['last_name']  as String? ?? '';
          final fullName  = '$firstName $lastName'.trim();
          _nutritionistName = fullName.isNotEmpty ? fullName : nd['email'] as String?;
          final studio = (nd['studio_name'] as String?)?.trim();
          _studioName = (studio != null && studio.isNotEmpty) ? studio : null;
        }
      } catch (e) {
        debugPrint('Chat: Could not fetch nutritionist name: $e');
      }

      _currentChatId = '${user.uid}_chat';
      _initialized = true;

      await _saveToCache();

      await _ensureChatDocument();

      _listenToUnreadCount();

      debugPrint(
          'Chat initialized: chatId=$_currentChatId, nutritionist=$_nutritionistId');
    } catch (e) {
      debugPrint('Error initializing chat: $e');
    }
  }

  Future<void> _ensureChatDocument() async {
    if (_currentChatId == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final chatRef = _firestore.collection('chats').doc(_currentChatId);
    final chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
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

      await _firestore
          .collection('chats')
          .doc(_currentChatId)
          .collection('messages')
          .add(message.toFirestore());

      String lastMessagePreview = text.trim();
      if (lastMessagePreview.isEmpty && attachmentType != null) {
        lastMessagePreview = attachmentType == 'pdf' ? '📄 Documento' : '📷 Immagine';
      }

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
          'client': 0,
          'nutritionist': FieldValue.increment(1),
        },
        'messageCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  Future<void> markAsRead() async {
    if (_currentChatId == null) return;

    try {
      await _firestore.collection('chats').doc(_currentChatId).update({
        'unreadCount.client': 0,
      });

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

  bool get isChatAvailable => _currentChatId != null && _nutritionistId != null;

  void clearChat() {
    _unreadSubscription?.cancel();
    final prevUid = _auth.currentUser?.uid;
    _currentChatId = null;
    _nutritionistId = null;
    _nutritionistName = null;
    _studioName = null;
    _clientName = null;
    _clientEmail = null;
    _unreadCount = 0;
    _initialized = false;
    if (prevUid != null) {
      SharedPreferences.getInstance()
          .then((p) => p.remove('${_kCacheKey}_$prevUid'));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _unreadSubscription?.cancel();
    super.dispose();
  }
}
