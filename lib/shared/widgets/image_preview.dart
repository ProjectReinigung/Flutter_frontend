import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class TaskImagePreview extends StatelessWidget {
  const TaskImagePreview({
    super.key,
    required this.base64Data,
    this.fit = BoxFit.cover,
  });

  final String base64Data;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final bytes = _decode(base64Data);
    if (bytes == null) {
      return const _ImageError();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.memory(
        bytes,
        fit: fit,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return const _ImageLoading();
        },
        errorBuilder: (context, error, stackTrace) => const _ImageError(),
      ),
    );
  }

  Uint8List? _decode(String value) {
    try {
      final normalized = value.contains(',') ? value.split(',').last : value;
      return base64Decode(normalized);
    } on FormatException {
      return null;
    }
  }
}

class _ImageLoading extends StatelessWidget {
  const _ImageLoading();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(height: 8),
            Text(
              'Image unavailable',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
