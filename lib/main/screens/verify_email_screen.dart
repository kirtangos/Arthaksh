import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    this.userName,
    this.userEmail,
  });

  final String? userName;
  final String? userEmail;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _timer;
  bool _checking = false;
  bool _resending = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  int _elapsedSeconds = 0;
  Timer? _elapsedTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
    _startElapsed();
    // Start initial cooldown because a verification link was just sent
    _startCooldown(60);
  }

  void _startPolling() {
    _timer?.cancel();
    _timer =
        Timer.periodic(const Duration(seconds: 3), (_) => _checkVerified());
  }

  void _startElapsed() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds += 1);
    });
  }

  Future<void> _checkVerified() async {
    if (_checking) return;
    _checking = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed != null && refreshed.emailVerified) {
        // Create user profile in Firestore only after email verification
        if (widget.userName != null && widget.userEmail != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set(
            {
              'name': widget.userName,
              'email': widget.userEmail,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verified!')),
        );
        // Navigate to Home and clear stack
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (_) {
      // ignore transient errors
    } finally {
      _checking = false;
    }
  }

  Future<void> _resend() async {
    if (_resending) return;
    if (_cooldownSeconds > 0) return;
    setState(() => _resending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent')),
      );
      // Reset elapsed waiting timer back to 00:00 on successful resend
      setState(() => _elapsedSeconds = 0);
      _startCooldown(60); // standard 60s cooldown after a successful resend
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = e.message ?? 'Failed to resend verification';
      if (e.code == 'too-many-requests') {
        msg = 'Too many requests. Please wait a bit before trying again.';
        // apply a longer cooldown to respect backend throttling
        _startCooldown(120);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldown(int seconds) {
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldownSeconds <= 1) {
        t.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cooldownTimer?.cancel();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final cs = base.colorScheme;
    final authTheme = base.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle:
              base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
    final email =
        widget.userEmail ?? FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your email'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Theme(
          data: authTheme,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We\'ve sent a verification link to',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Please tap the link in your email to verify. This page will automatically continue once verified.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _formatElapsed(_elapsedSeconds),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                ),
                if (_cooldownSeconds > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Resend after: ${_formatMMSS(_cooldownSeconds)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (_resending || _cooldownSeconds > 0)
                            ? null
                            : _resend,
                        icon: _resending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.mark_email_unread_rounded),
                        label: Text(_cooldownSeconds > 0
                            ? 'Resend in $_cooldownSeconds s'
                            : 'Resend email'),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatElapsed(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return 'Time waiting: $m:$s';
  }

  String _formatMMSS(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
