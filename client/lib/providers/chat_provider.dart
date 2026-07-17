// Provider per la chat con il nutrizionista.
// initializeChat — risolve il nutrizionista dal documento utente e crea il documento chat se assente.
// runSmartSyncCheck — non usato qui, ma il pattern Firestore unificato è: /chats/{uid}_chat/messages/{id}.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../services/api_client.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // [FIX CHAT-2 2026-07-07] initializeChat veniva chiamato in un solo punto:
  // alla costruzione dei provider in main.dart, cioè all'avvio dell'app.
  // Se in quel momento l'utente non era ancora loggato (prima sessione dopo
  // l'installazione), usciva subito per user==null e NESSUNO lo richiamava
  // dopo il login → chat mai inizializzata e doc chats/{uid}_chat mai
  // creato fino al riavvio successivo (il nutrizionista non vedeva la chat
  // del cliente). Ora segue authStateChanges: init al login, reset al
  // logout — copre anche il cambio account nella stessa sessione.
  ChatProvider() {
    _authSub = _auth.authStateChanges().listen((user) {
      if (user == null) {
        _reset();
      } else {
        initializeChat();
      }
    });
  }

  StreamSubscription<User?>? _authSub;

  void _reset() {
    _unreadSubscription?.cancel();
    _unreadSubscription = null;
    _initialized = false;
    _currentChatId = null;
    _nutritionistId = null;
    _nutritionistName = null;
    _studioName = null;
    _clientName = null;
    _clientEmail = null;
    _unreadCount = 0;
    notifyListeners();
  }

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  String? _currentChatId;

  String? _nutritionistId;
  String? _nutritionistName;
  String? _studioName;
  String? _clientName;
  String? _clientEmail;
  bool _initialized = false;

  String get nutritionistName => _nutritionistName ?? 'Nutrizionista';
  String? get studioName => _studioName;

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
      // Degradazione: senza init la chat mostra lo stato vuoto e si
      // re-inizializza al prossimo evento di auth (login/riavvio) — vedi
      // il listener authStateChanges nel costruttore. Nessun dato perso.
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

  // --- TYPING INDICATOR ---
  // Stato locale: per evitare di scrivere su Firestore a ogni keystroke,
  // marchiamo "sto scrivendo" una sola volta per burst e usiamo un timer
  // che azzera il flag dopo 3s di inattività.
  bool _isTypingLocal = false;
  Timer? _typingTimer;

  /// Stream del flag "sta scrivendo" della controparte (nutrizionista).
  Stream<bool> watchOtherTyping() {
    if (_currentChatId == null) return Stream.value(false);
    return _firestore
        .collection('chats')
        .doc(_currentChatId)
        .snapshots()
        .map((snap) {
      final data = snap.data();
      if (data == null) return false;
      final typing = data['typing'] as Map<String, dynamic>? ?? const {};
      return typing['nutritionist'] == true;
    });
  }

  /// Da chiamare a ogni TextField.onChanged. Scrive su Firestore al massimo
  /// una volta a inizio burst e una volta dopo 3s di inattività.
  void notifyTyping() {
    if (_currentChatId == null) return;
    if (!_isTypingLocal) {
      _isTypingLocal = true;
      _setTypingRemote(true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _isTypingLocal = false;
      _setTypingRemote(false);
    });
  }

  /// Forza l'azzeramento (es. invio messaggio o uscita schermata).
  void clearTyping() {
    _typingTimer?.cancel();
    if (_isTypingLocal) {
      _isTypingLocal = false;
      _setTypingRemote(false);
    }
  }

  Future<void> _setTypingRemote(bool value) async {
    if (_currentChatId == null) return;
    try {
      await _firestore
          .collection('chats')
          .doc(_currentChatId)
          .set({'typing': {'client': value}}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('typing update error: $e');
    }
  }

  // [FIX CH2] Prima usava http.MultipartRequest diretto: niente retry di
  // rete e niente 401→signOut centralizzato. ApiClient.uploadFile include
  // entrambi; il Content-Type è rilevato automaticamente dall'estensione
  // (come faceva già _getMediaType per jpg/png/pdf), e il server valida
  // comunque i magic bytes indipendentemente dall'header dichiarato.
  Future<Map<String, dynamic>> uploadAttachment(PlatformFile file) async {
    if (file.path == null) throw Exception('File vuoto o invalido');
    final data = await ApiClient().uploadFile('/chat/upload-attachment', file.path!);
    return data as Map<String, dynamic>;
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

    // Azzera subito il typing indicator: il messaggio è in volo.
    clearTyping();

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

      String lastMessagePreview = text.trim();
      if (lastMessagePreview.isEmpty && attachmentType != null) {
        lastMessagePreview = attachmentType == 'pdf' ? '📄 Documento' : '📷 Immagine';
      }

      // [FIX CH4] Prima erano due scritture separate: se la seconda (update
      // del doc chat) falliva dopo che la prima (messaggio) era riuscita, il
      // messaggio esisteva ma anteprima/contatore non-letti del
      // nutrizionista non si aggiornavano — un messaggio "silenzioso" per il
      // destinatario. Un batch le rende atomiche (entrambe o nessuna).
      final chatRef = _firestore.collection('chats').doc(_currentChatId);
      final messageRef = chatRef.collection('messages').doc();
      final batch = _firestore.batch();

      batch.set(messageRef, message.toFirestore());
      batch.set(chatRef, {
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
        // [FIX CH1] unreadCount.client non viene più azzerato qui: è
        // ridondante (markAsRead lo fa già all'apertura della chat) e la
        // scrittura come mappa annidata (non dotted-path) sovrascriveva
        // interamente 'unreadCount' invece di aggiornare solo il campo
        // interessato.
        'unreadCount.nutritionist': FieldValue.increment(1),
        'messageCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      await batch.commit();
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
    _authSub?.cancel();
    _unreadSubscription?.cancel();
    super.dispose();
  }
}
