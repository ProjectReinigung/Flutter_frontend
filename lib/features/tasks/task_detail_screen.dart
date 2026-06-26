import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
  final pendingImages = <Uint8List>[];
  bool busy = false;
  bool submittingReview = false;
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
            (loadedImages.isNotEmpty || pendingImages.isNotEmpty) &&
            !isAdmin;
        final canComplete = task.status == TaskStatus.inReview && isAdmin;
        final canRemoveImages =
            !isAdmin &&
            task.status == TaskStatus.inProgress &&
            !submittingReview;
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
                    onPressed: busy || submittingReview ? null : _captureImage,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Take photo'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (snapshot.connectionState != ConnectionState.done &&
                pendingImages.isEmpty)
              const SizedBox(
                height: 180,
                child: LoadingView(message: 'Loading images'),
              )
            else if (snapshot.hasError)
              ErrorState(
                message: snapshot.error.toString(),
                onRetry: _reloadImages,
              )
            else if (loadedImages.isEmpty && pendingImages.isEmpty)
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
                      for (var index = 0; index < pendingImages.length; index++)
                        _PendingImageTile(
                          bytes: pendingImages[index],
                          submitting: submittingReview,
                          onPreview: () =>
                              _previewPendingImage(pendingImages[index]),
                          onRemove: () =>
                              setState(() => pendingImages.removeAt(index)),
                        ),
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
                onPressed: canSubmit && !busy && !submittingReview
                    ? () => _submitReview(loadedImages.length)
                    : null,
                icon: submittingReview
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  submittingReview
                      ? 'Submitting in background'
                      : 'Submit for review',
                ),
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
    if (bytes.isEmpty) {
      setState(() => error = 'The captured photo is empty. Retake it.');
      return;
    }
    setState(() {
      pendingImages.add(bytes);
      error = null;
      success = 'Photo ready. It will upload when you submit the review.';
    });
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

  Future<void> _previewPendingImage(Uint8List bytes) {
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      ),
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

  void _submitReview(int uploadedImageCount) {
    final imagesToUpload = List<Uint8List>.from(pendingImages);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      submittingReview = true;
      error = null;
      success =
          'Review submission started. You will be notified when it is done.';
    });
    messenger.showSnackBar(
      const SnackBar(content: Text('Review submission started.')),
    );
    unawaited(
      _submitReviewInBackground(imagesToUpload, uploadedImageCount, messenger),
    );
  }

  Future<void> _submitReviewInBackground(
    List<Uint8List> imagesToUpload,
    int uploadedImageCount,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      final imageApi = TaskImagesApi(widget.authController.apiClient);
      for (var index = 0; index < imagesToUpload.length; index++) {
        await imageApi.upload(
          task.id,
          TaskImage(
            id: 0,
            order: uploadedImageCount + index + 1,
            imageData: base64Encode(imagesToUpload[index]),
          ),
        );
      }
      await TasksApi(widget.authController.apiClient).submitReview(task.id);
      final updatedTask = await TasksApi(
        widget.authController.apiClient,
      ).task(task.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Review submitted successfully.')),
      );
      if (mounted) {
        setState(() {
          task = updatedTask;
          pendingImages.clear();
          submittingReview = false;
          success = 'Review submitted successfully.';
        });
        widget.onTaskChanged();
        _reloadImages();
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Review submission failed: $e')),
      );
      if (mounted) {
        setState(() {
          submittingReview = false;
          error = e.toString();
        });
      }
    }
  }

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

class _PendingImageTile extends StatelessWidget {
  const _PendingImageTile({
    required this.bytes,
    required this.submitting,
    required this.onPreview,
    required this.onRemove,
  });

  final Uint8List bytes;
  final bool submitting;
  final VoidCallback onPreview;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onPreview,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(bytes, fit: BoxFit.cover),
            ),
          ),
        ),
        Positioned(
          left: 8,
          top: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Pending',
                style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
            child: IconButton(
              tooltip: 'Remove pending photo',
              onPressed: submitting ? null : onRemove,
              icon: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
            ),
          ),
        ),
      ],
    );
  }
}
