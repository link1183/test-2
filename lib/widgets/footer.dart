import 'package:flutter/material.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF212529),
      padding: const EdgeInsets.all(32.0),
      child: Row(
        children: [
          Image(
            image: AssetImage('assets/img/logoVD-blanc-2014_small.png'),
            height: 115,
            filterQuality: FilterQuality.none,
          ),
          SizedBox(width: 32),
          const Flexible(
            child: Text(
              '© 2025 Bibliothèque Cantonale et Universitaire de Lausanne',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
