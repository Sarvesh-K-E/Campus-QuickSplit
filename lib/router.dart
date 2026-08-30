import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/groups_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/create_group_screen.dart';
import 'screens/group_detail_screen.dart';
import 'screens/add_expense_screen.dart';
import 'screens/main_screen.dart';

import 'screens/edit_group_screen.dart';
import 'screens/view_expense_screen.dart';
import 'screens/activity_log_screen.dart';
import 'screens/record_payment_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/receive_payment_screen.dart';
import 'screens/pending_payments_screen.dart';
import 'screens/optimization_graph_screen.dart';

import 'package:campus_quicksplit/screens/import_group_screen.dart';
import 'package:campus_quicksplit/screens/p2p_share_screen.dart';
import 'package:campus_quicksplit/screens/p2p_receive_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/p2p_share/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return P2PShareScreen(groupId: id);
      },
    ),
    GoRoute(
      path: '/p2p_receive',
      builder: (context, state) => const P2PReceiveScreen(),
    ),
    GoRoute(
      path: '/import_group',
      builder: (context, state) {
        final jsonStr = state.extra as String;
        return ImportGroupScreen(jsonStr: jsonStr);
      },
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainScreen(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: '/groups',
          pageBuilder: (context, state) => const NoTransitionPage(child: GroupsScreen()),
          routes: [
            GoRoute(
              path: 'create',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const CreateGroupScreen(),
            ),
            GoRoute(
              path: ':id',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return GroupDetailScreen(groupId: id);
              },
            ),
            GoRoute(
              path: ':id/add_expense',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                final expenseId = state.uri.queryParameters['expenseId'];
                return AddExpenseScreen(groupId: id, existingExpenseId: expenseId);
              },
            ),
            GoRoute(
              path: ':id/edit',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return EditGroupScreen(groupId: id);
              },
            ),
            GoRoute(
              path: ':id/view_expense',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                final expenseId = state.uri.queryParameters['expenseId']!;
                return ViewExpenseScreen(groupId: id, expenseId: expenseId);
              },
            ),

            GoRoute(
              path: ':id/record_payment',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return RecordPaymentScreen(groupId: id);
              },
            ),
            GoRoute(
              path: ':id/graph',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return OptimizationGraphScreen(groupId: id);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/activity',
          pageBuilder: (context, state) => const NoTransitionPage(child: ActivityLogScreen()),
        ),
        GoRoute(
          path: '/analytics',
          pageBuilder: (context, state) => const NoTransitionPage(child: AnalyticsScreen()),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => const NoTransitionPage(child: ProfileScreen()),
        ),
        GoRoute(
          path: '/receive',
          pageBuilder: (context, state) => const NoTransitionPage(child: ReceivePaymentScreen()),
        ),
        GoRoute(
          path: '/pending',
          pageBuilder: (context, state) => const NoTransitionPage(child: PendingPaymentsScreen()),
        ),
      ],
    ),
  ],
);
