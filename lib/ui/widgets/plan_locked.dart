import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

Color get _accentYellow => AppColors.current.accent;

/// Friendly placeholder shown where a feature is hidden because the company's
/// subscription plan doesn't include it. Pure UI — the real enforcement lives in
/// the Firestore rules.
class PlanLocked extends StatelessWidget {
  const PlanLocked({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    watchAppShell(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _accentYellow.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_outline_rounded,
                  size: 48, color: _accentYellow),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: AppColors.current.textStrong,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
