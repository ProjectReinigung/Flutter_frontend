import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/services.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../shared/widgets/async_state.dart';
import '../../shared/widgets/responsive_dialog.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/task_card.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.authController,
    required this.onOpenTask,
  });
  final AuthController authController;
  final ValueChanged<CleaningTask> onOpenTask;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<({List<CleaningTask> tasks, List<AppUser> users})> future =
      _load();
  final searchController = TextEditingController();
  String query = '';

  Future<({List<CleaningTask> tasks, List<AppUser> users})> _load() async {
    return (
      tasks: await TasksApi(widget.authController.apiClient).allTasks(),
      users: await UsersApi(widget.authController.apiClient).all(),
    );
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
        final pending = data.tasks
            .where((task) => task.status == TaskStatus.inReview)
            .length;
        final visibleTasks = data.tasks.where(_matchesTaskSearch).toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Operations dashboard',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showTaskDialog(data.users),
                  icon: const Icon(Icons.add_task),
                  label: const Text('Create task'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 900 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _Metric(
                      label: 'Tasks',
                      value: data.tasks.length.toString(),
                      icon: Icons.assignment_outlined,
                    ),
                    _Metric(
                      label: 'Pending reviews',
                      value: pending.toString(),
                      icon: Icons.fact_check_outlined,
                    ),
                    _Metric(
                      label: 'Workers',
                      value: data.users
                          .where((user) => user.role == UserRole.worker)
                          .length
                          .toString(),
                      icon: Icons.engineering_outlined,
                    ),
                    _Metric(
                      label: 'Admins',
                      value: data.users
                          .where((user) => user.role == UserRole.admin)
                          .length
                          .toString(),
                      icon: Icons.admin_panel_settings_outlined,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            AppSearchField(
              controller: searchController,
              hintText:
                  'Search tasks by title, worker, status, location, or ID',
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 16),
            Text(
              'Recent task activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (visibleTasks.isEmpty)
              SizedBox(
                height: 300,
                child: EmptyView(
                  title: query.isEmpty ? 'No tasks yet' : 'No matching tasks',
                  subtitle: query.isEmpty
                      ? 'Create a task to start assigning work.'
                      : 'Try a different search term.',
                ),
              )
            else
              for (final task in visibleTasks.take(12))
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
                          onPressed: () => _showAssignDialog(task, data.users),
                          icon: const Icon(Icons.assignment_ind_outlined),
                          label: const Text('Assign'),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        );
      },
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

  bool _matchesTaskSearch(CleaningTask task) {
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
        title: Text(user.fullName.isEmpty ? user.username : user.fullName),
        subtitle: Text(
          [
            user.username,
            user.email,
            user.role.label,
          ].whereType<String>().join(' - '),
        ),
        onTap: onTap,
      ),
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
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                  Text(label),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
