import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../shared/widgets/flow_ribbon_background.dart';
import '../ingestion/sms_listener_service.dart';

class PermissionOnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const PermissionOnboardingScreen({super.key, required this.onComplete});

  @override
  State<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends State<PermissionOnboardingScreen> {
  String _status = 'Setting up automatic tracking...';
  double _progressFraction = 0;
  int _matchedCount = 0;
  bool _showProgressBar = false;
  bool _showSkip = false;
  bool _completed = false;
  Timer? _skipTimer;

  @override
  void initState() {
    super.initState();
    _skipTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !_completed) setState(() => _showSkip = true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _runOnboarding());
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
    super.dispose();
  }

  void _finish() {
    if (_completed) return;
    _completed = true;
    _skipTimer?.cancel();
    widget.onComplete();
  }

  Future<void> _runOnboarding() async {
    final smsService = SmsListenerService();

    try {
      setState(() => _status = 'Requesting SMS access...');
      final permState = await smsService
          .requestPermissions()
          .timeout(const Duration(seconds: 15), onTimeout: () => SmsPermissionState.denied);

      final granted = permState == SmsPermissionState.granted;

      if (granted) {
        setState(() {
          _status = 'Scanning messages since last month...';
          _showProgressBar = true;
        });

        try {
          await smsService
              .importExistingInbox(
            onProgress: (progress) {
              if (!mounted) return;
              setState(() {
                _progressFraction = progress.fraction;
                _matchedCount = progress.matched;
                _status = progress.total == 0
                    ? 'Scanning...'
                    : 'Scanning message ${progress.scanned} of ${progress.total}';
              });
            },
          )
              .timeout(const Duration(seconds: 30), onTimeout: () => 0);
        } catch (_) {}

        if (mounted) {
          setState(() {
            _status = 'Enabling instant background tracking...';
            _showProgressBar = false;
          });
        }

        try {
          await smsService
              .requestBatteryOptimizationExemption()
              .timeout(const Duration(seconds: 10), onTimeout: () => false);
        } catch (_) {}

        smsService.startListening();
      }
    } catch (_) {
    } finally {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlowRibbonBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_showProgressBar)
                    const CircularProgressIndicator(color: AppColors.flow)
                        .animate()
                        .fadeIn(duration: 300.ms)
                  else
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: _progressFraction),
                            duration: const Duration(milliseconds: 250),
                            builder: (context, value, _) => LinearProgressIndicator(
                              value: value,
                              minHeight: 8,
                              backgroundColor: AppColors.surface,
                              valueColor: const AlwaysStoppedAnimation(AppColors.flow),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$_matchedCount transactions found so far',
                          style: AppTheme.amountStyle(size: 14, color: AppColors.flow),
                        ),
                      ],
                    ).animate().fadeIn(duration: 300.ms),
                  const SizedBox(height: 24),
                  Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (_showSkip) ...[
                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: _finish,
                      child: Text(
                        'Taking a while? Skip and continue →',
                        style: TextStyle(color: AppColors.textMuted.withOpacity(0.8)),
                      ),
                    ),
                  ].animate().fadeIn(duration: 400.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}