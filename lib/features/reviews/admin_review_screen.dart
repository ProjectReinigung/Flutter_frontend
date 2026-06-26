import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/services.dart';
import '../../models/task.dart';
import '../../shared/widgets/async_state.dart';
import '../../shared/widgets/task_card.dart';

class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({
    super.key,
    required this.authController,
    required this.onOpenTask,
  });
  final AuthController authController;
  final ValueChanged<CleaningTask> onOpenTask;

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen> {
  late Future<List<CleaningTask>> future = TasksApi(
    widget.authController.apiClient,
  ).allTasks();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CleaningTask>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView(message: 'Loading review queue');
        }
        if (snapshot.hasError) {
          return ErrorState(
            message: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        final tasks = (snapshot.data ?? [])
            .where((task) => task.status == TaskStatus.inReview)
            .toList();
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Review queue',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (tasks.isEmpty)
              const SizedBox(
                height: 420,
                child: EmptyView(
                  title: 'No tasks waiting for review',
                  subtitle: 'Submitted worker tasks will appear here.',
                  icon: Icons.fact_check_outlined,
                ),
              )
            else
              for (final task in tasks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TaskCard(
                    task: task,
                    onTap: () => widget.onOpenTask(task),
                  ),
                ),
          ],
        );
      },
    );
  }

  void _reload() => setState(
    () => future = TasksApi(widget.authController.apiClient).allTasks(),
  );
}
