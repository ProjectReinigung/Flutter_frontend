import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/services.dart';
import '../../models/task.dart';
import '../../models/task_image.dart';
import '../../models/user.dart';
import '../../shared/widgets/async_state.dart';
import '../../shared/widgets/camera_capture_widget.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/image_preview.dart';
import '../../shared/widgets/status_badge.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.authController,
    required this.task,
    required this.onBack,
    required this.onTaskChanged,
  });
  final AuthController authController;
  final CleaningTask task;
  final VoidCallback onBack;
  final VoidCallback onTaskChanged;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late CleaningTask task = widget.task;
  late Future<List<TaskImage>> images = TaskImagesApi(
    widget.authController.apiClient,
  ).forTask(task.id);
  bool busy = false;
  bool uploadingImage = false;
  int? deletingImageId;
  String? error;
  String? success;

  bool get isAdmin => widget.authController.user?.role != UserRole.worker;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TaskImage>>(
      future: images,
      builder: (context, snapshot) {
        final loadedImages = snapshot.data ?? [];
        final canSubmit =
            task.status == TaskStatus.inProgress &&
            loadedImages.isNotEmpty &&
            !isAdmin;
        final canComplete = task.status == TaskStatus.inReview && isAdmin;
        final canRemoveImages =
            !isAdmin && task.status == TaskStatus.inProgress;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 220,
                    maxWidth: 720,
                  ),
                  child: Text(
                    task.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                StatusBadge(status: task.status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              task.description.isEmpty
                  ? 'No description provided.'
                  : task.description,
              softWrap: true,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _InfoTile(
                  icon: Icons.place_outlined,
                  label: 'Location',
                  value: task.location ?? 'Not provided',
                ),
                _InfoTile(
                  icon: Icons.flag_outlined,
                  label: 'Priority',
                  value: task.priority ?? 'Not provided',
                ),
                _InfoTile(
                  icon: Icons.event_outlined,
                  label: 'Due date',
                  value:
                      task.dueDate?.toLocal().toString().split('.').first ??
                      'Not provided',
                ),
                _InfoTile(
                  icon: Icons.person_outline,
                  label: 'Worker id',
                  value: '${task.assignedTo}',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Images',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (!isAdmin)
                  OutlinedButton.icon(
                    onPressed: busy ? null : _captureImage,
                    icon: uploadingImage
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_camera_outlined),
                    label: Text(uploadingImage ? 'Uploading' : 'Take photo'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState != ConnectionState.done)
              const SizedBox(
                height: 180,
                child: LoadingView(message: 'Loading images'),
              )
            else if (snapshot.hasError)
              ErrorState(
                message: snapshot.error.toString(),
                onRetry: _reloadImages,
              )
            else if (loadedImages.isEmpty)
              const SizedBox(
                height: 180,
                child: EmptyView(
                  title: 'No photos captured',
                  subtitle:
                      'Worker camera photos will appear as review evidence.',
                  icon: Icons.image_outlined,
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 900
                      ? 4
                      : constraints.maxWidth > 560
                      ? 3
                      : 2;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      for (final image in loadedImages)
                        _TaskImageTile(
                          image: image,
                          canRemove: canRemoveImages && !busy,
                          deleting: deletingImageId == image.id,
                          onPreview: () => _previewImage(image),
                          onRemove: () => _confirmRemoveImage(image),
                        ),
                    ],
                  );
                },
              ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (success != null) ...[
              const SizedBox(height: 12),
              Text(
                success!,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
            const SizedBox(height: 20),
            if (!isAdmin)
              FilledButton.icon(
                onPressed: canSubmit && !busy ? _submitReview : null,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Submit for review'),
              ),
            if (isAdmin)
              FilledButton.icon(
                onPressed: canComplete && !busy ? _completeReview : null,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Complete review'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _captureImage() async {
    final bytes = await CameraCaptureWidget.show(context);
    if (bytes == null) return;
    setState(() {
      busy = true;
      uploadingImage = true;
      error = null;
      success = null;
    });
    try {
      if (bytes.isEmpty) {
        setState(() => error = 'The captured photo is empty. Retake it.');
        return;
      }
      final loadedImages = await images;
      await TaskImagesApi(widget.authController.apiClient).upload(
        task.id,
        TaskImage(
          id: 0,
          order: loadedImages.length + 1,
          imageData: base64Encode(bytes),
        ),
      );
      task = await TasksApi(widget.authController.apiClient).task(task.id);
      widget.onTaskChanged();
      if (mounted) {
        setState(() => success = 'Photo uploaded successfully.');
      }
      _reloadImages();
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() {
        busy = false;
        uploadingImage = false;
      });
    }
  }

  Future<void> _confirmRemoveImage(TaskImage image) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Remove image?',
      message: 'Remove this image from the task?',
      confirmLabel: 'Remove',
    );
    if (!confirmed) return;
    setState(() {
      busy = true;
      deletingImageId = image.id;
      error = null;
      success = null;
    });
    try {
      await TaskImagesApi(
        widget.authController.apiClient,
      ).delete(task.id, image.id);
      widget.onTaskChanged();
      setState(() => success = 'Image removed.');
      _reloadImages();
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          deletingImageId = null;
        });
      }
    }
  }

  Future<void> _previewImage(TaskImage image) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: InteractiveViewer(
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: TaskImagePreview(base64Data: image.imageData),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReview() async => _transition(
    () => TasksApi(widget.authController.apiClient).submitReview(task.id),
  );
  Future<void> _completeReview() async => _transition(
    () => TasksApi(widget.authController.apiClient).completeReview(task.id),
  );

  Future<void> _transition(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
      success = null;
    });
    try {
      await action();
      task = await TasksApi(widget.authController.apiClient).task(task.id);
      widget.onTaskChanged();
      _reloadImages();
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => busy = false);
    }
  }

  void _reloadImages() => setState(
    () => images = TaskImagesApi(
      widget.authController.apiClient,
    ).forTask(task.id),
  );
}

class _TaskImageTile extends StatelessWidget {
  const _TaskImageTile({
    required this.image,
    required this.canRemove,
    required this.deleting,
    required this.onPreview,
    required this.onRemove,
  });

  final TaskImage image;
  final bool canRemove;
  final bool deleting;
  final VoidCallback onPreview;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPreview,
            child: TaskImagePreview(base64Data: image.imageData),
          ),
        ),
        if (canRemove)
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
              child: IconButton(
                tooltip: 'Remove image',
                onPressed: deleting ? null : onRemove,
                icon: deleting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
