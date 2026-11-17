import 'package:event_hive/core/theme/app_theme.dart';
import 'package:event_hive/provider/common/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Checks that the logged-in student has a student ID and a department,
/// which the database requires before any registration.
///
/// Returns true when the registration may go on. When the profile is
/// incomplete it shows a dialog that offers to open the profile, and
/// returns false, so no request is sent to the database and no error is
/// produced. If the profile cannot be read, it returns true and lets the
/// database decide, because the database checks again anyway.
Future<bool> ensureProfileComplete(BuildContext context, WidgetRef ref) async {
  try {
    // Read it fresh: the student may have just filled it in.
    ref.invalidate(currentProfileProvider);
    final profile = await ref.read(currentProfileProvider.future);
    if (profile.isComplete) return true;
  } catch (e) {
    debugPrint('Could not check the profile: $e');
    return true;
  }

  // The screen may have been closed while the profile was loading.
  if (!context.mounted) return false;
  await showProfileRequiredDialog(context);
  return false;
}

/// Tells the student the profile needs a student ID and department, and
/// opens the edit screen if they choose to.
///
/// The navigation happens only after the dialog has closed and only if
/// [context] still belongs to a screen on display; a callback that runs
/// later (such as a snackbar action) must not use a screen's context.
Future<void> showProfileRequiredDialog(BuildContext context) async {
  final openProfile = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: kSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Complete your profile',
        style: TextStyle(
          fontFamily: 'serif',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: kTextMain,
        ),
      ),
      content: const Text(
        'Add your student ID and department before you register for an '
        'event. It only takes a moment.',
        style: TextStyle(fontSize: 14, color: kTextSub),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: kNavy,
            foregroundColor: Colors.white,
          ),
          child: const Text('Complete profile'),
        ),
      ],
    ),
  );

  if (openProfile == true && context.mounted) {
    context.push('/participant/profile/edit');
  }
}