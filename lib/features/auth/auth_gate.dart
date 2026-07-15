import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import '../home/home_screen.dart';
import '../onboarding/permission_onboarding_screen.dart';

const _onboardingCompleteKey = 'onboarding_complete';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        Widget child;

        if (snapshot.hasError) {
          child = Scaffold(
            key: const ValueKey('error'),
            body: Center(
              child: Text('Auth Error: ${snapshot.error}',
                  style: const TextStyle(color: AppColors.alert)),
            ),
          );
        } else if (snapshot.connectionState == ConnectionState.waiting) {
          child = const Scaffold(
            key: ValueKey('loading'),
            body: Center(child: CircularProgressIndicator(color: AppColors.flow)),
          );
        } else if (snapshot.hasData) {
          child = const _PostSignInGate(key: ValueKey('post-sign-in'));
        } else {
          child = const LoginScreen(key: ValueKey('login'));
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (widget, animation) =>
              FadeTransition(opacity: animation, child: widget),
          child: child,
        );
      },
    );
  }
}

/// Decides between the one-time permission onboarding and the normal
/// Home screen, based on a locally-persisted flag (per device install).
class _PostSignInGate extends StatefulWidget {
  const _PostSignInGate({super.key});

  @override
  State<_PostSignInGate> createState() => _PostSignInGateState();
}

class _PostSignInGateState extends State<_PostSignInGate> {
  bool? _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final complete = prefs.getBool(_onboardingCompleteKey) ?? false;
    if (mounted) setState(() => _onboardingComplete = complete);
  }

  Future<void> _markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
    if (mounted) setState(() => _onboardingComplete = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingComplete == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.flow)),
      );
    }
    if (_onboardingComplete == false) {
      return PermissionOnboardingScreen(onComplete: _markOnboardingComplete);
    }
    return const HomeScreen();
  }
}