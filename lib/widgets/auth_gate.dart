import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/home/enhanced_home.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (data) {
        // If we are in the middle of a password recovery flow
        if (data.event == AuthChangeEvent.passwordRecovery) {
          return const ResetPasswordScreen();
        }

        if (data.session != null) {
          return const EnhancedHomeScreen();
        } else {
          return const AuthScreen();
        }
      },
      loading: () =>
          const Scaffold(backgroundColor: Color(0xFF0b1910), body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => const AuthScreen(),
    );
  }
}
