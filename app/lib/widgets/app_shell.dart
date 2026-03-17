import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/profile/providers/profile_provider.dart';
import 'bottom_nav.dart';
import 'side_nav.dart';

/// Whether the desktop/tablet sidebar is expanded. Toggled by the hamburger.
final sideNavExpandedProvider = StateProvider<bool>((ref) => true);

/// Adaptive shell:
/// - ≥ 768 px: collapsible 240 px sidebar + fluid content
/// - < 768 px: content + bottom navigation bar + profile in mobile app bars
class AppShell extends ConsumerWidget {
  final Widget child;
  const AppShell({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width      = MediaQuery.of(context).size.width;
    final isWide     = width >= 768;
    final isExpanded = ref.watch(sideNavExpandedProvider);
    final cs         = Theme.of(context).colorScheme;

    if (isWide) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Row(
          children: [
            if (isExpanded) ...[
              SideNav(
                onCollapse: () =>
                    ref.read(sideNavExpandedProvider.notifier).state = false,
              ),
              Container(width: 1, color: cs.outline),
            ] else ...[
              // Collapsed rail — just the hamburger icon
              Container(
                width: 56,
                color: cs.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 14),
                    IconButton(
                      icon: const Icon(Icons.menu, size: 22),
                      onPressed: () =>
                          ref.read(sideNavExpandedProvider.notifier).state = true,
                      tooltip: 'Expand sidebar',
                    ),
                  ],
                ),
              ),
              Container(width: 1, color: cs.outline),
            ],
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: const BottomNav(),
    );
  }
}

/// Shared profile icon button — add to any screen's AppBar actions on mobile.
class ProfileIconButton extends ConsumerWidget {
  const ProfileIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile  = ref.watch(profileProvider);
    final auth     = ref.watch(authProvider);
    final initials = profile.displayName?.isNotEmpty == true
        ? profile.initials
        : _emailInitials(auth.email);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => context.go('/settings'),
        child: CircleAvatar(
          radius: 17,
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
      ),
    );
  }

  static String _emailInitials(String? email) {
    if (email == null) return '?';
    final local = email.split('@').first;
    final parts = local.split(RegExp(r'[._-]'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return local.substring(0, local.length.clamp(0, 2)).toUpperCase();
  }
}
