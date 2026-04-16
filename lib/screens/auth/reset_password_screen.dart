import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';
import '../../core/supabase_config.dart';
import '../../widgets/buttons.dart';
import '../../widgets/mascot.dart';
import '../../widgets/backgrounds.dart';
import '../../widgets/notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  _ResetPasswordScreenState createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _success = false;
  bool _obscurePassword = true;

  Future<void> _resetPassword() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty) {
      SeedlingNotifications.showSnackBar(context, message: 'Please enter a new password');
      return;
    }

    if (password.length < 6) {
      SeedlingNotifications.showSnackBar(context, message: 'Password must be at least 6 characters');
      return;
    }

    if (password != confirmPassword) {
      SeedlingNotifications.showSnackBar(context, message: 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: password),
      );
      
      setState(() {
        _success = true;
      });

      if (mounted) {
        SeedlingNotifications.showDialog(
          context,
          title: 'Success!',
          message: 'Your password has been updated safely.',
          isError: false,
        );
      }

      // Wait a bit then redirect back to login (or home if session persists)
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        // We don't need to manually navigate because AuthGate will react 
        // to the session update or sign out.
      }
    } catch (e) {
      if (mounted) {
        SeedlingNotifications.showSnackBar(
          context,
          message: e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeedlingColors.background,
      body: Stack(
        children: [
          const FloatingLeavesBackground(child: SizedBox.expand()),
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  SeedlingMascot(
                    size: 120,
                    state: _success ? MascotState.happy : MascotState.thinking,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Reset Password',
                    style: SeedlingTypography.heading1.copyWith(
                      color: SeedlingColors.seedlingGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _success 
                        ? 'Your password has been updated!' 
                        : 'Enter your new password below.',
                    style: SeedlingTypography.body.copyWith(
                      color: SeedlingColors.textPrimary.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  if (!_success) ...[
                    _buildPasswordField(
                      controller: _passwordController,
                      label: 'New Password',
                    ),
                    const SizedBox(height: 16),
                    _buildPasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                    ),
                      const SizedBox(height: 16),
                    const SizedBox(height: 32),
                    if (_isLoading)
                      const CircularProgressIndicator(
                        color: SeedlingColors.seedlingGreen,
                      )
                    else
                      OrganicButton(
                        text: 'UPDATE PASSWORD',
                        onPressed: _resetPassword,
                      ),
                  ] else ...[
                    const SizedBox(height: 32),
                    const Icon(
                      Icons.check_circle_outline,
                      color: SeedlingColors.seedlingGreen,
                      size: 64,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: SeedlingColors.seedlingGreen),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: SeedlingColors.textSecondary,
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        filled: true,
        fillColor: SeedlingColors.cardBackground.withValues(alpha: 0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
