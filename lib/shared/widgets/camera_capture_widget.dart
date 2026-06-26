import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraCaptureWidget extends StatefulWidget {
  const CameraCaptureWidget({super.key});

  static Future<Uint8List?> show(BuildContext context) {
    return showDialog<Uint8List>(
      context: context,
      builder: (context) => const Dialog(
        insetPadding: EdgeInsets.all(20),
        child: CameraCaptureWidget(),
      ),
    );
  }

  @override
  State<CameraCaptureWidget> createState() => _CameraCaptureWidgetState();
}

class _CameraCaptureWidgetState extends State<CameraCaptureWidget> {
  final picker = ImagePicker();
  Uint8List? bytes;
  bool capturing = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Take photo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: capturing ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 4 / 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: bytes == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Use the device camera to capture review evidence.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(bytes!, fit: BoxFit.cover),
                      ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: capturing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                OutlinedButton.icon(
                  onPressed: capturing ? null : _takePhoto,
                  icon: capturing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_camera_outlined),
                  label: Text(bytes == null ? 'Take photo' : 'Retake'),
                ),
                FilledButton.icon(
                  onPressed: bytes == null || capturing
                      ? null
                      : () => Navigator.pop(context, bytes),
                  icon: const Icon(Icons.check),
                  label: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    setState(() {
      capturing = true;
      error = null;
    });
    try {
      final allowed = await _ensureCameraPermission();
      if (!allowed) return;
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 78,
      );
      if (picked == null) return;
      final data = await picked.readAsBytes();
      if (data.isEmpty) {
        setState(() => error = 'The captured photo is empty. Retake it.');
        return;
      }
      setState(() => bytes = data);
    } catch (e) {
      setState(() => error = _cameraErrorMessage(e));
    } finally {
      if (mounted) setState(() => capturing = false);
    }
  }

  Future<bool> _ensureCameraPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.camera.status;
    if (status.isGranted || status.isLimited) return true;

    final requested = await Permission.camera.request();
    if (requested.isGranted || requested.isLimited) return true;

    if (requested.isPermanentlyDenied) {
      setState(() {
        error =
            'Camera permission is blocked. Enable it in system settings to take photos.';
      });
      await openAppSettings();
      return false;
    }

    setState(() {
      error = 'Camera permission is required to take task review photos.';
    });
    return false;
  }

  String _cameraErrorMessage(Object error) {
    if (kIsWeb) {
      return 'Camera access failed. Use HTTPS, allow camera permission, and make sure a camera is available.';
    }
    return 'Camera capture is not available or permission was denied on this device.';
  }
}
