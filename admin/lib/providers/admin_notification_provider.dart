import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminNotificationProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _userRole;
  int _unreadChats = 0;
  int _expiringDiets = 0;

  int get unreadChats => _unreadChats;
  int get expiringDiets => _expiringDiets;

  AdminNotificationProvider() {
    _init();
  }

  void _init() async {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _fetchUserRole(user.uid);
      } else {
        _userRole = null;
        _unreadChats = 0;
        _expiringDiets = 0;
        notifyListeners();
      }
    });
  }

  Future<void> _fetchUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      _userRole = doc.data()?['role'];
      _startListening();
    } catch (e) {
      debugPrint("Error fetching role for notifications: $e");
    }
  }

  void _startListening() {
    if (_userRole == null) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // 1. Listen to Unread Chats
    Query chatQuery = _firestore.collection('chats');
    
    if (_userRole == 'admin') {
      chatQuery = chatQuery
          .where('chatType', isEqualTo: 'admin-nutritionist')
          .where('participants.clientId', isEqualTo: uid);
          // Firestore doesn't support inequality filter on different field easily with this setup
          // so we filter in client or use a specific index. 
          // For now, let's getting all matches and sum locally.
    } else {
      chatQuery = chatQuery
          .where('participants.nutritionistId', isEqualTo: uid);
    }

    chatQuery.snapshots().listen((snapshot) {
      int totalUnread = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final unreadMap = data['unreadCount'] as Map<String, dynamic>? ?? {};
        
        // Determine which counter matters
        if (_userRole == 'admin') {
           // Admin is 'client' in admin-nutritionist chat
           totalUnread += (unreadMap['client'] as num? ?? 0).toInt();
        } else {
           // Nutritionist
           totalUnread += (unreadMap['nutritionist'] as num? ?? 0).toInt();
        }
      }
      
      if (_unreadChats != totalUnread) {
        _unreadChats = totalUnread;
        notifyListeners();
      }
    });

    // 2. Listen to Expiring Diets
    // Logic: users where last_diet_update is older than 30 days
    // Firestore limited query capabilities for "older than x dynamic".
    // We will listen to all users assigned to this pro (if nutri) or all users (if admin)
    // and filter locally. For scalability this should be backend aggregation, but fine for now.
    
    Query userQuery = _firestore.collection('users');
    
    if (_userRole == 'nutritionist') {
       userQuery = userQuery.where('parent_id', isEqualTo: uid);
    } 
    // If admin, we see all users (or maybe filtered context? Assuming all for dashboard badge)

    userQuery.snapshots().listen((snapshot) {
       int expiring = 0;
       final now = DateTime.now();
       final threshold = now.subtract(const Duration(days: 30));

       for (var doc in snapshot.docs) {
         final data = doc.data() as Map<String, dynamic>;
         final lastUpdateTs = data['last_diet_update'] as Timestamp?;
         
         if (lastUpdateTs != null) {
           final lastUpdate = lastUpdateTs.toDate();
           if (lastUpdate.isBefore(threshold)) {
             expiring++;
           }
         }
       }

       if (_expiringDiets != expiring) {
         _expiringDiets = expiring;
         notifyListeners();
       }
    });
  }
}
