import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'features/auth/auth_gate.dart';

/// App-wide messenger key — lets any screen show a SnackBar that
/// survives being navigated away from mid-call (e.g. right after a
/// sign-in success swaps this screen out for Home).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const RigiFlowApp());
}

class RigiFlowApp extends StatelessWidget {
  const RigiFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RigiFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      home: const AuthGate(),
    );
  }
}