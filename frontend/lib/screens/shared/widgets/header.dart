import 'package:flutter/material.dart';
import 'package:portail_it/middlewares/auth_provider.dart';
import 'package:portail_it/screens/admin/admin_dashboard.dart';
import 'package:portail_it/screens/shared/widgets/user_info.dart';
import 'package:portail_it/theme/theme.dart';
import 'package:provider/provider.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoggedIn = authProvider.isAuthenticated;
    final displayName = authProvider.displayName;
    final email = authProvider.email;
    final isAdmin = _isUserAdmin(authProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.secondary,
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image(
                image: AssetImage('assets/img/bcul_logo_RVB.png'),
                width: 155,
                filterQuality: FilterQuality.high,
                fit: BoxFit.contain,
                isAntiAlias: true,
              ),
              const SizedBox(width: 16),
              Text(
                'Portail IT BCUL',
                style: TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          if (isLoggedIn)
            Row(
              children: [
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AdminDashboard(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Administration'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (displayName != null && email != null)
                  UserInfo(
                    displayName: displayName,
                    email: email,
                    authProvider: authProvider,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  bool _isUserAdmin(AuthProvider authProvider) {
    final userData = authProvider.userData;
    if (userData == null) return false;

    final groups = userData['groups'];
    if (groups == null) return false;

    return (groups as List).contains('admin') || (groups).contains('si-bcu-g');
  }
}

