import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/subscription_provider.dart';

class PaywallScreen extends ConsumerStatefulWidget {
  final String? featureHint; // e.g. "share card" — shown as context
  const PaywallScreen({this.featureHint, super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _upgrade(String tier) async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(subscriptionProvider.notifier).upgrade(tier);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upgraded to ${tier.toUpperCase()}!'),
            backgroundColor: AppColors.health,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Plan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.featureHint != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: AppColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${widget.featureHint} requires a paid plan.',
                      style: TextStyle(color: cs.onSurface),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: const TextStyle(color: AppColors.error)),
            ),
            const SizedBox(height: 16),
          ],

          _TierCard(
            tier: 'free',
            label: 'Free',
            price: 'Free forever',
            color: cs.onSurfaceVariant,
            features: const [
              '10 video analyses / month',
              '5 exercises supported',
              'AI coaching feedback',
              'Workout planning',
              'Walking + step tracking',
              '5 voice queries / month',
            ],
            onSelect: null, // current plan button disabled
            isCurrent: ref.watch(subscriptionProvider).valueOrNull?.tier == 'free',
          ),
          const SizedBox(height: 12),

          _TierCard(
            tier: 'pro',
            label: 'Pro',
            price: '\$7.99 / month',
            color: AppColors.primary,
            features: const [
              '100 video analyses / month',
              '20 exercises supported',
              'AI coaching feedback',
              'Workout planning + share card',
              'Walking + GPS activity tracking',
              '50 voice queries / month',
              'Priority support',
            ],
            loading: _loading,
            onSelect: () => _upgrade('pro'),
            isCurrent: ref.watch(subscriptionProvider).valueOrNull?.tier == 'pro',
          ),
          const SizedBox(height: 12),

          _TierCard(
            tier: 'elite',
            label: 'Elite',
            price: '\$14.99 / month',
            color: AppColors.health,
            features: const [
              'Unlimited video analyses',
              '40+ exercises supported',
              'AI coaching feedback',
              'Custom workout plans + share card',
              'Full GPS activity tracking',
              'Unlimited voice queries',
              'Data export (CSV / PDF)',
              'Priority support',
            ],
            loading: _loading,
            onSelect: () => _upgrade('elite'),
            isCurrent: ref.watch(subscriptionProvider).valueOrNull?.tier == 'elite',
          ),

          const SizedBox(height: 24),
          Text(
            'MVP: payments are simulated. In production, Stripe handles billing.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final String tier;
  final String label;
  final String price;
  final Color color;
  final List<String> features;
  final VoidCallback? onSelect;
  final bool isCurrent;
  final bool loading;

  const _TierCard({
    required this.tier,
    required this.label,
    required this.price,
    required this.color,
    required this.features,
    required this.onSelect,
    this.isCurrent = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? color : cs.outline,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
              const Spacer(),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Current',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(price,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              )),
          const SizedBox(height: 12),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(f, style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          if (!isCurrent && onSelect != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: color),
                onPressed: loading ? null : onSelect,
                child: loading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Upgrade to $label'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
