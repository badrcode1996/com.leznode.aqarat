import 'package:flutter/material.dart';

const Color _primaryDarkBlue = Color(0xFF0F2C59);

/// Blocking "please wait" dialog shown while a contract is being saved.
///
/// Saving uploads the attachments and then runs a Firestore transaction, which
/// on a slow connection is long enough that the button alone doesn't read as
/// progress. The barrier also stops a second tap creating a second contract.
///
/// Dismissal is the caller's job — always close it from a `finally`, or a
/// failure would leave the app stuck behind the barrier.
Future<void> showSavingDialog(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      // Back/Escape must not dismiss it: the write is already in flight.
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: _primaryDarkBlue),
              ),
              const SizedBox(width: 18),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _primaryDarkBlue),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
