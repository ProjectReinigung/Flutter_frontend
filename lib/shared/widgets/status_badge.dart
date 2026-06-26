import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/task.dart';
import '../../models/user.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final color = switch (status) {
      TaskStatus.open => colors.info,
      TaskStatus.inProgress => colors.warning,
      TaskStatus.inReview => Theme.of(context).colorScheme.primary,
      TaskStatus.reviewCompleted => colors.success,
    };
    return _Badge(label: status.label, color: color);
  }
}

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      UserRole.owner => Theme.of(context).colorScheme.tertiary,
      UserRole.admin => Theme.of(context).colorScheme.primary,
      UserRole.worker => Theme.of(context).extension<AppColors>()!.mint,
    };
    return _Badge(label: role.label, color: color);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
