import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme.dart';
import 'auth_service.dart';
import 'login_screen.dart';
import '../home/home_screen.dart';

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
          child = const HomeScreen(key: ValueKey('home'));
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