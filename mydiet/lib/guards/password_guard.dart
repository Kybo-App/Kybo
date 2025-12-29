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

    // Se l'utente non è loggato, mostra il contenuto normale (Login Screen)
    if (user == null) return child;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        // Mentre carica, mostriamo l'app (o uno splash vuoto)
        if (!snapshot.hasData) return child;

        final userData = snapshot.data!.data() as Map<String, dynamic>?;

        // CONTROLLO FLAG
        bool requiresChange = userData?['requires_password_change'] ?? false;

        if (requiresChange) {
          // BLOCCA LA NAVIGAZIONE e mostra solo la schermata cambio password
          return const ChangePasswordScreen();
        }

        // Se tutto ok, mostra l'app
        return child;
      },
    );
  }
}
