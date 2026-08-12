import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
      // Without this, built-in widgets like showDateRangePicker have no
      // locale to format/parse typed dates against — that mismatch is
      // what caused "can't put in correct date/month". en_GB uses
      // day/month/year, matching how dates are naturally written and
      // typed in Kenya (unlike the US month/day/year default).
      locale: const Locale('en', 'GB'),
      supportedLocales: const [Locale('en', 'GB')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}