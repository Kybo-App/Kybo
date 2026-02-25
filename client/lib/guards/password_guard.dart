// Intercetta la navigazione e mostra ChangePasswordScreen se il flag requires_password_change è attivo su Firestore.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/change_password_screen.dart';

class PasswordGuard extends StatelessWidget {
  final Widget child;

  const PasswordGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return child;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return child;

        final userData = snapshot.data!.data() as Map<String, dynamic>?;

        bool requiresChange = userData?['requires_password_change'] ?? false;

        if (requiresChange) {
          return const ChangePasswordScreen();
        }

        return child;
      },
    );
  }
}
