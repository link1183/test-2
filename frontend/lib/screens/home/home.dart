import 'package:flutter/material.dart';
import 'package:portail_it/screens/shared/widgets/footer.dart';
import 'package:portail_it/screens/shared/widgets/header.dart';
import 'package:portail_it/screens/home/widgets/main.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Column(
                children: [
                  Header(),
                  SizedBox(height: 16),
                  Main(),
                ],
              ),
              Column(
                children: [
                  SizedBox(height: 16),
                  Footer(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
