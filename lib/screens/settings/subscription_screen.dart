import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/subscription_service.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cards.dart';
import '../../core/colors.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SubscriptionScreenState createState() => _SubscriptionScreenState();
}

// ignore: library_private_types_in_public_api
class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = false;

  Future<void> _handleUnlock() async {
    setState(() => _isLoading = true);
    try {
      await SubscriptionService().upgradeToPremium();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome to Seedling Premium! 🌱')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seedling Premium'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: SeedlingColors.textPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(
              Icons.stars_rounded,
              size: 80,
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            Text(
              'Grow Faster with Premium',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: SeedlingColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildFeatureRow(Icons.cloud_sync, 'Cloud Sync across all devices'),
            _buildFeatureRow(Icons.offline_pin, 'Unrestricted offline learning'),
            _buildFeatureRow(Icons.analytics, 'Advanced progress statistics'),
            _buildFeatureRow(Icons.group, 'Join community challenges'),
            _buildFeatureRow(Icons.psychology, 'AI-powered personalized path'),
            const SizedBox(height: 48),
            GrowingCard(
              child: Column(
                children: [
                  const Text(
                    'Annual Plan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '\$29.99 / year',
                    style: TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.bold,
                      color: SeedlingColors.seedlingGreen,
                    ),
                  ),
                  const Text('Save 50% compared to monthly'),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const CircularProgressIndicator(color: SeedlingColors.seedlingGreen)
                  else
                    OrganicButton(
                      text: 'UNLOCK PREMIUM',
                      onPressed: _handleUnlock,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Maybe Later',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: SeedlingColors.seedlingGreen),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
