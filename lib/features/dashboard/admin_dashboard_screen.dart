import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/services.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../shared/widgets/async_state.dart';
import '../../shared/widgets/responsive_dialog.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/task_card.dart';

enum AdminDashboardMode { overview, tasks }

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.authController,
    required this.mode,
    required this.onOpenTask,
  });
  final AuthController authController;
  final AdminDashboardMode mode;
  final ValueChanged<CleaningTask> onOpenTask;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<({List<CleaningTask> tasks, List<AppUser> users})> future =
      _load();
  final searchController = TextEditingController();
  String query = '';
  TaskStatus? statusFilter;

  Future<({List<CleaningTask> tasks, List<AppUser> users})> _load() async {
    return (
      tasks: await TasksApi(widget.authController.apiClient).allTasks(),
      users: await UsersApi(widget.authController.apiClient).all(),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({List<CleaningTask> tasks, List<AppUser> users})>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView(message: 'Loading operations');
        }
        if (snapshot.hasError) {
          return ErrorState(
            message: snapshot.error.toString(),
            onRetry: () => setState(() => future = _load()),
          );
        }
        final data = snapshot.data!;
        return widget.mode == AdminDashboardMode.overview
            ? _overview(context, data.tasks, data.users)
            : _tasks(context, data.tasks, data.users);
      },
    );
  }

  Widget _overview(
    BuildContext context,
    List<CleaningTask> tasks,
    List<AppUser> users,
  ) {
    final pending = tasks
        .where((task) => task.status == TaskStatus.inReview)
        .length;
    final active = tasks
        .where((task) => task.status != TaskStatus.reviewCompleted)
        .length;
    final recent = tasks.take(5).toList();
    return RefreshIndicator(
      onRefresh: () async => setState(() => future = _load()),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Operations dashboard',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          _MetricsGrid(
            children: [
              _Metric(
                label: 'Active tasks',
                value: active.toString(),
                icon: Icons.assignment_outlined,
              ),
              _Metric(
                label: 'Pending reviews',
                value: pending.toString(),
                icon: Icons.fact_check_outlined,
              ),
              _Metric(
                label: 'Workers',
                value: users
                    .where((user) => user.role == UserRole.worker)
                    .length
                    .toString(),
                icon: Icons.engineering_outlined,
              ),
              _Metric(
                label: 'Admins',
                value: users
                    .where((user) => user.role == UserRole.admin)
                    .length
                    .toString(),
                icon: Icons.admin_panel_settings_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SummaryPanel(tasks: tasks),
          const SizedBox(height: 20),
          Text(
            'Recent activity',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (recent.isEmpty)
            const SizedBox(
              height: 260,
              child: EmptyView(
                title: 'No task activity',
                subtitle:
                    'New assignments and review updates will appear here.',
              ),
            )
          else
            for (final task in recent)
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

  Widget _tasks(
    BuildContext context,
    List<CleaningTask> tasks,
    List<AppUser> users,
  ) {
    final visibleTasks = tasks.where(_matchesTaskFilters).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        return RefreshIndicator(
          onRefresh: () async => setState(() => future = _load()),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (compact) ...[
                Text(
                  'Tasks',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _taskSearchField()),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () => _showTaskDialog(users),
                      icon: const Icon(Icons.add_task),
                      tooltip: 'Create task',
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tasks',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _showTaskDialog(users),
                      icon: const Icon(Icons.add_task),
                      label: const Text('Create task'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _taskSearchField(),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: statusFilter == null,
                    onSelected: (_) => setState(() => statusFilter = null),
                  ),
                  for (final status in TaskStatus.values)
                    ChoiceChip(
                      label: Text(status.label),
                      selected: statusFilter == status,
                      onSelected: (_) => setState(() => statusFilter = status),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (visibleTasks.isEmpty)
                SizedBox(
                  height: 300,
                  child: EmptyView(
                    title: query.isEmpty && statusFilter == null
                        ? 'No tasks yet'
                        : 'No matching tasks',
                    subtitle: query.isEmpty && statusFilter == null
                        ? 'Create a task to start assigning work.'
                        : 'Adjust the search or status filter.',
                  ),
                )
              else
                for (final task in visibleTasks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TaskCard(
                          task: task,
                          onTap: () => widget.onOpenTask(task),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _showAssignDialog(task, users),
                            icon: const Icon(Icons.assignment_ind_outlined),
                            label: const Text('Assign'),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _taskSearchField() {
    return AppSearchField(
      controller: searchController,
      hintText: 'Search tasks by title, worker, status, location, or ID',
      onChanged: (value) => setState(() => query = value),
    );
  }

  Future<void> _showTaskDialog(List<AppUser> users) async {
    final title = TextEditingController();
    final description = TextEditingController();
    final workers = users
        .where((user) => user.role == UserRole.worker && user.enabled)
        .toList();
    AppUser? worker = workers.isEmpty ? null : workers.first;
    String? error;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => ResponsiveDialog(
          title: const Text('Create task'),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (title.text.trim().isEmpty || worker == null) {
                        setDialogState(
                          () => error = workers.isEmpty
                              ? 'Create an active worker first.'
                              : 'Title and worker are required.',
                        );
                        return;
                      }
                      try {
                        setDialogState(() {
                          saving = true;
                          error = null;
                        });
                        await TasksApi(widget.authController.apiClient).create(
                          CleaningTask(
                            id: 0,
                            title: title.text.trim(),
                            description: description.text.trim(),
                            status: TaskStatus.open,
                            assignedTo: worker!.id,
                            assignedBy: widget.authController.user!.id,
                          ),
                        );
                        if (context.mounted) Navigator.pop(context);
                        setState(() => future = _load());
                      } catch (e) {
                        setDialogState(() {
                          saving = false;
                          error = e.toString();
                        });
                      }
                    },
              child: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create'),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Task details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<AppUser>(
                initialValue: worker,
                decoration: const InputDecoration(labelText: 'Worker'),
                items: workers
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(
                          item.fullName.isEmpty ? item.username : item.fullName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => worker = value,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAssignDialog(CleaningTask task, List<AppUser> users) async {
    final workers = users
        .where((user) => user.role == UserRole.worker && user.enabled)
        .toList();
    AppUser? worker;
    for (final candidate in workers) {
      if (candidate.id == task.assignedTo) worker = candidate;
    }
    worker ??= workers.isEmpty ? null : workers.first;
    String? error;
    String workerQuery = '';
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredWorkers = workers
              .where((item) => _matchesWorkerSearch(item, workerQuery))
              .toList();
          return ResponsiveDialog(
            title: Text('Assign ${task.title}'),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (worker == null) {
                          setDialogState(
                            () => error = 'Select an active worker.',
                          );
                          return;
                        }
                        try {
                          setDialogState(() {
                            saving = true;
                            error = null;
                          });
                          await TasksApi(
                            widget.authController.apiClient,
                          ).assign(
                            taskId: task.id,
                            assignedTo: worker!.id,
                            assignedBy: widget.authController.user!.id,
                          );
                          if (context.mounted) Navigator.pop(context);
                          setState(() => future = _load());
                        } catch (e) {
                          setDialogState(() {
                            saving = false;
                            error = e.toString();
                          });
                        }
                      },
                child: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Assign'),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search workers',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setDialogState(() => workerQuery = value),
                ),
                const SizedBox(height: 12),
                if (filteredWorkers.isEmpty)
                  const SizedBox(
                    height: 180,
                    child: EmptyView(
                      title: 'No workers found',
                      subtitle: 'Try another name, email, username, or role.',
                    ),
                  )
                else
                  for (final candidate in filteredWorkers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _WorkerChoice(
                        user: candidate,
                        selected: worker?.id == candidate.id,
                        onTap: () => setDialogState(() => worker = candidate),
                      ),
                    ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _matchesTaskFilters(CleaningTask task) {
    if (statusFilter != null && task.status != statusFilter) return false;
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

  bool _matchesWorkerSearch(AppUser user, String query) {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) return true;
    return [
      user.username,
      user.firstname,
      user.lastname,
      user.email,
      user.role.label,
      user.role.apiName,
    ].whereType<String>().any((value) => value.toLowerCase().contains(text));
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.tasks});
  final List<CleaningTask> tasks;

  @override
  Widget build(BuildContext context) {
    final open = tasks.where((task) => task.status == TaskStatus.open).length;
    final inProgress = tasks
        .where((task) => task.status == TaskStatus.inProgress)
        .length;
    final completed = tasks
        .where((task) => task.status == TaskStatus.reviewCompleted)
        .length;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SummaryChip(label: 'Open', value: open),
                _SummaryChip(label: 'In progress', value: inProgress),
                _SummaryChip(label: 'Completed', value: completed),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(child: Text(value.toString())),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}

class _WorkerChoice extends StatelessWidget {
  const _WorkerChoice({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final AppUser user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
      child: ListTile(
        leading: Icon(
          selected ? Icons.check_circle : Icons.circle_outlined,
          color: selected ? scheme.primary : null,
        ),
        title: Text(
          user.fullName.isEmpty ? user.username : user.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            user.username,
            user.email,
            user.role.label,
          ].whereType<String>().join(' - '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 900
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

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
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
                    value,
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
