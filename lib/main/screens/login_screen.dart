import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email to reset password')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email')),
      );
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? 'Failed to send reset email';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged in')),
      );
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'Failed to sign in';
      if (e.code == 'user-not-found') {
        msg = 'Account does not exists. Please, register';
      } else if (e.code == 'wrong-password') {
        msg = 'Password is incorrect';
      } else if (e.code == 'invalid-credential') {
        // Some SDKs return this for wrong password
        msg = 'Password is incorrect';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final cs = base.colorScheme;
    // Auth-specific visual consistency
    final authTheme = base.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), // Reduced from 16,16 proportionally
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), // Reduced from 14 proportionally
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), // Reduced from 14 proportionally
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), // Reduced from 14 proportionally
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(44), // Reduced from 48 proportionally
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Reduced from 14 proportionally
          textStyle: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log in'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Theme(
          data: authTheme,
          child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20), // Reduced from 24,12,24,24 proportionally
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand header
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pie_chart_rounded, color: cs.primary, size: 18), // Reduced from default proportionally
                        const SizedBox(width: 6), // Reduced from 8 proportionally
                        Text(
                          'Arthaksh',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith( // Reduced from titleMedium
                                fontWeight: FontWeight.w700,
                                fontSize: 14, // Reduced proportionally
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8), // Reduced from 12 proportionally
                  Text(
                    'Welcome back',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge // Reduced from headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800, fontSize: 20), // Reduced proportionally
                  ),
                  const SizedBox(height: 4), // Reduced from 6 proportionally
                  Text(
                    'Log in to continue with Arthaksh',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall // Reduced from bodyMedium
                        ?.copyWith(color: cs.onSurface.withValues(alpha: 0.75), fontSize: 12), // Reduced proportionally
                  ),
                  const SizedBox(height: 16), // Reduced from 20 proportionally
                  Form(
                    key: _formKey,
                    child: Column(children: [
                      TextFormField(
                        controller: _emailCtrl,
                        autofillHints: const [AutofillHints.username, AutofillHints.email],
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter email';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10), // Reduced from 12 proportionally
                      TextFormField(
                        controller: _passCtrl,
                        autofillHints: const [AutofillHints.password],
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter password';
                          if (v.length < 6) return 'Minimum 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16), // Reduced from 20 proportionally
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : _login,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.login_rounded),
                          label: const Text('Log in'),
                        ),
                      ),
                      const SizedBox(height: 6), // Reduced from 8 proportionally
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _busy ? null : _sendReset,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12), // Reduced from 16 proportionally
                  // Bottom sign up link
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Don't have an account? ",
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12), // Reduced proportionally
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                          child: const Text('Sign up'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
}
