import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/services.dart';
import '../../models/user.dart';
import '../../shared/widgets/async_state.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import '../../shared/widgets/search_field.dart';
import '../../shared/widgets/status_badge.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key, required this.authController});
  final AuthController authController;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late Future<List<AppUser>> future = UsersApi(
    widget.authController.apiClient,
  ).all();
  int? deletingUserId;
  int? resettingUserId;
  final searchController = TextEditingController();
  String query = '';
  UserRole? roleFilter;
  List<AppUser>? currentUsers;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppUser>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView(message: 'Loading users');
        }
        if (snapshot.hasError) {
          return ErrorState(
            message: snapshot.error.toString(),
            onRetry: _reload,
          );
        }
        currentUsers ??= (snapshot.data ?? [])
            .where((user) => user.hasProfile)
            .toList();
        final users = currentUsers!.where(_matchesFilters).toList();
        final isAdmin = widget.authController.user?.role != UserRole.worker;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'User management',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                if (isAdmin)
                  FilledButton.icon(
                    onPressed: () => _showUserDialog(),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Create user'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AppSearchField(
              controller: searchController,
              hintText: 'Search users by name, username, email, or role',
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: roleFilter == null,
                  onSelected: (_) => setState(() => roleFilter = null),
                ),
                for (final role in [UserRole.admin, UserRole.worker])
                  ChoiceChip(
                    label: Text(role.label),
                    selected: roleFilter == role,
                    onSelected: (_) => setState(() => roleFilter = role),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (users.isEmpty)
              SizedBox(
                height: 420,
                child: EmptyView(
                  title: query.isEmpty
                      ? 'No users returned'
                      : 'No matching users',
                  subtitle: query.isEmpty
                      ? 'Admins and workers will appear here.'
                      : 'Try another name, username, email, or role.',
                ),
              )
            else
              for (final user in users)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _UserCard(
                    user: user,
                    initials: _initials(user),
                    isAdmin: isAdmin,
                    busy: _userActionBusy,
                    resetting: resettingUserId == user.id,
                    deleting: deletingUserId == user.id,
                    onEdit: () => _showUserDialog(user),
                    onResetPassword: () => _showResetPasswordDialog(user),
                    onDelete: () => _confirmDelete(user),
                  ),
                ),
          ],
        );
      },
    );
  }

  Future<void> _showUserDialog([AppUser? user]) async {
    final formKey = GlobalKey<FormState>();
    final username = TextEditingController(text: user?.username ?? '');
    final firstname = TextEditingController(text: user?.firstname ?? '');
    final lastname = TextEditingController(text: user?.lastname ?? '');
    final email = TextEditingController(text: user?.email ?? '');
    final address = TextEditingController(text: user?.address ?? '');
    final password = TextEditingController();
    var role = user?.role ?? UserRole.worker;
    var enabled = user?.enabled ?? true;
    var showPassword = false;
    String? error;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(user == null ? 'Create user' : 'Edit user'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Form(
                    key: formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: username,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                          ),
                          validator: _required('Username'),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: firstname,
                          decoration: const InputDecoration(
                            labelText: 'First name',
                          ),
                          validator: _required('First name'),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: lastname,
                          decoration: const InputDecoration(
                            labelText: 'Last name',
                          ),
                          validator: _required('Last name'),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: email,
                          decoration: const InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                          validator: _email,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: address,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                          ),
                        ),
                        if (user == null) ...[
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: password,
                            obscureText: !showPassword,
                            decoration:
                                const InputDecoration(
                                  labelText: 'Temporary password',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    tooltip: showPassword
                                        ? 'Hide password'
                                        : 'Show password',
                                    icon: Icon(
                                      showPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                    onPressed: () => setDialogState(
                                      () => showPassword = !showPassword,
                                    ),
                                  ),
                                ),
                            validator: _password,
                          ),
                        ],
                        const SizedBox(height: 10),
                        DropdownButtonFormField<UserRole>(
                          initialValue: role,
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: [UserRole.admin, UserRole.worker]
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item,
                                  child: Text(item.label),
                                ),
                              )
                              .toList(),
                          validator: (value) =>
                              value == null ? 'Select a role.' : null,
                          onChanged: (value) =>
                              setDialogState(() => role = value ?? role),
                        ),
                      ],
                    ),
                  ),
                  if (user == null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'The user will be asked to set a new password the first time they sign in.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  SwitchListTile(
                    value: enabled,
                    onChanged: (value) => setDialogState(() => enabled = value),
                    title: const Text('Active'),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
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
                        try {
                          setDialogState(() {
                            saving = true;
                            error = null;
                          });
                          if (user == null) {
                            await UsersApi(
                              widget.authController.apiClient,
                            ).create({
                              'username': username.text,
                              'firstname': firstname.text,
                              'lastname': lastname.text,
                              'email': email.text,
                              'address': address.text,
                              'role': role.apiName,
                              'temporaryPassword': password.text,
                              'forcePasswordChange': true,
                              'enabled': enabled,
                            });
                          } else {
                            await UsersApi(
                              widget.authController.apiClient,
                            ).update(
                              AppUser(
                                id: user.id,
                                username: username.text,
                                firstname: firstname.text,
                                lastname: lastname.text,
                                email: email.text,
                                address: address.text,
                                enabled: enabled,
                                role: role,
                              ),
                            );
                          }
                          if (context.mounted) Navigator.pop(context);
                          _reload();
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
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showResetPasswordDialog(AppUser user) async {
    final formKey = GlobalKey<FormState>();
    final password = TextEditingController();
    var showPassword = false;
    String? error;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Reset password for ${user.username}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: password,
                  obscureText: !showPassword,
                  decoration:
                      const InputDecoration(
                        labelText: 'Temporary password',
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                      ).copyWith(
                        suffixIcon: IconButton(
                          tooltip: showPassword
                              ? 'Hide password'
                              : 'Show password',
                          icon: Icon(
                            showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setDialogState(
                            () => showPassword = !showPassword,
                          ),
                        ),
                      ),
                  validator: _password,
                ),
                const SizedBox(height: 10),
                Text(
                  'The user will be asked to set a new password the next time they sign in.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
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
                        error = null;
                      });
                      setState(() => resettingUserId = user.id);
                      try {
                        await UsersApi(
                          widget.authController.apiClient,
                        ).resetPassword(
                          id: user.id,
                          temporaryPassword: password.text,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Password reset. The user must choose a new password at next sign-in.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          saving = false;
                          error = e.toString();
                        });
                      } finally {
                        if (mounted) setState(() => resettingUserId = null);
                      }
                    },
              child: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Reset password'),
            ),
          ],
        ),
      ),
    );
    password.dispose();
  }

  Future<void> _confirmDelete(AppUser user) async {
    final confirmed = await showConfirmationDialog(
      context: context,
      title: 'Delete user?',
      message:
          'Delete ${user.username}${user.email == null ? '' : ' (${user.email})'}? This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    setState(() => deletingUserId = user.id);
    try {
      await UsersApi(widget.authController.apiClient).delete(user.id);
      currentUsers = currentUsers?.where((item) => item.id != user.id).toList();
      _reload();
    } finally {
      if (mounted) setState(() => deletingUserId = null);
    }
  }

  void _reload() => setState(() {
    currentUsers = null;
    future = UsersApi(widget.authController.apiClient).all();
  });

  bool get _userActionBusy => deletingUserId != null || resettingUserId != null;

  bool _matchesFilters(AppUser user) {
    if (roleFilter != null && user.role != roleFilter) return false;
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

  String _initials(AppUser user) {
    final source = user.firstname.isNotEmpty ? user.firstname : user.username;
    return source.isEmpty ? '?' : source.characters.first.toUpperCase();
  }

  FormFieldValidator<String> _required(String label) {
    return (value) =>
        value == null || value.trim().isEmpty ? '$label is required.' : null;
  }

  String? _email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Email is required.';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Temporary password is required.';
    }
    if (text.length < 8) {
      return 'Use at least 8 characters.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(text)) {
      return 'Add at least one uppercase letter.';
    }
    if (!RegExp(r'[a-z]').hasMatch(text)) {
      return 'Add at least one lowercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(text)) {
      return 'Add at least one number.';
    }
    return null;
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.initials,
    required this.isAdmin,
    required this.busy,
    required this.resetting,
    required this.deleting,
    required this.onEdit,
    required this.onResetPassword,
    required this.onDelete,
  });

  final AppUser user;
  final String initials;
  final bool isAdmin;
  final bool busy;
  final bool resetting;
  final bool deleting;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final identity = Row(
              children: [
                CircleAvatar(child: Text(initials)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName.isEmpty ? user.username : user.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        user.email ?? user.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user.enabled ? 'Active' : 'Inactive',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                RoleBadge(role: user.role),
                if (isAdmin) ...[
                  IconButton(
                    onPressed: busy ? null : onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    onPressed: busy ? null : onResetPassword,
                    icon: resetting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_reset_outlined),
                    tooltip: 'Reset password',
                  ),
                  IconButton(
                    onPressed: busy ? null : onDelete,
                    icon: deleting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                  ),
                ],
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [identity, const SizedBox(height: 12), actions],
              );
            }
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 12),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: actions,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
