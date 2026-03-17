import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/providers/auth_provider.dart';

class SideNav extends ConsumerWidget {
  final VoidCallback? onCollapse;
  const SideNav({super.key, this.onCollapse});

  static const _items = [
    _NavItem(icon: Icons.home_outlined,         activeIcon: Icons.home,            label: 'Home',      path: '/'),
    _NavItem(icon: Icons.video_call_outlined,   activeIcon: Icons.video_call,      label: 'Analyze',   path: '/analyze'),
    _NavItem(icon: Icons.history_outlined,      activeIcon: Icons.history,         label: 'History',   path: '/history'),
    _NavItem(icon: Icons.trending_up_outlined,  activeIcon: Icons.trending_up,     label: 'Progress',  path: '/progress'),
    _NavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month, label: 'Plans',    path: '/plans'),
    _NavItem(icon: Icons.menu_book_outlined,    activeIcon: Icons.menu_book,       label: 'Library',   path: '/library'),
    _NavItem(icon: Icons.mic_outlined,          activeIcon: Icons.mic,             label: 'Assistant', path: '/assistant'),
    _NavItem(icon: Icons.settings_outlined,     activeIcon: Icons.settings,        label: 'Settings',  path: '/settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final cs       = Theme.of(context).colorScheme;
    final auth     = ref.watch(authProvider);

    return Container(
      width: 240,
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Brand header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.fitness_center, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'PHVA',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 0.5),
                  ),
                ),
                if (onCollapse != null)
                  IconButton(
                    icon: const Icon(Icons.menu_open, size: 20),
                    onPressed: onCollapse,
                    tooltip: 'Collapse sidebar',
                    visualDensity: VisualDensity.compact,
                    color: cs.onSurfaceVariant,
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.outline),
          const SizedBox(height: 8),

          // ── Nav items ─────────────────────────────────────────────────────
          for (final item in _items)
            _NavTile(item: item, isActive: _isActive(item.path, location)),

          const Spacer(),
          Divider(height: 1, color: cs.outline),

          // ── Profile footer ────────────────────────────────────────────────
          _ProfileTile(email: auth.email),
        ],
      ),
    );
  }

  bool _isActive(String itemPath, String current) {
    if (itemPath == '/') return current == '/';
    return current.startsWith(itemPath);
  }
}

// ── Nav tile ──────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  const _NavTile({required this.item, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: isActive ? cs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(item.path),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  size: 22,
                  color: isActive ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isActive ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Profile footer ────────────────────────────────────────────────────────────

class _ProfileTile extends StatelessWidget {
  final String? email;
  const _ProfileTile({this.email});

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final initials = _initials(email);

    return InkWell(
      onTap: () => context.go('/settings'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _displayName(email),
                    style: Theme.of(context).textTheme.labelLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'View profile',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  static String _initials(String? email) {
    if (email == null) return '?';
    final local = email.split('@').first;
    final parts = local.split(RegExp(r'[._-]'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return local.substring(0, local.length.clamp(0, 2)).toUpperCase();
  }

  static String _displayName(String? email) {
    if (email == null) return 'User';
    final local = email.split('@').first;
    return local[0].toUpperCase() + local.substring(1);
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  const _NavItem({
    required this.icon, required this.activeIcon,
    required this.label, required this.path,
  });
}
