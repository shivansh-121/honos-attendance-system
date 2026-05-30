import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _login() async {
    final userText = _username.text.trim();
    if (userText.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Please enter username and password');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final error = await ref
          .read(authProvider.notifier)
          .login(userText, _password.text.trim());
      if (mounted) {
        setState(() => _loading = false);
        if (error != null) setState(() => _error = error);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'System error: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.bgBase,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            decoration: BoxDecoration(
              color: context.colors.bgSurface,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                    color: context.colors.bord,
                    blurRadius: 20,
                    offset: const Offset(0, 10))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.colors.bord),
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 70,
                    fit: BoxFit.contain,
                  ),
                ).animate().fadeIn(duration: 800.ms).scale(
                    begin: const Offset(0.7, 0.7), curve: Curves.elasticOut),

                const SizedBox(height: 28),
                Text('HONOS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: context.colors.txtPrimary,
                            letterSpacing: 1.2))
                    .animate()
                    .fadeIn(delay: 400.ms)
                    .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCirc),

                const SizedBox(height: 6),
                Text('ATTENDANCE SYSTEM',
                        style: TextStyle(
                            color: context.colors.txtSec,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0))
                    .animate()
                    .fadeIn(delay: 600.ms),

                const SizedBox(height: 40),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colors.red.withValues(alpha: 0.1),
                      border: Border.all(
                          color: context.colors.red.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: context.colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_error!,
                                style: TextStyle(
                                    color: context.colors.red, fontSize: 13))),
                      ],
                    ),
                  ).animate().shake(),
                  const SizedBox(height: 24),
                ],

                TextField(
                  controller: _username,
                  style: TextStyle(color: context.colors.txtPrimary),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline,
                        color: context.colors.txtSec),
                  ),
                ).animate().fadeIn(delay: 800.ms),

                const SizedBox(height: 16),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  style: TextStyle(color: context.colors.txtPrimary),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon:
                        Icon(Icons.lock_outline, color: context.colors.txtSec),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: context.colors.txtSec),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ).animate().fadeIn(delay: 900.ms),

                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: context.colors.bgBase,
                    backgroundColor:
                        context.colors.primary, // The dark `#161616` color

                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Sign In',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                ).animate().fadeIn(delay: 1000.ms).scale(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
