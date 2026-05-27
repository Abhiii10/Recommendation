import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_api_service.dart';
import '../services/auth_session_service.dart';
import '../services/interaction_sync_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final AuthSessionService _auth = AuthSessionService.instance;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _registerMode = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_registerMode && username.length < 2) {
      setState(() => _error = 'Enter your name.');
      return;
    }

    if (!email.contains('@') || password.length < 8) {
      setState(() => _error = 'Enter a valid email and 8+ character password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_registerMode) {
        await _auth.register(
          username: username,
          email: email,
          password: password,
        );
      } else {
        await _auth.login(email: email, password: password);
      }

      unawaited(InteractionSyncService.instance.syncPending());
      _passwordController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signed in as ${_auth.displayName}')),
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error, stackTrace) {
      debugPrint('Account auth submit failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _error = 'Sign-in could not finish on this device. ${error.toString()}';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _loading = true);
    await _auth.logout();
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signed out. Guest mode is active.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        actions: [
          if (_auth.isAuthenticated)
            IconButton(
              tooltip: 'Refresh account',
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      try {
                        await _auth.refreshCurrentUser();
                      } catch (_) {
                        if (mounted) {
                          setState(() {
                            _error = 'Could not refresh account right now.';
                          });
                        }
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
              icon: const Icon(Icons.sync_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      _auth.isAuthenticated
                          ? Icons.verified_user_rounded
                          : Icons.person_outline_rounded,
                      size: 54,
                      color: cs.primary,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _auth.isAuthenticated
                          ? 'Signed in'
                          : 'Use an account or continue as guest',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _auth.isAuthenticated
                          ? 'Recommendations and synced interactions use your account ID.'
                          : 'Guest mode keeps working offline with a local ID.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 24),
                    if (_auth.isAuthenticated)
                      _SignedInPanel(
                        user: _auth.user!,
                        loading: _loading,
                        onLogout: _logout,
                      )
                    else
                      _AuthForm(
                        registerMode: _registerMode,
                        loading: _loading,
                        error: _error,
                        usernameController: _usernameController,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        obscurePassword: _obscurePassword,
                        onModeChanged: (value) {
                          setState(() {
                            _registerMode = value;
                            _error = null;
                          });
                        },
                        onTogglePassword: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        onSubmit: _submit,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInPanel extends StatelessWidget {
  final AuthUserAccount user;
  final bool loading;
  final VoidCallback onLogout;

  const _SignedInPanel({
    required this.user,
    required this.loading,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
            child: Text(
              user.username.isEmpty ? 'U' : user.username[0].toUpperCase(),
            ),
          ),
          title: Text(user.username),
          subtitle: Text(user.email),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outlineVariant),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: loading ? null : onLogout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}

class _AuthForm extends StatelessWidget {
  final bool registerMode;
  final bool loading;
  final String? error;
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  const _AuthForm({
    required this.registerMode,
    required this.loading,
    required this.error,
    required this.usernameController,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onModeChanged,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.login_rounded),
                label: Text('Login'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.person_add_alt_rounded),
                label: Text('Register'),
              ),
            ],
            selected: {registerMode},
            onSelectionChanged:
                loading ? null : (values) => onModeChanged(values.first),
          ),
        ),
        const SizedBox(height: 20),
        if (registerMode) ...[
          TextField(
            controller: usernameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => loading ? null : onSubmit(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              tooltip: obscurePassword ? 'Show password' : 'Hide password',
              onPressed: onTogglePassword,
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            style: TextStyle(color: cs.error, fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: loading ? null : onSubmit,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  registerMode
                      ? Icons.person_add_alt_rounded
                      : Icons.login_rounded,
                ),
          label: Text(registerMode ? 'Create account' : 'Login'),
        ),
      ],
    );
  }
}
