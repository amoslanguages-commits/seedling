import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/app_providers.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../services/subscription_service.dart';
import '../../services/iap_service.dart';
import '../../widgets/buttons.dart';
import '../../widgets/notifications.dart';
import '../../core/colors.dart';
import '../../core/typography.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _isPolling = false;
  bool _isAutoRedirecting = false;
  StreamSubscription? _iapStatusSub;
  Map<String, dynamic>? _paymentConfig;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    _iapStatusSub = IapService.instance.purchaseStatusStream.listen((status) {
      if (status == PurchaseStatus.purchased) {
        ref.invalidate(isPremiumProvider);
        Navigator.pop(context);
      }
    });

    _fetchPaymentConfig();
  }

  Future<void> _fetchPaymentConfig() async {
    try {
      final config = await SubscriptionService().getPaymentConfig();
      if (mounted) setState(() => _paymentConfig = config);
    } catch (e) {
      debugPrint('Geo-detect failed: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _iapStatusSub?.cancel();
    super.dispose();
  }

  /// Opens the chosen checkout provider (Lemon Squeezy or Flutterwave) in the browser.
  /// After the user returns to the app, polls Supabase for up to 60s
  /// waiting for the webhook to activate their subscription.
  Future<void> _handleUnlock({
    required String planId,
    String? provider,
  }) async {
    setState(() => _isLoading = true);
    try {
      // 1. Resolve checkout URL based on provider
      String checkoutUrl;
      final selectedProvider = provider ?? _paymentConfig?['primary_provider'] ?? 'lemonsqueezy';

      switch (selectedProvider) {
        case 'flutterwave':
          checkoutUrl = await SubscriptionService().createFlutterwaveCheckoutSession(planId);
          break;
        case 'dlocal':
          checkoutUrl = await SubscriptionService().createDLocalCheckoutSession(planId);
          break;
        default:
          checkoutUrl = await SubscriptionService().createCheckoutSession(planId);
      }

      if (!mounted) return;

      // 2. Launch in external browser
      final uri = Uri.parse(checkoutUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw const SubscriptionException('Could not open the payment page.');
      }

      // 3. Show "waiting for payment" state while polling
      setState(() {
        _isLoading = false;
        _isPolling = true;
      });

      // 4. Poll Supabase every 3s for up to 60s for webhook to fire
      final activated = await _pollForActivation();
      if (!mounted) return;

      setState(() => _isPolling = false);

      if (activated) {
        ref.invalidate(isPremiumProvider);
        SeedlingNotifications.showSnackBar(
          context,
          message: 'Welcome to Seedling Premium! 🌱',
          isError: false,
        );
        Navigator.pop(context);
      } else {
        SeedlingNotifications.showSnackBar(
          context,
          message: 'Processing payment... Access will activate shortly! 🌿',
          isError: false,
        );
        Navigator.pop(context);
      }
    } on SubscriptionException catch (e) {
      if (mounted) SeedlingNotifications.showSnackBar(context, message: e.message);
    } catch (e) {
      if (mounted) SeedlingNotifications.showSnackBar(context, message: 'Something went wrong.');
    } finally {
      if (mounted) setState(() { _isLoading = false; _isPolling = false; });
    }
  }

  /// Polls Supabase every 3 seconds for up to 60 seconds for subscription activation.
  /// Returns true if premium was detected, false if timed out.
  Future<bool> _pollForActivation({int maxAttempts = 20}) async {
    for (int i = 0; i < maxAttempts; i++) {
      await Future.delayed(const Duration(seconds: 3));
      await SubscriptionService().checkSubscription();
      if (SubscriptionService().isPremium) return true;
    }
    return false;
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
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: Column(
                children: [
                  if (SubscriptionService().isGracePeriod)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Payment issue detected. Please update your payment method within 3 days to avoid losing access.',
                              style: SeedlingTypography.body.copyWith(
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                      'The ultimate companion for your botanical language journey.',
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
                      Icons.local_florist_rounded,
                      'Unlimited Daily Growth',
                      'Nurture as many new words as you desire every single day.',
                    ),
                  ),
                  _staggeredSlide(
                    4,
                    _buildGlassFeatureRow(
                      Icons.category_rounded,
                      'Full Course Access',
                      'Instant access to all 20+ specialized Topic Gems and rare vocabulary.',
                    ),
                  ),
                  _staggeredSlide(
                    5,
                    _buildGlassFeatureRow(
                      Icons.forum_rounded,
                      'Endless Language Practice',
                      'Practice unlimited grammar sentences to achieve total fluency faster.',
                    ),
                  ),
                  _staggeredSlide(
                    6,
                    _buildGlassFeatureRow(
                      Icons.all_inclusive_rounded,
                      'Infinite Study Sessions',
                      'Learn for as long as you want with unlimited daily review and focus time.',
                    ),
                  ),
                  _staggeredSlide(
                    7,
                    _buildGlassFeatureRow(
                      Icons.cloud_sync_rounded,
                      'Botanical Cloud Sync',
                      'Keep your entire botanical journey safely synced across all your devices.',
                    ),
                  ),

                  const SizedBox(height: 48),

                  _staggeredSlide(
                    8,
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
                    9,
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
          else if (_isPolling)
            Column(
              children: [
                const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: SeedlingColors.autumnGold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Waiting for payment confirmation…',
                  style: SeedlingTypography.caption.copyWith(
                    color: SeedlingColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete the payment in your browser,\nthen return here.',
                  style: SeedlingTypography.caption.copyWith(
                    color: SeedlingColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          else
            Column(
              children: [
                // 1. Native Store Button (Primary on Mobile)
                if ((Platform.isIOS || Platform.isAndroid) && IapService.instance.products.isNotEmpty)
                  Builder(builder: (context) {
                    final iap = IapService.instance;
                    final product = iap.products.firstWhere(
                      (p) => planId == 'premium_monthly' 
                        ? p.id == IapService.monthlyId 
                        : p.id == IapService.annualId,
                      orElse: () => iap.products.first,
                    );

                    return OrganicButton(
                      text: Platform.isIOS ? ' Pay with App Store' : 'Pay with Google Play',
                      onPressed: () => iap.buyProduct(product),
                      width: double.infinity,
                      isPremiumActiveMode: isBestValue,
                    );
                  })
                else
                  // Default Primary for Web/Desktop or if IAP products are not loaded
                  OrganicButton(
                    text: 'UPGRADE NOW',
                    onPressed: () => _handleUnlock(planId: planId, provider: 'lemonsqueezy'),
                    width: double.infinity,
                    isPremiumActiveMode: isBestValue,
                  ),

                // 2. Secondary/Optional Buttons
                const SizedBox(height: 12),
                
                if ((Platform.isIOS || Platform.isAndroid) && IapService.instance.products.isNotEmpty)
                  // Show card option as secondary on mobile ONLY if IAP is available
                  TextButton.icon(
                    onPressed: () => _handleUnlock(planId: planId, provider: 'lemonsqueezy'),
                    icon: const Icon(Icons.credit_card_rounded, size: 18, color: SeedlingColors.textSecondary),
                    label: const Text('Pay with Credit Card'),
                    style: TextButton.styleFrom(
                      foregroundColor: SeedlingColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),

                if (_paymentConfig != null && _paymentConfig!['local_provider'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: () => _handleUnlock(
                        planId: planId, 
                        provider: _paymentConfig!['local_provider']
                      ),
                      icon: Icon(
                        _paymentConfig!['local_provider'] == 'flutterwave' 
                          ? Icons.phone_android_rounded 
                          : Icons.local_atm_rounded,
                        size: 18,
                        color: SeedlingColors.seedlingGreen,
                      ),
                      label: Text(
                        'Pay with ${_paymentConfig!['local_method_name']}',
                        style: const TextStyle(
                          color: SeedlingColors.seedlingGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                
                if (_paymentConfig == null) ...[
                  const SizedBox(height: 12),
                  // Loading shimmer for geo-detect
                  Container(
                    height: 48,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: SeedlingColors.textSecondary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            SeedlingColors.textSecondary.withOpacity(0.2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}
