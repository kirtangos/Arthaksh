import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static Future<void> initialize() async {
    // Initialize/normalize user profile on every sign-in or registration
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await ensureUserProfile(user);
      }
    });
  }

  /// Ensure the signed-in user's Firestore profile exists and has standard fields.
  /// - Creates the doc if missing
  /// - Sets premium defaults ONLY when missing (never overwrite true values)
  /// - Normalizes common fields to keep a consistent shape across all users
  static Future<void> ensureUserProfile(User user) async {
    try {
      final users = FirebaseFirestore.instance.collection('users');
      final ref = users.doc(user.uid);
      final snap = await ref.get(const GetOptions(source: Source.server));

      // Derive a friendly name if displayName is empty
      String? name = user.displayName?.trim();
      if (name == null || name.isEmpty) {
        final email = user.email ?? '';
        name = email.contains('@') ? email.split('@').first : email;
        if (name.isEmpty) name = 'User';
      }

      final existing = snap.data();

      // Always-safe profile fields (won't clobber premium flags)
      final update = <String, dynamic>{
        'exists': true,
        'email': user.email,
        'emailVerified': user.emailVerified,
        'name': name,
        if (existing?['currency'] is! String) 'currency': 'INR',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!snap.exists) {
        // First-time profile creation: set defaults including premium flags
        await ref.set({
          ...update,
          'isPremium': false,
          'premiumFeatures': {
            'exportToExcel': false,
            'reminders': false,
            'insights': false,
          },
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        return;
      }

      // Existing profile: only set premium defaults if missing; do NOT overwrite
      if (existing?['isPremium'] == null) {
        update['isPremium'] = false;
      }
      final hasPF = existing?['premiumFeatures'] is Map;
      if (!hasPF) {
        update['premiumFeatures'] = {
          'exportToExcel': false,
          'reminders': false,
          'insights': false, // Disable insights by default for new users
        };
      } else {
        final pf =
            Map<String, dynamic>.from(existing!['premiumFeatures'] as Map);
        if (!pf.containsKey('exportToExcel')) {
          update['premiumFeatures.exportToExcel'] = false;
        }
        if (!pf.containsKey('reminders')) {
          update['premiumFeatures.reminders'] = false;
        }
        if (!pf.containsKey('insights')) {
          update['premiumFeatures.insights'] =
              true; // Enable insights by default for existing users
        }
      }

      if (update.isNotEmpty) {
        await ref.set(update, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[ensureUserProfile] Failed to init user profile: $e');
    }
  }

  static Future<User?> refreshUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload();
      } catch (_) {}
      return FirebaseAuth.instance.currentUser;
    }
    return null;
  }

  static User? get currentUser => FirebaseAuth.instance.currentUser;
  static Stream<User?> get authStateChanges =>
      FirebaseAuth.instance.authStateChanges();
}
