import 'package:flutter/material.dart';

const Color _primaryDarkBlue = Color(0xFF0F2C59);

/// Shows a non-dismissible spinner dialog with [message] while [task] runs,
/// then closes it and returns the task's result. The dialog is also closed if
/// [task] throws — the error is rethrown so callers can handle it.
///
/// Used while a receipt is being generated (the server-side PDF render takes a
/// moment) so the user sees "please wait" instead of a frozen screen.
Future<T> showProcessingWhile<T>(
  BuildContext context,
  Future<T> Function() task, {
  String message = 'چاوەڕوانبە، پسولە دروست دەبێت...',
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _primaryDarkBlue),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _primaryDarkBlue,
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
