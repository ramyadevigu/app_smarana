import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../services/google_auth_service.dart';

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

  Future<void> _signOut() async {
    if (_isBusy) {
      return;
    }
    setState(() => _isBusy = true);
    try {
      await _authService.signOut();
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Google sign-out',
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
                  'Account',
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
                  isBusy: _isBusy,
                  onSignOut: _signOut,
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
  const _SignedInAccountCard({
    required this.user,
    required this.isBusy,
    required this.onSignOut,
  });

  final User user;
  final bool isBusy;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          child: user.photoURL == null
              ? Icon(
                  Icons.person_outline,
                  color: colorScheme.onSecondaryContainer,
                )
              : ClipOval(
                  child: Image.network(
                    user.photoURL!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.person_outline,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
        ),
        title: Text(
          user.displayName?.trim().isNotEmpty == true
              ? user.displayName!
              : 'Google account',
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.email?.isNotEmpty == true) Text(user.email!),
            SelectableText('ID: ${user.uid}', maxLines: 1),
          ],
        ),
        trailing: IconButton(
          tooltip: 'Sign out',
          onPressed: isBusy ? null : onSignOut,
          icon: isBusy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout),
        ),
      ),
    );
  }
}
