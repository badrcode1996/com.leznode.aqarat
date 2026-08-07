import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';


/// Shows a non-dismissible spinner dialog with [message] while [task] runs,
/// then closes it and returns the task's result. The dialog is also closed if
/// [task] throws — the error is rethrown so callers can handle it.
///
/// Used while a receipt is being generated (the server-side PDF render takes a
/// moment) so the user sees "please wait" instead of a frozen screen.
Future<T> showProcessingWhile<T>(
  BuildContext context,
  Future<T> Function() task, {
  // Null means the standard wording — a translated string can't be a `const`
  // default value.
  String? message,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: AppColors.current.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.current.textStrong),
              const SizedBox(height: 20),
              Text(
                message ?? S.creatingReceipt,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.current.textStrong,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    return await task();
  } finally {
    navigator.pop();
  }
}
