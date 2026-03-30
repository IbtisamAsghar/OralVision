import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'login_view.dart';
import '../home/home_view.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the authentication state heavily connected to Supabase
    final authState = ref.watch(authViewModelProvider);
    
    // Automatically redirect based on authentication
    if (authState.isAuthenticated) {
      return const HomeView();
    }
    
    return const LoginView();
  }
}
