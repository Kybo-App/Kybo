// Mostra VerifyEmailScreen finché il flag requires_email_verification è true su
// Firestore. Il flag lo impostano solo i NUOVI account (self-signup + creati
// dall'admin): gli utenti esistenti non lo hanno → guard inerte (nessun blocco).
// Viene azzerato solo lato server dopo verifica reale dell'email.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/verify_email_screen.dart';

class EmailVerificationGuard extends StatelessWidget {
  final Widget child;

  const EmailVerificationGuard({super.key, required this.child});

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

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final requiresVerification =
            data?['requires_email_verification'] ?? false;

        if (requiresVerification == true) {
          return const VerifyEmailScreen();
        }

        return child;
      },
    );
  }
}
