import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/config/app_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.authController});
  final AuthController authController;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final backend = TextEditingController(text: AppConfig.defaultBackendUrl);
  final keycloak = TextEditingController(text: AppConfig.defaultKeycloakUrl);
  final username = TextEditingController();
  final password = TextEditingController();
  bool showPassword = false;
  String? error;

  @override
  void dispose() {
    backend.dispose();
    keycloak.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.authController;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AutofillGroup(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.cleaning_services,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Sign in',
                          style: Theme.of(context).textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use your company account to open Cleaning Manager.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: username,
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Username or email',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Enter your username or email.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: password,
                          obscureText: !showPassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) {
                            if (!auth.loading) _login();
                          },
                          decoration:
                              const InputDecoration(
                                labelText: 'Password',
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
                                  onPressed: () => setState(
                                    () => showPassword = !showPassword,
                                  ),
                                ),
                              ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter your password.'
                              : null,
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: auth.loading ? null : _login,
                          icon: auth.loading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: Text(auth.loading ? 'Signing in' : 'Sign in'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    setState(() => error = null);
    if (!formKey.currentState!.validate()) return;
    try {
      await widget.authController.login(
        backend: backend.text,
        keycloakBase: keycloak.text.replaceAll(RegExp(r'/$'), ''),
        username: username.text.trim(),
        password: password.text,
      );
    } catch (e) {
      if (_isTemporaryPasswordError(e)) {
        await _showCompletePasswordDialog();
        return;
      }
      setState(() => error = _friendlyError(e));
    }
  }

  Future<void> _showCompletePasswordDialog() async {
    final formKey = GlobalKey<FormState>();
    final newPassword = TextEditingController();
    final confirmPassword = TextEditingController();
    var showNewPassword = false;
    var showConfirmPassword = false;
    String? dialogError;
    bool saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set a new password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'If this is a temporary password, choose a new password to finish signing in.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPassword,
                  obscureText: !showNewPassword,
                  decoration:
                      const InputDecoration(
                        labelText: 'New password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ).copyWith(
                        suffixIcon: IconButton(
                          tooltip: showNewPassword
                              ? 'Hide password'
                              : 'Show password',
                          icon: Icon(
                            showNewPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setDialogState(
                            () => showNewPassword = !showNewPassword,
                          ),
                        ),
                      ),
                  validator: _passwordRule,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPassword,
                  obscureText: !showConfirmPassword,
                  decoration:
                      const InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: Icon(Icons.lock_reset_outlined),
                      ).copyWith(
                        suffixIcon: IconButton(
                          tooltip: showConfirmPassword
                              ? 'Hide password'
                              : 'Show password',
                          icon: Icon(
                            showConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setDialogState(
                            () => showConfirmPassword = !showConfirmPassword,
                          ),
                        ),
                      ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirm the new password.';
                    }
                    if (value != newPassword.text) {
                      return 'Passwords do not match.';
                    }
                    return null;
                  },
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 12),
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
                      try {
                        await widget.authController.completePasswordChange(
                          backend: backend.text,
                          username: username.text.trim(),
                          currentPassword: password.text,
                          newPassword: newPassword.text,
                        );
                        await widget.authController.login(
                          backend: backend.text,
                          keycloakBase: keycloak.text.replaceAll(
                            RegExp(r'/$'),
                            '',
                          ),
                          username: username.text.trim(),
                          password: newPassword.text,
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        setDialogState(() {
                          saving = false;
                          dialogError = _friendlyError(e);
                        });
                      }
                    },
              child: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save and sign in'),
            ),
          ],
        ),
      ),
    );
    newPassword.dispose();
    confirmPassword.dispose();
  }

  String _friendlyError(Object error) {
    final message = _errorText(error);
    final lower = message.toLowerCase();
    if (lower.contains('invalid user credentials') ||
        lower.contains('invalid username or password') ||
        lower.contains('bad credentials')) {
      return 'Username or password is incorrect.';
    }
    if (lower.contains('account is not fully set up') ||
        lower.contains('account setup') ||
        lower.contains('required action') ||
        lower.contains('temporary')) {
      return 'This password was not accepted. If it is a temporary password, set a new password to continue.';
    }
    if (message.contains('XMLHttpRequest') ||
        message.contains('Failed host lookup')) {
      return 'Sign-in service is unavailable. Try again later or contact your admin.';
    }
    return message;
  }

  bool _isTemporaryPasswordError(Object error) {
    final lower = _errorText(error).toLowerCase();
    return lower.contains('account is not fully set up') ||
        lower.contains('account setup') ||
        lower.contains('required action') ||
        lower.contains('temporary');
  }

  String _errorText(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    try {
      final data = jsonDecode(message);
      if (data is Map<String, dynamic>) {
        for (final value in [
          data['error_description'],
          data['message'],
          data['error'],
        ].whereType<String>()) {
          return value;
        }
      }
    } on FormatException {
      return message;
    }
    return message;
  }

  String? _passwordRule(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Enter a new password.';
    if (text.length < 8) return 'Use at least 8 characters.';
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
