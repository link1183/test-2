import 'package:flutter/material.dart';
import 'package:portail_it/middlewares/auth_provider.dart';
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
}
