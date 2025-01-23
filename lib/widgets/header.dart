import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF212529),
      padding: const EdgeInsets.fromLTRB(0, 16, 32, 16),
      child: Row(
        children: [
          Image(
            image: AssetImage('assets/img/bcul_logo_RVB_small.png'),
            height: 115,
          ),
          const Text(
            'Portail IT BCUL',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
            ),
          ),
        ],
      ),
    );
  }
}
