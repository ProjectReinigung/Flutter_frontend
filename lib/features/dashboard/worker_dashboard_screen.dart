import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/services.dart';
import '../../models/task.dart';
import '../../shared/widgets/async_state.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/task_card.dart';

enum WorkerDashboardMode { overview, tasks }

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({
    super.key,
    required this.authController,
    required this.mode,
    required this.onOpenTask,
  });
  final AuthController authController;
  final WorkerDashboardMode mode;
  final ValueChanged<CleaningTask> onOpenTask;

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  late Future<List<CleaningTask>> future = TasksApi(
    widget.authController.apiClient,
  ).myTasks();
  TaskStatus? filter;
  final searchController = TextEditingController();
  String query = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CleaningTask>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView(message: 'Loading assigned tasks');
        }
        if (snapshot.hasError) {
          return ErrorState(
            message: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final tasks = snapshot.data ?? [];
        return widget.mode == WorkerDashboardMode.overview
            ? _overview(context, tasks)
            : _tasks(context, tasks);
      },
    );
  }

  Widget _overview(BuildContext context, List<CleaningTask> tasks) {
    final dueSoon = tasks
        .where(
          (task) =>
              task.status != TaskStatus.reviewCompleted &&
              task.dueDate != null &&
              task.dueDate!.difference(DateTime.now()).inDays <= 3,
        )
        .length;
    final nextTasks = tasks
        .where((task) => task.status != TaskStatus.reviewCompleted)
        .take(5)
        .toList();
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Dashboard', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          _SummaryGrid(
            children: [
              _SummaryCard(
                label: 'Open',
                value: _count(tasks, TaskStatus.open),
                icon: Icons.assignment_outlined,
              ),
              _SummaryCard(
                label: 'In progress',
                value: _count(tasks, TaskStatus.inProgress),
                icon: Icons.cleaning_services_outlined,
              ),
              _SummaryCard(
                label: 'In review',
                value: _count(tasks, TaskStatus.inReview),
                icon: Icons.fact_check_outlined,
              ),
              _SummaryCard(
                label: 'Due soon',
                value: dueSoon,
                icon: Icons.event_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Next tasks', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (nextTasks.isEmpty)
            const SizedBox(
              height: 260,
              child: EmptyView(
                title: 'No active tasks',
                subtitle: 'New assignments will appear here.',
              ),
            )
          else
            for (final task in nextTasks)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TaskCard(
                  task: task,
                  dense: true,
                  onTap: () => widget.onOpenTask(task),
                ),
              ),
        ],
      ),
    );
  }

  Widget _tasks(BuildContext context, List<CleaningTask> tasks) {
    final visible = tasks.where(_matchesFilters).toList();
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Tasks', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          AppSearchField(
            controller: searchController,
            hintText: 'Search tasks by title, status, location, or ID',
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: filter == null,
                onSelected: (_) => setState(() => filter = null),
              ),
              for (final status in TaskStatus.values)
                ChoiceChip(
                  label: Text(status.label),
                  selected: filter == status,
                  onSelected: (_) => setState(() => filter = status),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            SizedBox(
              height: 360,
              child: EmptyView(
                title: 'No matching tasks',
                subtitle: query.isEmpty && filter == null
                    ? 'Assigned tasks will appear here.'
                    : 'Adjust the search or status filter.',
              ),
            )
          else
            for (final task in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TaskCard(
                  task: task,
                  onTap: () => widget.onOpenTask(task),
                ),
              ),
        ],
      ),
    );
  }

  void _reload() => setState(
    () => future = TasksApi(widget.authController.apiClient).myTasks(),
  );

  int _count(List<CleaningTask> tasks, TaskStatus status) {
    return tasks.where((task) => task.status == status).length;
  }

  bool _matchesFilters(CleaningTask task) {
    if (filter != null && task.status != filter) return false;
    final text = query.trim().toLowerCase();
    if (text.isEmpty) return true;
    return [
      task.id.toString(),
      task.title,
      task.description,
      task.status.label,
      task.status.apiName,
      task.location,
      task.priority,
      task.assignedTo.toString(),
    ].whereType<String>().any((value) => value.toLowerCase().contains(text));
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 800
            ? 4
            : constraints.maxWidth > 520
            ? 2
            : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: columns == 1 ? 3.2 : 2.2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: children,
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
