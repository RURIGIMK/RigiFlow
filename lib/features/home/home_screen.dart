import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../shared/widgets/flow_ribbon_background.dart';
import '../auth/auth_service.dart';
import '../ingestion/sms_listener_service.dart';
import '../ingestion/ingestion_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _initSmsListener();
  }

  Future<void> _initSmsListener() async {
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
                      child: Text('Hey, $name',
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
            ],
          ),
        ),
      ),
    );
  }
}