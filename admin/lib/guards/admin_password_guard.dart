// Guard che reindirizza a ChangePasswordScreen se requires_password_change è true.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/change_password_screen.dart';

class AdminPasswordGuard extends StatelessWidget {
  final Widget child;
  const AdminPasswordGuard({super.key, required this.child});

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
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        bool mustChange = data?['requires_password_change'] ?? false;

        if (mustChange) {
          return const ChangePasswordScreen();
        }

        return child;
      },
    );
  }
}
