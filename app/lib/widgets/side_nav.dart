import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/providers/auth_provider.dart';

// ── Nav item model ────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
}

// ── Section definitions ───────────────────────────────────────────────────────

const _primaryItems = [
  _NavItem(icon: Icons.home_outlined,       activeIcon: Icons.home,       label: 'Home',    path: '/'),
  _NavItem(icon: Icons.video_call_outlined, activeIcon: Icons.video_call, label: 'Analyze', path: '/analyze'),
];

const _trackItems = [
  _NavItem(icon: Icons.directions_walk_outlined, activeIcon: Icons.directions_walk, label: 'Activity',  path: '/activity'),
  _NavItem(icon: Icons.trending_up_outlined,     activeIcon: Icons.trending_up,    label: 'Progress',  path: '/progress'),
  _NavItem(icon: Icons.history_outlined,         activeIcon: Icons.history,        label: 'History',   path: '/history'),
];

const _planItems = [
  _NavItem(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month, label: 'Plans',   path: '/plans'),
  _NavItem(icon: Icons.menu_book_outlined,      activeIcon: Icons.menu_book,      label: 'Library', path: '/library'),
];

const _coachItems = [
  _NavItem(icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome, label: 'AI Coach', path: '/assistant'),
];

// ── SideNav ───────────────────────────────────────────────────────────────────

class SideNav extends ConsumerWidget {
  final VoidCallback? onCollapse;
  const SideNav({super.key, this.onCollapse});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final cs       = Theme.of(context).colorScheme;
    final auth     = ref.watch(authProvider);

    bool isActive(String path) {
      if (path == '/') return location == '/';
      return location.startsWith(path);
    }

    return Container(
      width: 240,
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Brand header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 14),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.fitness_center,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'PHVA',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(letterSpacing: 0.5),
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
          const SizedBox(height: 6),

          // ── Primary: Home + Analyze ──────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final item in _primaryItems)
                  _NavTile(
                    item: item,
                    isActive: isActive(item.path),
                    isPrimary: item.path == '/analyze',
                  ),

                const SizedBox(height: 4),
                _SectionLabel('TRACK'),

                for (final item in _trackItems)
                  _NavTile(item: item, isActive: isActive(item.path)),

                const SizedBox(height: 4),
                _SectionLabel('PLAN'),

                for (final item in _planItems)
                  _NavTile(item: item, isActive: isActive(item.path)),

                const SizedBox(height: 4),
                _SectionLabel('COACH'),

                for (final item in _coachItems)
                  _NavTile(item: item, isActive: isActive(item.path)),

                const SizedBox(height: 4),
              ],
            ),
          ),

          // ── Settings ────────────────────────────────────────────────────────
          Divider(height: 1, color: cs.outline),
          _NavTile(
            item: const _NavItem(
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
              label: 'Settings',
              path: '/settings',
            ),
            isActive: isActive('/settings'),
          ),

          // ── Profile footer ───────────────────────────────────────────────────
          Divider(height: 1, color: cs.outline),
          _ProfileTile(email: auth.email),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: cs.onSurfaceVariant,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

// ── Nav tile ──────────────────────────────────────────────────────────────────

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final bool isPrimary;
  const _NavTile({
    required this.item,
    required this.isActive,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // "Analyze" gets a filled primary look when active, tinted bg when idle
    final bgColor = isActive
        ? cs.primaryContainer
        : isPrimary
            ? AppColors.primary.withValues(alpha: 0.07)
            : Colors.transparent;

    final iconColor = isActive
        ? cs.primary
        : isPrimary
            ? AppColors.primary
            : cs.onSurfaceVariant;

    final textColor = isActive
        ? cs.primary
        : isPrimary
            ? AppColors.primary
            : cs.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(item.path),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  size: 20,
                  color: iconColor,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: isActive || isPrimary
                        ? FontWeight.w600
                        : FontWeight.w400,
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

// ── Profile footer ─────────────────────────────────────────────────────────────

class _ProfileTile extends StatelessWidget {
  final String? email;
  const _ProfileTile({this.email});

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final initials = _initials(email);

    return InkWell(
      onTap: () => context.go('/settings'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
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
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: cs.onSurfaceVariant),
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
