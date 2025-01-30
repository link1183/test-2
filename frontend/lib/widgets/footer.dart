import 'package:flutter/material.dart';
import 'package:test/theme/theme.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.secondary,
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Image(
            image: AssetImage('assets/img/logoVD-blanc-2014_small.png'),
            width: 40,
            filterQuality: FilterQuality.high,
          ),
          SizedBox(width: 32),
          const Flexible(
            child: Text(
              '© 2025 Bibliothèque Cantonale et Universitaire de Lausanne',
              style: TextStyle(
                color: AppTheme.textLight,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
