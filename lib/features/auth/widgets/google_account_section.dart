import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../screens/profile_screen.dart';
import '../services/google_auth_service.dart';
import 'google_profile_avatar.dart';

class GoogleAccountSection extends StatefulWidget {
  const GoogleAccountSection({super.key});

  @override
  State<GoogleAccountSection> createState() => _GoogleAccountSectionState();
}

class _GoogleAccountSectionState extends State<GoogleAccountSection> {
  bool _isBusy = false;

  GoogleAuthService get _authService => GoogleAuthService.instance;

  Future<void> _signIn() async {
    if (_isBusy) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      await _authService.signInWithGoogle();
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Google sign-in',
        ),
      );
      if (mounted) {
        _showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('The account request could not be completed. Try again.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      initialData: _authService.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        return Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'User Profile',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (snapshot.hasError)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.error_outline),
                    title: Text('Account details are unavailable'),
                  ),
                )
              else if (user == null)
                _SignedOutAccountCard(isBusy: _isBusy, onSignIn: _signIn)
              else
                _SignedInAccountCard(
                  user: user,
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => ProfileScreen(user: user),
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Reminders and notes remain stored on this device.',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SignedOutAccountCard extends StatelessWidget {
  const _SignedOutAccountCard({required this.isBusy, required this.onSignIn});

  final bool isBusy;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sign in to keep your Google account connected.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isBusy ? null : onSignIn,
              icon: isBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.account_circle_outlined),
              label: const Text('Continue with Google'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignedInAccountCard extends StatelessWidget {
  const _SignedInAccountCard({required this.user, required this.onTap});

  final User user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 1,
      child: ListTile(
        key: const ValueKey('user-profile-settings-card'),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: GoogleProfileAvatar(user: user, radius: 24),
        title: Text(
          user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : 'Google account',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          user.email?.trim().isNotEmpty == true
              ? user.email!.trim()
              : 'Email unavailable',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
