import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../shared/widgets/flow_ribbon_background.dart';
import '../auth/auth_service.dart';
import '../ingestion/sms_listener_service.dart';
import '../ingestion/ingestion_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../forecasting/forecasting_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final SignInGreeting _greeting;

  @override
  void initState() {
    super.initState();
    // Consumed exactly once per sign-in — see AuthService for why this
    // correctly reverts to the default greeting on a later app resume.
    _greeting = AuthService().consumePendingGreeting();
    _initSmsListener();
  }

  Future<void> _initSmsListener() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('device_role');
    if (role != 'host') return; // parent devices never touch SMS APIs

    final smsService = SmsListenerService();
    try {
      final state = await smsService
          .checkPermissionStatus()
          .timeout(const Duration(seconds: 5), onTimeout: () => SmsPermissionState.denied);
      if (state == SmsPermissionState.granted) {
        smsService.startListening();
      }
    } catch (_) {}
  }

  String _greetingText(String name) {
    switch (_greeting) {
      case SignInGreeting.newAccount:
        return 'Welcome to RigiFlow, $name';
      case SignInGreeting.returning:
        return 'Welcome back, $name';
      case SignInGreeting.none:
        return 'Hey, $name';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;
    final displayName = user?.displayName;
    final name = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim().split(' ').first
        : 'there';

    return Scaffold(
      body: FlowRibbonBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(_greetingText(name),
                          style: Theme.of(context).textTheme.headlineMedium,
                          overflow: TextOverflow.ellipsis)
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideX(begin: -0.1, end: 0),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: AppColors.textMuted),
                      tooltip: 'Sign Out',
                      onPressed: () => AuthService().signOut(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('System Status', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Text('Auth is live ✓', style: AppTheme.amountStyle(size: 22, color: AppColors.flow)),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15, end: 0),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const IngestionScreen()),
                    ),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('View Transactions'),
                  ),
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.15, end: 0),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ForecastingScreen()),
                    ),
                    icon: const Icon(Icons.insights),
                    label: const Text('Insights'),
                  ),
                ),
              ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.15, end: 0),
            ],
          ),
        ),
      ),
    );
  }
}