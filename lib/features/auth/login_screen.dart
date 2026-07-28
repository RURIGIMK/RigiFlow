import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../shared/widgets/flow_ribbon_background.dart';
import 'auth_service.dart';

enum _AuthMode { login, signUp }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAction(Future<void> Function() action) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Google/Apple sign-in is a single unified action — Firebase creates
  /// the account automatically if it's new. Rather than force an
  /// artificial "block and redirect" the way email/password does, we
  /// let the sign-in complete either way and simply tell the person
  /// afterward whether it was a new account or an existing one.
  Future<void> _handleOAuthSignIn(
      Future<UserCredential?> Function() signInMethod) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final credential = await signInMethod();
      if (credential == null) return; // user cancelled the provider dialog

      final isNewUser = credential.additionalUserInfo?.isNewUser ?? false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNewUser
                ? 'Account created — welcome to RigiFlow!'
                : 'Welcome back!'),
            backgroundColor: AppColors.surface,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _submitEmailForm() {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text;
    final password = _passwordController.text;

    _handleEmailAction(() => _mode == _AuthMode.login
        ? _authService.logInWithEmail(email, password)
        : _authService.signUpWithEmail(email, password));
  }

  void _switchMode(_AuthMode mode) {
    _emailController.clear();
    _passwordController.clear();
    _formKey.currentState?.reset();
    setState(() {
      _mode = mode;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == _AuthMode.login;

    return Scaffold(
      body: FlowRibbonBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.waves_rounded,
                      size: 48, color: AppColors.flow),
                ).animate().fadeIn(duration: 500.ms).scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1, 1)),
                const SizedBox(height: 24),
                Text('RigiFlow', style: Theme.of(context).textTheme.displayLarge)
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 500.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 8),
                Text(
                  'Your money, understood automatically.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
                const SizedBox(height: 40),

                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(child: _buildToggleTab('Log In', isLogin, () => _switchMode(_AuthMode.login))),
                      Expanded(child: _buildToggleTab('Sign Up', !isLogin, () => _switchMode(_AuthMode.signUp))),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 20),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: _inputDecoration('Email'),
                        validator: (value) {
                          if (value == null || !value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: _inputDecoration('Password'),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'At least 6 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 450.ms),

                const SizedBox(height: 20),

                if (_isLoading)
                  const CircularProgressIndicator(color: AppColors.flow)
                else ...[
                  ElevatedButton(
                    onPressed: _submitEmailForm,
                    child: Text(isLogin ? 'Log In' : 'Sign Up'),
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.textMuted.withOpacity(0.3))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or', style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      Expanded(child: Divider(color: AppColors.textMuted.withOpacity(0.3))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _handleOAuthSignIn(() => _authService.signInWithGoogle()),
                    icon: const Icon(Icons.login),
                    label: const Text('Continue with Google'),
                  ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _handleOAuthSignIn(() => _authService.signInWithApple()),
                    icon: const Icon(Icons.apple),
                    label: const Text('Continue with Apple'),
                  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3, end: 0),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.alert)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleTab(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.flow : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? AppColors.ink : AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}