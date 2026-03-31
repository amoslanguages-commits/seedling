import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/buttons.dart';
import '../../widgets/mascot.dart';
import '../../widgets/backgrounds.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';


class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage = '';

  Future<void> _handleAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUp) {
        await AuthService().signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          displayName: _nameController.text.trim(),
        );
      } else {
        await AuthService().signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
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
      body: Stack(
        children: [
          const FloatingLeavesBackground(child: SizedBox.expand()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  const SizedBox(height: 60),
                  const SeedlingMascot(
                    size: 120,
                    state: MascotState.idle,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Seedling',
                    style: SeedlingTypography.heading1.copyWith(
                      color: SeedlingColors.seedlingGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Grow your vocabulary naturally',
                    style: SeedlingTypography.body.copyWith(
                      color: SeedlingColors.textPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 48),
                  if (_isSignUp)
                    _buildTextField(
                      controller: _nameController,
                      label: 'Display Name',
                      icon: Icons.person_outline,
                    ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    isPassword: true,
                  ),
                  if (_errorMessage != null && _errorMessage!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: SeedlingColors.error),
                      ),
                    ),
                  const SizedBox(height: 32),
                  if (_isLoading)
                    const CircularProgressIndicator(color: SeedlingColors.seedlingGreen)
                  else
                    OrganicButton(
                      text: _isSignUp ? 'CREATE ACCOUNT' : 'SIGN IN',
                      onPressed: _handleAuth,
                    ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp 
                        ? 'Already have an account? Sign In' 
                        : 'New to Seedling? Create Account',
                      style: const TextStyle(color: SeedlingColors.seedlingGreen),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('OR'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSocialButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: SeedlingColors.seedlingGreen),
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

  Widget _buildSocialButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _socialIcon(Icons.g_mobiledata, () => AuthService().signInWithGoogle()),
        const SizedBox(width: 24),
        _socialIcon(Icons.apple, () => AuthService().signInWithApple()),
      ],
    );
  }

  Widget _socialIcon(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SeedlingColors.cardBackground,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: SeedlingColors.deepRoot.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 32, color: SeedlingColors.textPrimary),
      ),
    );
  }
}
