import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/models/user_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../profile/screens/edit_profile_screen.dart';
import '../../../widgets/app_shell.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _urlCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final url = await SecureStorage.instance.readServerUrl();
    _urlCtrl.text = url ?? 'http://localhost';
  }

  Future<void> _saveUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _saving = true);
    await ApiClient.instance.updateBaseUrl(url);
    setState(() => _saving = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Server URL saved')),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm == true) await ref.read(authProvider.notifier).logout();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final email     = ref.watch(authProvider).email;
    final profile   = ref.watch(profileProvider);
    final cs        = Theme.of(context).colorScheme;
    final isMobile  = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [if (isMobile) const ProfileIconButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileCard(profile: profile, email: email),
          const SizedBox(height: 16),

          const _SectionHeader('Appearance'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette_outlined, size: 20, color: cs.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Text('Theme', style: Theme.of(context).textTheme.labelLarge),
                  ],
                ),
                const SizedBox(height: 14),
                _ThemeToggle(
                  current: themeMode,
                  onChanged: (m) => ref.read(themeModeProvider.notifier).setMode(m),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (!kIsWeb) ...[
            const _SectionHeader('Connection'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Backend Server URL', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text('Enter the address of your PHVA backend',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      hintText: 'http://192.168.1.10',
                      prefixIcon: Icon(Icons.dns_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _saving ? null : _saveUrl,
                    child: _saving
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          const _SectionHeader('Danger Zone'),
          ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.outline),
            ),
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}

// ── Profile card ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final UserProfile profile;
  final String? email;
  const _ProfileCard({required this.profile, required this.email});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final stats = <_StatData>[
      if (profile.age != null)
        _StatData(label: 'Age', value: '${profile.age}', icon: Icons.cake_outlined),
      if (profile.heightCm != null)
        _StatData(label: 'Height', value: profile.displayHeight, icon: Icons.height),
      if (profile.weightKg != null)
        _StatData(label: 'Weight', value: profile.displayWeight, icon: Icons.monitor_weight_outlined),
      if (profile.bmi != null)
        _StatData(
          label: 'BMI',
          value: profile.bmi!.toStringAsFixed(1),
          sub: profile.bmiCategory,
          icon: Icons.analytics_outlined,
          valueColor: _bmiColor(profile.bmi!),
        ),
      if (profile.fitnessLevel != null)
        _StatData(
          label: 'Level',
          value: profile.fitnessLevel!.label,
          icon: Icons.fitness_center_outlined,
          valueColor: AppColors.primary,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProfileAvatar(profile: profile, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName?.isNotEmpty == true
                          ? profile.displayName!
                          : 'Set your name',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email ?? '—',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => context.push('/profile/edit'),
                icon: const Icon(Icons.edit_outlined, size: 20),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  side: BorderSide(color: cs.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),

          // ── Tags row (goal + activity + equipment) ───────────────────
          if (profile.primaryGoal != null || profile.activityLevel != null ||
              profile.equipment != null || profile.weeklyWorkoutTarget != null ||
              profile.targetWeightKg != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (profile.primaryGoal != null)
                  _InfoChip(
                    icon: Icons.flag_outlined,
                    label: profile.primaryGoal!.label,
                    color: AppColors.primary,
                  ),
                if (profile.activityLevel != null)
                  _InfoChip(
                    icon: Icons.bolt_outlined,
                    label: profile.activityLevel!.label,
                    color: AppColors.health,
                  ),
                if (profile.equipment != null)
                  _InfoChip(
                    icon: Icons.fitness_center_outlined,
                    label: profile.equipment!.label,
                    color: AppColors.info,
                  ),
                if (profile.weeklyWorkoutTarget != null)
                  _InfoChip(
                    icon: Icons.calendar_month_outlined,
                    label: '${profile.weeklyWorkoutTarget}×/week',
                    color: AppColors.warning,
                  ),
                if (profile.targetWeightKg != null)
                  _InfoChip(
                    icon: Icons.track_changes_outlined,
                    label: 'Target ${profile.displayTargetWeight}',
                    color: AppColors.primary.withValues(alpha: 0.8),
                  ),
              ],
            ),
          ],

          // ── Stats grid ────────────────────────────────────────────────
          if (stats.isNotEmpty) ...[
            const SizedBox(height: 20),
            LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 440;
              if (isWide) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < stats.length; i++) ...[
                        Expanded(child: _StatCard(data: stats[i])),
                        if (i < stats.length - 1) const SizedBox(width: 10),
                      ],
                    ],
                  ),
                );
              } else {
                const cardHeight = 122.0;
                final cardWidth = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: stats
                      .map((s) => SizedBox(
                            width: cardWidth,
                            height: cardHeight,
                            child: _StatCard(data: s),
                          ))
                      .toList(),
                );
              }
            }),
          ],
        ],
      ),
    );
  }

  Color _bmiColor(double bmi) {
    if (bmi < 18.5) return AppColors.info;
    if (bmi < 25)   return AppColors.health;
    if (bmi < 30)   return AppColors.warning;
    return AppColors.error;
  }
}

class _StatData {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color? valueColor;
  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    this.sub,
    this.valueColor,
  });
}

/// Individual stat card — no border, subtle fill, icon + large value + label.
class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = data.valueColor ?? cs.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(data.icon, size: 15, color: cs.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(
            data.value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (data.sub != null) ...[
            const SizedBox(height: 2),
            Text(
              data.sub!,
              style: TextStyle(
                fontSize: 11,
                color: color.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}


class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.20)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}

// ── Theme toggle ──────────────────────────────────────────────────────────────

class _ThemeToggle extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<ThemeMode>(
        expandedInsets: EdgeInsets.zero,
        segments: const [
          ButtonSegment(
            value: ThemeMode.light,
            icon: Icon(Icons.light_mode_outlined, size: 16),
            label: Text('Light'),
          ),
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(Icons.brightness_auto_outlined, size: 16),
            label: Text('Auto'),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(Icons.dark_mode_outlined, size: 16),
            label: Text('Dark'),
          ),
        ],
        selected: {current},
        onSelectionChanged: (s) => onChanged(s.first),
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          side: WidgetStatePropertyAll(
            BorderSide(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8, left: 4),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                letterSpacing: 1.0, fontWeight: FontWeight.w600),
        ),
      );
}
