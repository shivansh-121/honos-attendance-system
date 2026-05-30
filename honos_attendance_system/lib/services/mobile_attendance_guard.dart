import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app_theme.dart';

bool get isMobileAttendanceDevice {
  return !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
}

Future<void> showMobileAttendanceRequiredDialog(
  BuildContext context, {
  bool? isCheckOut,
}) {
  final actionText = isCheckOut == null
      ? 'mark attendance'
      : isCheckOut
          ? 'check out'
          : 'check in';
  final titleAction = isCheckOut == null
      ? 'Check In / Out'
      : isCheckOut
          ? 'Check Out'
          : 'Check In';

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.colors.bgSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Icon(Icons.smartphone, size: 52, color: context.colors.primary),
      title: Text(
        'Use Your Phone to $titleAction',
        style: TextStyle(
          color: context.colors.txtPrimary,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      content: Text(
        'Attendance with facial recognition and GPS is only available on the mobile app.\n\nPlease open the Honos app on your phone to $actionText.',
        style: TextStyle(color: context.colors.txtSec),
        textAlign: TextAlign.center,
      ),
      actions: [
        Center(
          child: FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got It'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}
