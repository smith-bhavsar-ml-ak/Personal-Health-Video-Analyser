import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  static const _paths  = ['/', '/analyze', '/progress', '/plans', '/history'];
  static const _labels = ['Home', 'Analyze', 'Progress', 'Plans', 'History'];
  static const _icons  = [
    Icons.home_outlined,
    Icons.video_call_outlined,
    Icons.trending_up_outlined,
    Icons.calendar_month_outlined,
    Icons.history_outlined,
  ];
  static const _activeIcons = [
    Icons.home,
    Icons.video_call,
    Icons.trending_up,
    Icons.calendar_month,
    Icons.history,
  ];

  int _index(String location) {
    for (var i = 1; i < _paths.length; i++) {
      if (location.startsWith(_paths[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final current  = _index(location);
    final cs       = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outline)),
      ),
      child: BottomNavigationBar(
        currentIndex: current,
        onTap: (i) => context.go(_paths[i]),
        backgroundColor: cs.surface,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurfaceVariant,
        items: List.generate(
          _paths.length,
          (i) => BottomNavigationBarItem(
            icon:       Icon(_icons[i],       size: 24),
            activeIcon: Icon(_activeIcons[i], size: 24),
            label:      _labels[i],
            tooltip:    _labels[i],
          ),
        ),
      ),
    );
  }
}
