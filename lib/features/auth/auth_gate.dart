import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import '../home/home_screen.dart';
import '../onboarding/permission_onboarding_screen.dart';
import '../onboarding/device_role_screen.dart';

const _onboardingCompleteKey = 'onboarding_complete';
const _deviceRoleKey = 'device_role'; // 'host' or 'parent'

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

/// Three-step gate after sign-in, each backed by a locally-persisted
/// (per-device, not per-account) flag:
///  1. Device role — host (reads this phone's SMS) or parent (viewer only).
///  2. Permission onboarding — host devices only; parent devices skip
///     straight past this, since they never request SMS access.
///  3. Home.
class _PostSignInGate extends StatefulWidget {
  const _PostSignInGate({super.key});

  @override
  State<_PostSignInGate> createState() => _PostSignInGateState();
}

class _PostSignInGateState extends State<_PostSignInGate> {
  bool _loading = true;
  String? _deviceRole;
  bool _onboardingComplete = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _deviceRole = prefs.getString(_deviceRoleKey);
      _onboardingComplete = prefs.getBool(_onboardingCompleteKey) ?? false;
      _loading = false;
    });
  }

  Future<void> _handleRoleSelected(DeviceRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceRoleKey, role.name);

    // A parent/viewer device has nothing further to onboard — it never
    // touches SMS permissions at all.
    if (role == DeviceRole.parent) {
      await prefs.setBool(_onboardingCompleteKey, true);
    }

    if (!mounted) return;
    setState(() {
      _deviceRole = role.name;
      _onboardingComplete = role == DeviceRole.parent;
    });
  }

  Future<void> _markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
    if (mounted) setState(() => _onboardingComplete = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.flow)),
      );
    }
    if (_deviceRole == null) {
      return DeviceRoleScreen(onSelected: _handleRoleSelected);
    }
    if (_deviceRole == DeviceRole.host.name && !_onboardingComplete) {
      return PermissionOnboardingScreen(onComplete: _markOnboardingComplete);
    }
    return const HomeScreen();
  }
}