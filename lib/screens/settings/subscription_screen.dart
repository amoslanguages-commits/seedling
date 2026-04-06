import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/subscription_service.dart';
import '../../widgets/buttons.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _handleUnlock([String planId = 'premium_annual']) async {
    setState(() => _isLoading = true);
    try {
      await SubscriptionService().upgradeToPremium(planId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome to Seedling Premium! 🌱')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _staggeredSlide(int index, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Interval(
        (index * 0.1).clamp(0.0, 1.0),
        1.0,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: child,
    );
  }

  Widget _orb(double size, Color color, double alpha) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          Colors.transparent,
        ],
      ),
    ),
  );

  Widget _buildBgMesh() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) => Stack(
        children: [
          Positioned(
            top: -100 + (math.sin(_pulseController.value * math.pi) * 20),
            right: -80 + (math.cos(_pulseController.value * math.pi) * 30),
            child: _orb(450, SeedlingColors.autumnGold, 0.25),
          ),
          Positioned(
            top: 150 + (math.cos(_pulseController.value * math.pi) * 40),
            left: -150 + (math.sin(_pulseController.value * math.pi) * 20),
            child: _orb(500, SeedlingColors.seedlingGreen, 0.15),
          ),
          Positioned(
            bottom: -50,
            left: 20,
            right: 20,
            child: _orb(300, SeedlingColors.waterBlue, 0.10),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: Container(color: Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassFeatureRow(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SeedlingColors.morningDew.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SeedlingColors.autumnGold.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: SeedlingColors.autumnGold, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SeedlingTypography.body.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: SeedlingTypography.caption.copyWith(
                    color: SeedlingColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SeedlingColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: SeedlingColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          _buildBgMesh(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: Column(
                children: [
                  _staggeredSlide(
                    0,
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, __) => Icon(
                        Icons.stars_rounded,
                        size: 80,
                        color: SeedlingColors.autumnGold.withValues(
                          alpha:
                              0.8 +
                              0.2 * math.sin(_pulseController.value * math.pi),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _staggeredSlide(
                    1,
                    Text(
                      'Grow Faster with Premium',
                      style: SeedlingTypography.heading1.copyWith(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _staggeredSlide(
                    2,
                    Text(
                      'Unlock your full language potential.',
                      style: SeedlingTypography.body.copyWith(
                        color: SeedlingColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),

                  _staggeredSlide(
                    3,
                    _buildGlassFeatureRow(
                      Icons.cloud_sync,
                      'Cloud Sync',
                      'Access your data across all devices',
                    ),
                  ),
                  _staggeredSlide(
                    4,
                    _buildGlassFeatureRow(
                      Icons.offline_pin,
                      'Offline Mode',
                      'Learn anywhere without restrictions',
                    ),
                  ),
                  _staggeredSlide(
                    5,
                    _buildGlassFeatureRow(
                      Icons.analytics,
                      'Advanced Stats',
                      'Track your progress beautifully',
                    ),
                  ),
                  _staggeredSlide(
                    6,
                    _buildGlassFeatureRow(
                      Icons.all_inclusive,
                      'Unlimited Challenges',
                      'Join any community arena instantly',
                    ),
                  ),

                  const SizedBox(height: 48),

                  _staggeredSlide(
                    7,
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, __) => Column(
                        children: [
                          _buildPlanCard(
                            title: 'Monthly Plan',
                            price: '\$9.99',
                            subtitle: ' / month',
                            planId: 'premium_monthly',
                            isBestValue: false,
                          ),
                          const SizedBox(height: 16),
                          _buildPlanCard(
                            title: 'Annual Plan',
                            price: '\$99.99',
                            subtitle: ' / year',
                            planId: 'premium_annual',
                            isBestValue: true,
                            discount: 'Save 16%',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  _staggeredSlide(
                    8,
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Maybe Later',
                        style: SeedlingTypography.caption.copyWith(
                          color: SeedlingColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String subtitle,
    required String planId,
    required bool isBestValue,
    String? discount,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SeedlingColors.cardBackground.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isBestValue
              ? SeedlingColors.autumnGold.withValues(
                  alpha: 0.3 + 0.3 * math.sin(_pulseController.value * math.pi),
                )
              : SeedlingColors.morningDew.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: isBestValue
            ? [
                BoxShadow(
                  color: SeedlingColors.autumnGold.withValues(
                    alpha:
                        0.15 + 0.1 * math.sin(_pulseController.value * math.pi),
                  ),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (discount != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: SeedlingColors.autumnGold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    discount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: SeedlingColors.autumnGold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                subtitle,
                style: SeedlingTypography.caption.copyWith(
                  color: SeedlingColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const CircularProgressIndicator(color: SeedlingColors.autumnGold)
          else
            OrganicButton(
              text: 'SELECT PLAN',
              onPressed: () => _handleUnlock(planId),
              width: double.infinity,
              isPremiumActiveMode: isBestValue,
            ),
        ],
      ),
    );
  }
}
