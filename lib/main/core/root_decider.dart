import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:arthaksh/main/screens/verify_email_screen.dart';
import 'package:arthaksh/main/screens/home_screen.dart';

class RootDecider extends StatelessWidget {
  const RootDecider({super.key});

  Future<User?> _refreshUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload();
      } catch (_) {}
      return FirebaseAuth.instance.currentUser;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<User?>(
      future: _refreshUser(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snap.data;
        if (user != null && user.emailVerified == false) {
          return const VerifyEmailScreen();
        }
        return const HomeScreen();
      },
    );
  }
}
