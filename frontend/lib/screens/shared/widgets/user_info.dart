import 'package:flutter/material.dart';
import 'package:test/middlewares/auth_provider.dart';
import 'package:test/theme/theme.dart';

class UserInfo extends StatelessWidget {
  final String displayName;
  final String email;
  final AuthProvider authProvider;

  const UserInfo({
    super.key,
    required this.displayName,
    required this.email,
    required this.authProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.secondary.withValues(alpha: 0.8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.textLight.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: Icon(
                Icons.person_outline_rounded,
                color: AppTheme.textLight,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    color: AppTheme.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: authProvider.logout,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textLight,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
