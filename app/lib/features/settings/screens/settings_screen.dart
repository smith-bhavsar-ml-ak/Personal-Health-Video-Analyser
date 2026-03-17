import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
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
    final cs        = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [if (MediaQuery.of(context).size.width < 768) const ProfileIconButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Account ─────────────────────────────────────────────────────
          const _SectionHeader('Account'),
          _InfoTile(
            icon: Icons.person_outline,
            label: 'Email',
            value: email ?? '—',
          ),
          const SizedBox(height: 16),

          // ── Appearance ──────────────────────────────────────────────────
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

          // ── Connection (mobile only) ─────────────────────────────────────
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
                  Text(
                    'Enter the address of your PHVA backend',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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

          // ── Danger zone ─────────────────────────────────────────────────
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

// ── Theme toggle (segmented) ──────────────────────────────────────────────────

class _ThemeToggle extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode_outlined, size: 18),
          label: Text('Light'),
        ),
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto_outlined, size: 18),
          label: Text('System'),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode_outlined, size: 18),
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
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(letterSpacing: 1.0, fontWeight: FontWeight.w600),
        ),
      );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ],
      ),
    );
  }
}
