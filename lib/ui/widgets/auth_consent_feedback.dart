import 'package:flutter/material.dart';

/// Make a missing user decision visible even when the form is scrolled or the
/// keyboard covers the agreement. This never changes a consent checkbox.
void showAuthConsentFeedback(
  BuildContext context,
  GlobalKey anchor,
  String message,
) {
  FocusScope.of(context).unfocus();
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final target = anchor.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 240),
        alignment: 0.4,
      );
    }
  });
}

class AuthConsentFeedback extends StatelessWidget {
  const AuthConsentFeedback({
    super.key,
    required this.child,
    this.message,
    this.messageKey,
  });
  final Widget child;
  final String? message;
  final Key? messageKey;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Material(
      color: message == null
          ? Colors.transparent
          : error.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: message == null ? Colors.transparent : error),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            child,
            if (message != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  message!,
                  key: messageKey,
                  style: TextStyle(color: error, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
