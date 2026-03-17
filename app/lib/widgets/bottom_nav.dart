import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({super.key});

  static const _paths  = ['/', '/analyze', '/history', '/assistant', '/settings'];
  static const _labels = ['Home', 'Analyze', 'History', 'Assistant', 'Settings'];
  static const _icons  = [
    Icons.home_outlined,
    Icons.video_call_outlined,
    Icons.history_outlined,
    Icons.mic_outlined,
    Icons.settings_outlined,
  ];
  static const _activeIcons = [
    Icons.home,
    Icons.video_call,
    Icons.history,
    Icons.mic,
    Icons.settings,
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
