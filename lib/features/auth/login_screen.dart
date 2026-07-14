import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../shared/widgets/flow_ribbon_background.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleSignIn(Future<void> Function() signInMethod) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await signInMethod();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlowRibbonBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
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
                const SizedBox(height: 56),
                if (_isLoading)
                  const CircularProgressIndicator(color: AppColors.flow)
                else ...[
                  ElevatedButton.icon(
                    onPressed: () =>
                        _handleSignIn(() => _authService.signInWithGoogle()),
                    icon: const Icon(Icons.login),
                    label: const Text('Continue with Google'),
                  ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _handleSignIn(() => _authService.signInWithApple()),
                    icon: const Icon(Icons.apple),
                    label: const Text('Continue with Apple'),
                  ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.3, end: 0),
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
}