import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String _strengthLabel = '';
  Color? _strengthColor;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final name = _nameCtrl.text.trim();
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      // Send verification email and go to VerifyEmailScreen which auto-redirects when verified
      await cred.user?.sendEmailVerification();
      if (!mounted) return;
      // Success toast/snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification email sent.')),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => VerifyEmailScreen(
          userName: name,
          userEmail: _emailCtrl.text.trim(),
        )),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      final msg = e.message ?? 'Registration failed';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final cs = base.colorScheme;
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
        title: const Text('Register'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Theme(
          data: authTheme,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;
                final horizontalPad = isWide ? (constraints.maxWidth - 560) / 2 : 24.0;
                final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(horizontalPad, 10, horizontalPad, 20 + bottomInset), // Reduced from 12,24 proportionally
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (isWide) ...[
                            Card(
                              elevation: 1,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Reduced from 16 proportionally
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), // Reduced from 24,20,24,24 proportionally
                                child: _buildRegisterForm(cs),
                              ),
                            ),
                          ] else ...[
                            _buildRegisterForm(cs),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  _PasswordStrength _evaluatePassword(String v) {
    final cs = Theme.of(context).colorScheme;
    if (v.isEmpty) return _PasswordStrength('', cs.error);
    int score = 0;
    if (v.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(v)) score++;
    if (RegExp(r'[a-z]').hasMatch(v)) score++;
    if (RegExp(r'[0-9]').hasMatch(v)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(v)) score++;

    if (score <= 2) return const _PasswordStrength('Weak', Colors.red);
    if (score == 3 || score == 4) return const _PasswordStrength('Medium', Colors.orange);
    return const _PasswordStrength('Strong', Colors.green);
  }

  Widget _buildRegisterForm(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Create your account',
          style: Theme.of(context)
              .textTheme
              .titleLarge // Reduced from headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800, fontSize: 20), // Reduced proportionally
        ),
        const SizedBox(height: 4), // Reduced from 6 proportionally
        Text(
          'Register to start using Arthaksh',
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
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter your name';
                if (v.trim().length < 2) return 'Name is too short';
                return null;
              },
            ),
            const SizedBox(height: 10), // Reduced from 12 proportionally
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
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
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
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
              onChanged: (v) {
                final res = _evaluatePassword(v);
                setState(() {
                  _strengthLabel = res.label;
                  _strengthColor = res.color;
                });
              },
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter password';
                if (v.length < 6) return 'Minimum 6 characters';
                return null;
              },
            ),
            if (_strengthLabel.isNotEmpty) ...[
              const SizedBox(height: 4), // Reduced from 6 proportionally
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Strength: $_strengthLabel',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: _strengthColor),
                ),
              ),
            ],
            const SizedBox(height: 10), // Reduced from 12 proportionally
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded),
                ),
              ),
              validator: (v) {
                if (v != _passCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 16), // Reduced from 20 proportionally
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _register,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Create account'),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

// Removed _RegisterForm; inlined into _RegisterScreenState via _buildRegisterForm

class _PasswordStrength {
  final String label;
  final Color color;
  const _PasswordStrength(this.label, this.color);
}
