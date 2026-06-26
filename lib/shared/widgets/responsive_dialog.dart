import 'package:flutter/material.dart';

class ResponsiveDialog extends StatelessWidget {
  const ResponsiveDialog({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
  });

  final Widget title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mobile = size.width < 640;
    return Dialog(
      insetPadding: EdgeInsets.all(mobile ? 12 : 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: mobile ? size.width - 24 : 720,
          maxHeight: mobile ? size.height - 24 : size.height * 0.84,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.titleLarge!,
                child: title,
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: child,
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
