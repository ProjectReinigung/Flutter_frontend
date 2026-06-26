import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/services.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../models/user.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/status_badge.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.authController,
    required this.settingsController,
  });

  final AuthController authController;
  final AppSettingsController settingsController;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool savingProfile = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final user = widget.authController.user!;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        _AccountCard(
          user: user,
          saving: savingProfile,
          error: error,
          onEdit: user.role == UserRole.worker
              ? null
              : () => _showEditDialog(user),
          onLogout: _confirmLogout,
        ),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {widget.settingsController.themeMode},
                    onSelectionChanged: (value) =>
                        widget.settingsController.setThemeMode(value.first),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: widget.settingsController.compactMode,
                  onChanged: widget.settingsController.setCompactMode,
                  title: const Text('Compact mode'),
                  subtitle: const Text('Use tighter spacing where supported.'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Cleaning Manager'),
            subtitle: Text(
              'Flutter multi-platform app for cleaning task operations.',
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Sign out?',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign out',
    );
    if (confirmed) await widget.authController.logout();
  }

  Future<void> _showEditDialog(AppUser user) async {
    final formKey = GlobalKey<FormState>();
    final username = TextEditingController(text: user.username);
    final firstname = TextEditingController(text: user.firstname);
    final lastname = TextEditingController(text: user.lastname);
    final email = TextEditingController(text: user.email ?? '');
    final address = TextEditingController(text: user.address ?? '');
    String? dialogError;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit account'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: username,
                    decoration: const InputDecoration(labelText: 'Username'),
                    validator: _required('Username'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: firstname,
                    decoration: const InputDecoration(labelText: 'First name'),
                    validator: _required('First name'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: lastname,
                    decoration: const InputDecoration(labelText: 'Last name'),
                    validator: _required('Last name'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: _email,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: address,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      dialogError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        saving = true;
                        dialogError = null;
                      });
                      setState(() {
                        savingProfile = true;
                        error = null;
                      });
                      try {
                        await UsersApi(widget.authController.apiClient).update(
                          AppUser(
                            id: user.id,
                            username: username.text.trim(),
                            firstname: firstname.text.trim(),
                            lastname: lastname.text.trim(),
                            email: email.text.trim(),
                            address: address.text.trim(),
                            enabled: user.enabled,
                            role: user.role,
                          ),
                        );
                        await widget.authController.refreshUser();
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        setDialogState(() {
                          saving = false;
                          dialogError = e.toString();
                        });
                      } finally {
                        if (mounted) setState(() => savingProfile = false);
                      }
                    },
              child: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
    username.dispose();
    firstname.dispose();
    lastname.dispose();
    email.dispose();
    address.dispose();
  }

  FormFieldValidator<String> _required(String label) {
    return (value) =>
        value == null || value.trim().isEmpty ? '$label is required.' : null;
  }

  String? _email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'Enter a valid email address.';
    }
    return null;
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.user,
    required this.saving,
    required this.error,
    required this.onEdit,
    required this.onLogout,
  });

  final AppUser user;
  final bool saving;
  final String? error;
  final VoidCallback? onEdit;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final avatarSource = user.firstname.isNotEmpty
        ? user.firstname
        : user.username;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CircleAvatar(
                  child: Text(
                    avatarSource.isEmpty
                        ? '?'
                        : avatarSource.characters.first.toUpperCase(),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 180,
                    maxWidth: 420,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName.isEmpty ? user.username : user.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        user.email ?? user.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                RoleBadge(role: user.role),
              ],
            ),
            const SizedBox(height: 16),
            _ProfileRow(
              icon: Icons.badge_outlined,
              label: 'Username',
              value: user.username,
            ),
            _ProfileRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: user.email ?? 'Not provided',
            ),
            _ProfileRow(
              icon: Icons.home_outlined,
              label: 'Address',
              value: user.address ?? 'Not provided',
            ),
            _ProfileRow(
              icon: Icons.verified_user_outlined,
              label: 'Role',
              value: user.role.label,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onEdit != null)
                  FilledButton.icon(
                    onPressed: saving ? null : onEdit,
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit_outlined),
                    label: Text(saving ? 'Saving' : 'Edit account'),
                  ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                  onPressed: onLogout,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        value.isEmpty ? 'Not provided' : value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
