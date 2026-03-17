import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/analyze/screens/analyze_screen.dart';
import 'features/sessions/screens/history_screen.dart';
import 'features/sessions/screens/session_detail_screen.dart';
import 'features/assistant/screens/assistant_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/profile/screens/edit_profile_screen.dart';
import 'features/progress/screens/progress_screen.dart';
import 'features/plans/screens/plans_screen.dart';
import 'features/library/screens/library_screen.dart';
import 'widgets/app_shell.dart';

/// Bridges Riverpod auth state → GoRouter refreshListenable.
/// GoRouter requires a Listenable; this ChangeNotifier listens to authProvider
/// and calls notifyListeners() whenever auth state changes.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
}

final _routerNotifierProvider = Provider<_RouterNotifier>(
  (ref) => _RouterNotifier(ref),
);

final _routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(_routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isAuth = ref.read(authProvider).isAuthenticated;
      final isLogin = state.matchedLocation == '/login';
      if (!isAuth && !isLogin) return '/login';
      if (isAuth  &&  isLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/',          builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/analyze',   builder: (_, __) => const AnalyzeScreen()),
          GoRoute(path: '/history',   builder: (_, __) => const HistoryScreen()),
          GoRoute(
            path: '/sessions/:id',
            builder: (_, state) => SessionDetailScreen(
              sessionId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(path: '/assistant', builder: (_, __) => const AssistantScreen()),
          GoRoute(path: '/settings',       builder: (_, __) => const SettingsScreen()),
          GoRoute(path: '/profile/edit',  builder: (_, __) => const EditProfileScreen()),
          GoRoute(path: '/progress',      builder: (_, __) => const ProgressScreen()),
          GoRoute(path: '/plans',         builder: (_, __) => const PlansScreen()),
          GoRoute(
            path: '/plans/:id',
            builder: (_, state) => PlanDetailScreen(planId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/library',       builder: (_, __) => const LibraryScreen()),
        ],
      ),
    ],
  );
});

class PhvaApp extends ConsumerWidget {
  const PhvaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(_routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'PHVA',
      theme:      AppTheme.light,
      darkTheme:  AppTheme.dark,
      themeMode:  themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
