import 'package:flutter/material.dart';
import 'package:portail_it/screens/shared/widgets/footer.dart';
import 'package:portail_it/screens/shared/widgets/header.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
        child: Column(
      children: [
        Header(),
        CircularProgressIndicator(),
        Footer(),
      ],
    ));
  }
}
