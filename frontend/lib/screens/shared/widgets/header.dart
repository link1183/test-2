import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test/screens/shared/widgets/user_info.dart';
import 'package:test/theme/theme.dart';
import 'package:test/middlewares/auth_provider.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoggedIn = authProvider.isAuthenticated;
    final displayName = authProvider.displayName;
    final email = authProvider.email;

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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image(
                  image: AssetImage('assets/img/bcul_logo_RVB_small.png'),
                  width: 115,
                  filterQuality: FilterQuality.high,
                ),
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
          if (isLoggedIn && displayName != null && email != null)
            UserInfo(
              displayName: displayName,
              email: email,
              authProvider: authProvider,
            ),
        ],
      ),
    );
  }
}
