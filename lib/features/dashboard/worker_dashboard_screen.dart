import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/services.dart';
import '../../models/task.dart';
import '../../shared/widgets/async_state.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/task_card.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({
    super.key,
    required this.authController,
    required this.onOpenTask,
  });
  final AuthController authController;
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
        final visible = tasks.where(_matchesFilters).toList();
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'My cleaning tasks',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              _Summary(tasks: tasks),
              const SizedBox(height: 16),
              AppSearchField(
                controller: searchController,
                hintText: 'Search tasks by title, status, location, or ID',
                onChanged: (value) => setState(() => query = value),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
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
      },
    );
  }

  void _reload() => setState(
    () => future = TasksApi(widget.authController.apiClient).myTasks(),
  );

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

class _Summary extends StatelessWidget {
  const _Summary({required this.tasks});
  final List<CleaningTask> tasks;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 800 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.6,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final status in TaskStatus.values)
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Center(
                  child: ListTile(
                    title: Text(
                      '${tasks.where((task) => task.status == status).length}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    subtitle: Text(status.label),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
