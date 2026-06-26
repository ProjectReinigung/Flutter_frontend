import 'package:flutter/material.dart';

import '../../models/user.dart';

class AppNavItem {
  const AppNavItem(this.key, this.label, this.icon);
  final String key;
  final String label;
  final IconData icon;
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.user,
    required this.currentIndex,
    required this.items,
    required this.onSelect,
    required this.child,
  });

  final AppUser user;
  final int currentIndex;
  final List<AppNavItem> items;
  final ValueChanged<int> onSelect;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool collapsed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final compactBottomLabels = constraints.maxWidth < 430;
        return Scaffold(
          body: Row(
            children: [
              if (wide)
                _Sidebar(
                  user: widget.user,
                  items: widget.items,
                  currentIndex: widget.currentIndex,
                  onSelect: widget.onSelect,
                  collapsed: collapsed,
                  onToggleCollapsed: () =>
                      setState(() => collapsed = !collapsed),
                ),
              Expanded(child: SafeArea(child: widget.child)),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  labelBehavior: compactBottomLabels
                      ? NavigationDestinationLabelBehavior.alwaysHide
                      : NavigationDestinationLabelBehavior.onlyShowSelected,
                  selectedIndex: widget.currentIndex,
                  onDestinationSelected: widget.onSelect,
                  destinations: [
                    for (final item in widget.items)
                      NavigationDestination(
                        icon: Icon(item.icon),
                        label: item.label,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.user,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    required this.collapsed,
    required this.onToggleCollapsed,
  });

  final AppUser user;
  final List<AppNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: collapsed ? 82 : 264,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      padding: EdgeInsets.all(collapsed ? 10 : 16),
      child: Column(
        crossAxisAlignment: collapsed
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (collapsed)
            Column(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primary,
                  child: const Icon(
                    Icons.cleaning_services,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                IconButton(
                  tooltip: 'Expand sidebar',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: onToggleCollapsed,
                ),
              ],
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: scheme.primary,
                child: const Icon(Icons.cleaning_services, color: Colors.white),
              ),
              title: Text(
                'Cleaning Manager',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              subtitle: Text(user.role.label),
              trailing: IconButton(
                tooltip: 'Collapse sidebar',
                icon: const Icon(Icons.chevron_left),
                onPressed: onToggleCollapsed,
              ),
            ),
          const SizedBox(height: 24),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NavigationDrawerDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.icon),
                label: collapsed ? const SizedBox.shrink() : Text(item.label),
                selected: items.indexOf(item) == currentIndex,
                onTap: () => onSelect(items.indexOf(item)),
              ),
            ),
          const Spacer(),
          Material(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: collapsed ? 8 : 12,
              ),
              leading: CircleAvatar(child: Text(_initial(user))),
              title: collapsed
                  ? null
                  : Text(
                      user.fullName.isEmpty ? user.username : user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              subtitle: collapsed
                  ? null
                  : Text(
                      user.email ?? user.role.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              titleAlignment: ListTileTitleAlignment.center,
            ),
          ),
        ],
      ),
    );
  }

  String _initial(AppUser user) {
    final source = user.firstname.isNotEmpty ? user.firstname : user.username;
    return source.isEmpty ? '?' : source.characters.first.toUpperCase();
  }
}

class NavigationDrawerDestination extends StatelessWidget {
  const NavigationDrawerDestination({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Widget icon;
  final Widget selectedIcon;
  final Widget label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        leading: selected ? selectedIcon : icon,
        title: label,
        selected: selected,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: onTap,
      ),
    );
  }
}
