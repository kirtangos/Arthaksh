import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _saving = false;
  String _saveStatus = '';
  Timer? _debounce;
  Timer? _verifyPollTimer;
  String? _pendingNewEmail;
  String _emailStatus = '';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? '';
    _nameController.addListener(_onNameChanged);
    // Optionally hydrate from Firestore if it has a canonical name
    _loadFromFirestore();
    _emailController.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _verifyPollTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _updateDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;
    setState(() => _saving = true);
    try {
      await user.updateDisplayName(newName);
      await user.reload();
      // Mirror into Firestore user profile
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'displayName': newName,
        'email': user.email,
        'emailVerified': user.emailVerified,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      setState(() {
        _saveStatus = 'All changes saved';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update name: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send email: $e')),
      );
    }
  }

  Future<void> _sendPasswordReset() async {
    final currentEmail = FirebaseAuth.instance.currentUser?.email;
    if (currentEmail == null || currentEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email found for this account')),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: currentEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $currentEmail')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reset email: $e')),
      );
    }
  }

  Future<void> _attemptEmailChange() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final newEmail = _emailController.text.trim();
    if (newEmail.isEmpty || newEmail == user.email) return;
    setState(() {
      _emailStatus = 'Sending verification to $newEmail...';
    });
    try {
      await user.verifyBeforeUpdateEmail(newEmail);
      _pendingNewEmail = newEmail;
      if (!mounted) return;
      setState(() {
        _emailStatus = 'Verification sent to $newEmail. Please verify from your inbox.';
      });
      _startVerificationPolling();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        await _reauthenticateAndRetryEmailChange();
      } else {
        if (!mounted) return;
        setState(() {
          _emailStatus = 'Email update failed: ${e.message ?? e.code}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _emailStatus = 'Email update failed: $e';
      });
    }
  }

  Future<void> _reauthenticateAndRetryEmailChange() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final newEmail = _emailController.text.trim();
    // Prompt simple password dialog for reauth
    final pwd = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Re-authenticate'),
          content: TextField(
            controller: ctrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Current password',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: const Text('Continue')),
          ],
        );
      },
    );
    if (pwd == null || pwd.isEmpty) return;
    try {
      final cred = EmailAuthProvider.credential(email: user.email!, password: pwd);
      await user.reauthenticateWithCredential(cred);
      await user.verifyBeforeUpdateEmail(newEmail);
      _pendingNewEmail = newEmail;
      if (!mounted) return;
      setState(() {
        _emailStatus = 'Verification sent to $newEmail. Please verify from your inbox.';
      });
      _startVerificationPolling();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _emailStatus = 'Re-authentication or email update failed: $e';
      });
    }
  }

  void _startVerificationPolling() {
    _verifyPollTimer?.cancel();
    // Poll every 3s up to ~3 minutes
    int tries = 0;
    _verifyPollTimer = Timer.periodic(const Duration(seconds: 3), (t) async {
      tries++;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed == null) return;
      if (_pendingNewEmail != null && refreshed.email == _pendingNewEmail && refreshed.emailVerified) {
        // Update Firestore and navigate home
        try {
          await FirebaseFirestore.instance.collection('users').doc(refreshed.uid).set({
            'email': refreshed.email,
            'emailVerified': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
        if (mounted) {
          setState(() {
            _emailStatus = 'Email verified. Redirecting...';
          });
          // Pop to root (HomeScreen) without importing main.dart to avoid circular deps
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        t.cancel();
      } else if (tries >= 60) { // stop after ~3 minutes
        setState(() {
          _emailStatus = 'Waiting for verification... You can verify later from your inbox.';
        });
        t.cancel();
      }
    });
  }

  void _onNameChanged() {
    // Debounce updates to avoid excessive writes while the user types
    _debounce?.cancel();
    setState(() {
      _saveStatus = 'Saving...';
    });
    _debounce = Timer(const Duration(milliseconds: 700), () async {
      await _updateDisplayName();
    });
  }

  Future<void> _loadFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data != null) {
        final name = (data['displayName'] ?? '').toString().trim();
        if (name.isNotEmpty && name != _nameController.text) {
          _nameController.text = name;
        }
      }
    } catch (_) {
      // Ignore; optional hydration
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFE6F7F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE6F7F5),
        title: const Text('My Profile'),
        scrolledUnderElevation: 0,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: cs.primary.withValues(alpha: 0.12),
                            child: Icon(Icons.person, color: cs.primary, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.displayName?.trim().isNotEmpty == true
                                      ? user!.displayName!.trim()
                                      : (user?.email ?? 'Anonymous'),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                if (user?.email != null)
                                  Text(
                                    user!.email!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: cs.onSurface.withValues(alpha: 0.7)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                const SizedBox(height: 6),
                                if (user != null)
                                  Row(
                                    children: [
                                      Icon(
                                        user.emailVerified
                                            ? Icons.verified_rounded
                                            : Icons.mark_email_unread_rounded,
                                        size: 18,
                                        color: user.emailVerified
                                            ? Colors.green
                                            : cs.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(user.emailVerified ? 'Email verified' : 'Email not verified'),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Account', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Display name',
                              prefixIcon: Icon(Icons.badge_rounded),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (_saving)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              if (_saving) const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  _saveStatus,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.green.shade700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.alternate_email_rounded),
                              suffixIcon: IconButton(
                                tooltip: 'Send verification to this email',
                                icon: const Icon(Icons.verified_rounded),
                                onPressed: () {
                                  _attemptEmailChange();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _emailStatus,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.blueGrey),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _sendPasswordReset,
                            icon: const Icon(Icons.lock_reset_rounded),
                            label: const Text('Forgot password'),
                          ),
                          const SizedBox(height: 12),
                          if (user != null && !user.emailVerified)
                            OutlinedButton.icon(
                              onPressed: _sendVerificationEmail,
                              icon: const Icon(Icons.mark_email_unread_rounded),
                              label: const Text('Send verification email'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
