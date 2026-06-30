import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Clears the navigation stack and returns to role selection after logout.
Future<void> logoutAndGoToRole(BuildContext context) async {
  await Supabase.instance.client.auth.signOut();
  if (!context.mounted) return;
  Navigator.of(context).pushNamedAndRemoveUntil('/role', (route) => false);
}

/// Wraps authenticated shells so back does not return to login screens.
Widget authShell({required Widget child}) {
  return PopScope(
    canPop: false,
    child: child,
  );
}
