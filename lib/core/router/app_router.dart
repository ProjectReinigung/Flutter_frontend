import 'package:flutter/material.dart';

import '../../features/auth/login_screen.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/dashboard/admin_dashboard_screen.dart';
import '../../features/dashboard/worker_dashboard_screen.dart';
import '../../features/reviews/admin_review_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/tasks/task_detail_screen.dart';
import '../../features/users/user_management_screen.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../shared/widgets/app_shell.dart';
import '../auth/auth_controller.dart';

class AppRouter extends StatefulWidget {
  const AppRouter({
    super.key,
    required this.authController,
    required this.settingsController,
  });
  final AuthController authController;
  final AppSettingsController settingsController;

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  int index = 0;
  int refreshVersion = 0;
  CleaningTask? selectedTask;

  @override
  Widget build(BuildContext context) {
    final auth = widget.authController;
    final user = auth.user;
    if (user == null) return LoginScreen(authController: auth);

    final items = _itemsFor(user.role);
    if (index >= items.length) index = 0;
    return AppShell(
      user: user,
      currentIndex: index,
      items: items,
      onSelect: (value) => setState(() {
        index = value;
        selectedTask = null;
      }),
      child: _screen(items[index].key, auth),
    );
  }

  Widget _screen(String key, AuthController auth) {
    if (selectedTask != null) {
      return TaskDetailScreen(
        authController: auth,
        task: selectedTask!,
        onTaskChanged: () => setState(() => refreshVersion++),
        onBack: () => setState(() => selectedTask = null),
      );
    }
    return switch (key) {
      'worker_home' => WorkerDashboardScreen(
        key: ValueKey('worker-$refreshVersion'),
        authController: auth,
        mode: WorkerDashboardMode.overview,
        onOpenTask: (task) => setState(() => selectedTask = task),
      ),
      'worker_tasks' => WorkerDashboardScreen(
        key: ValueKey('worker-tasks-$refreshVersion'),
        authController: auth,
        mode: WorkerDashboardMode.tasks,
        onOpenTask: (task) => setState(() => selectedTask = task),
      ),
      'admin_home' => AdminDashboardScreen(
        key: ValueKey('admin-$refreshVersion'),
        authController: auth,
        mode: AdminDashboardMode.overview,
        onOpenTask: (task) => setState(() => selectedTask = task),
      ),
      'admin_tasks' => AdminDashboardScreen(
        key: ValueKey('admin-tasks-$refreshVersion'),
        authController: auth,
        mode: AdminDashboardMode.tasks,
        onOpenTask: (task) => setState(() => selectedTask = task),
      ),
      'reviews' => AdminReviewScreen(
        key: ValueKey('reviews-$refreshVersion'),
        authController: auth,
        onOpenTask: (task) => setState(() => selectedTask = task),
      ),
      'users' => UserManagementScreen(authController: auth),
      'chat' => ChatScreen(authController: auth),
      'settings' => SettingsScreen(
        authController: auth,
        settingsController: widget.settingsController,
      ),
      _ => SettingsScreen(
        authController: auth,
        settingsController: widget.settingsController,
      ),
    };
  }

  List<AppNavItem> _itemsFor(UserRole role) {
    if (role == UserRole.worker) {
      return const [
        AppNavItem('worker_home', 'Dashboard', Icons.dashboard_outlined),
        AppNavItem('worker_tasks', 'Tasks', Icons.cleaning_services_outlined),
        AppNavItem('chat', 'Chat', Icons.chat_bubble_outline),
        AppNavItem('settings', 'Settings', Icons.tune_outlined),
      ];
    }
    if (role == UserRole.owner) {
      return const [
        AppNavItem('admin_home', 'Dashboard', Icons.dashboard_outlined),
        AppNavItem('admin_tasks', 'Tasks', Icons.assignment_outlined),
        AppNavItem('reviews', 'Reviews', Icons.fact_check_outlined),
        AppNavItem('users', 'Users', Icons.groups_outlined),
        AppNavItem('chat', 'Chat', Icons.chat_bubble_outline),
        AppNavItem('settings', 'Settings', Icons.tune_outlined),
      ];
    }
    return const [
      AppNavItem('admin_home', 'Dashboard', Icons.dashboard_outlined),
      AppNavItem('admin_tasks', 'Tasks', Icons.assignment_outlined),
      AppNavItem('reviews', 'Reviews', Icons.fact_check_outlined),
      AppNavItem('users', 'Users', Icons.groups_outlined),
      AppNavItem('chat', 'Chat', Icons.chat_bubble_outline),
      AppNavItem('settings', 'Settings', Icons.tune_outlined),
    ];
  }
}
