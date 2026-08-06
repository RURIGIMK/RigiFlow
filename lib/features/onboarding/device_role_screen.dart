import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme.dart';
import '../../shared/widgets/flow_ribbon_background.dart';

enum DeviceRole { host, parent }

/// Asked once per device install (not per account) — a "host" device
/// reads this phone's own SMS automatically; a "parent"/viewer device
/// never requests SMS access at all and only ever displays data synced
/// from elsewhere.
class DeviceRoleScreen extends StatelessWidget {
  final void Function(DeviceRole role) onSelected;
  const DeviceRoleScreen({super.key, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlowRibbonBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Which device is this?',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center)
                    .animate()
                    .fadeIn(duration: 400.ms),
                const SizedBox(height: 8),
                Text(
                  'This decides whether RigiFlow reads this phone\'s SMS.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 40),
                _RoleCard(
                  icon: Icons.smartphone,
                  title: 'This is my main phone',
                  description:
                  'RigiFlow will read M-Pesa & bank SMS on this device automatically.',
                  onTap: () => onSelected(DeviceRole.host),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.15, end: 0),
                const SizedBox(height: 16),
                _RoleCard(
                  icon: Icons.tablet_mac,
                  title: 'This is a second device',
                  description:
                  'View synced data here only — this device will never read SMS.',
                  onTap: () => onSelected(DeviceRole.parent),
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.15, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.textMuted.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.flow.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.flow),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(description, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}