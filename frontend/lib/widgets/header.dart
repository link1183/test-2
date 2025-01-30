import 'package:flutter/material.dart';
import 'package:test/theme/theme.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.secondary,
      padding: const EdgeInsets.fromLTRB(0, 8, 32, 8),
      child: Row(
        children: [
          Image(
            image: AssetImage('assets/img/bcul_logo_RVB_small.png'),
            width: 115,
            filterQuality: FilterQuality.high,
          ),
          const Text(
            'Portail IT BCUL',
            style: TextStyle(
              color: AppTheme.textLight,
              fontSize: 32,
            ),
          ),
        ],
      ),
    );
  }
}
