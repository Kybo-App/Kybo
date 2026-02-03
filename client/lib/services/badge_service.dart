import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/badge_model.dart';

class BadgeService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<BadgeModel> _badges = [];
  List<BadgeModel> get badges => _badges;

  BadgeService() {
    _initBadges();
  }

  void _initBadges() {
    // Load static registry
    _badges = List.from(BadgeModel.registry);
    _loadUserBadges();
  }

  Future<void> _loadUserBadges() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      
      if (data != null && data.containsKey('unlocked_badges')) {
        final unlockedMap = data['unlocked_badges'] as Map<String, dynamic>;
        
        for (var badge in _badges) {
           if (unlockedMap.containsKey(badge.id)) {
             badge.isUnlocked = true;
             // unlockedMap[badge.id] could be timestamp or boolean, let's assume timestamp string if possible
             final val = unlockedMap[badge.id];
             if (val is String) {
               badge.unlockedAt = DateTime.tryParse(val);
             } else if (val is Timestamp) {
               badge.unlockedAt = val.toDate();
             }
           }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading badges: $e");
    }
  }

  /// Check conditions and unlock badge if met
  Future<void> unlockBadge(String badgeId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final badgeIndex = _badges.indexWhere((b) => b.id == badgeId);
    if (badgeIndex == -1) return;

    final badge = _badges[badgeIndex];
    if (badge.isUnlocked) return; // Already unlocked

    // Local update
    badge.isUnlocked = true;
    badge.unlockedAt = DateTime.now();
    notifyListeners();

    // Persist to Firestore
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'unlocked_badges': {
          badgeId: FieldValue.serverTimestamp(), // Store as timestamp
        }
      }, SetOptions(merge: true));
      
      debugPrint("🏆 Badge Unlocked: ${badge.title}");
    } catch (e) {
      debugPrint("Error unlocking badge: $e");
      // Revert local state if save fails? usually safe to keep local state for UX
    }
  }
  
  // Example triggers
  Future<void> checkLoginStreak() async {
     // Logic to calculate streak would go here.
     // For demo, let's just unlock 'first_login'
     await unlockBadge('first_login');
  }

  Future<void> onWeightLogged() async {
    await unlockBadge('weight_log_1');
  }
}
