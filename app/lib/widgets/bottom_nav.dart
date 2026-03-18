import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';

/// 5-tab bottom navigation following the Strava / Strong pattern —
/// direct access to the 5 most-frequently-used destinations,
/// ordered by daily use frequency:
///   Home (dashboard+streak) → Analyze (core CTA) → Activity (steps, daily habit)
///   → Plans (today's workout) → Progress (analytics)
///
/// History, Library, AI Coach, Settings are all reachable from within these
/// primary screens or via the desktop sidebar.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  static const _tabs = [
    _Tab(
      path: '/',
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
    _Tab(
      path: '/analyze',
      label: 'Analyze',
      icon: Icons.video_call_outlined,
      activeIcon: Icons.video_call,
    ),
    _Tab(
      path: '/activity',
      label: 'Activity',
      icon: Icons.directions_walk_outlined,
      activeIcon: Icons.directions_walk,
    ),
    _Tab(
      path: '/plans',
      label: 'Plans',
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month,
    ),
    _Tab(
      path: '/progress',
      label: 'Progress',
      icon: Icons.trending_up_outlined,
      activeIcon: Icons.trending_up,
    ),
  ];

  int _currentIndex(String location) {
    for (var i = 1; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final current  = _currentIndex(location);
    final cs       = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final tab      = _tabs[i];
              final isActive = i == current;
              // "Analyze" gets a distinct primary accent even when inactive
              final isAnalyze = tab.path == '/analyze';

              final iconColor = isActive
                  ? cs.primary
                  : isAnalyze
                      ? AppColors.primary.withValues(alpha: 0.7)
                      : cs.onSurfaceVariant;

              final labelColor = isActive
                  ? cs.primary
                  : isAnalyze
                      ? AppColors.primary.withValues(alpha: 0.7)
                      : cs.onSurfaceVariant;

              return Expanded(
                child: InkWell(
                  onTap: () => context.go(tab.path),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Active indicator dot (above icon, like Strava)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isActive ? 20 : 0,
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Icon(
                        isActive ? tab.activeIcon : tab.icon,
                        size: 22,
                        color: iconColor,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 10,
                          color: labelColor,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _Tab({
    required this.path,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
