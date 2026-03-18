class SubscriptionFeatures {
  final int analysesPerMonth;   // -1 = unlimited
  final bool shareCard;
  final bool customPlans;
  final bool exportData;
  final int voiceQueries;       // -1 = unlimited

  const SubscriptionFeatures({
    required this.analysesPerMonth,
    required this.shareCard,
    required this.customPlans,
    required this.exportData,
    required this.voiceQueries,
  });

  factory SubscriptionFeatures.fromJson(Map<String, dynamic> json) =>
      SubscriptionFeatures(
        analysesPerMonth: json['analyses_per_month'] as int? ?? 10,
        shareCard: json['share_card'] as bool? ?? false,
        customPlans: json['custom_plans'] as bool? ?? false,
        exportData: json['export_data'] as bool? ?? false,
        voiceQueries: json['voice_queries'] as int? ?? 5,
      );
}

class SubscriptionInfo {
  final String tier;
  final bool isActive;
  final int analysesUsed;
  final int analysesLimit;   // -1 = unlimited
  final DateTime? expiresAt;
  final SubscriptionFeatures features;

  const SubscriptionInfo({
    required this.tier,
    required this.isActive,
    required this.analysesUsed,
    required this.analysesLimit,
    required this.features,
    this.expiresAt,
  });

  bool get isUnlimited => analysesLimit == -1;
  bool get canAnalyze => isUnlimited || analysesUsed < analysesLimit;
  double get usageRatio => isUnlimited ? 0.0 : (analysesUsed / analysesLimit).clamp(0.0, 1.0);

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) => SubscriptionInfo(
        tier: json['tier'] as String? ?? 'free',
        isActive: json['is_active'] as bool? ?? true,
        analysesUsed: json['analyses_used'] as int? ?? 0,
        analysesLimit: json['analyses_limit'] as int? ?? 10,
        expiresAt: json['expires_at'] != null
            ? DateTime.tryParse(json['expires_at'] as String)
            : null,
        features: SubscriptionFeatures.fromJson(
          (json['features'] as Map<String, dynamic>?) ?? {},
        ),
      );
}
