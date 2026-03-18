import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_service.dart';
import '../../../core/models/subscription.dart';

final subscriptionProvider = AsyncNotifierProvider<SubscriptionNotifier, SubscriptionInfo>(
  SubscriptionNotifier.new,
);

class SubscriptionNotifier extends AsyncNotifier<SubscriptionInfo> {
  @override
  Future<SubscriptionInfo> build() => _fetch();

  Future<SubscriptionInfo> _fetch() async {
    final json = await ApiService.instance.getSubscription();
    return SubscriptionInfo.fromJson(json);
  }

  Future<void> upgrade(String tier) async {
    await ApiService.instance.upgradeTier(tier);
    ref.invalidateSelf();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
