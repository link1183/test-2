import 'package:flutter/material.dart';
import 'package:test/theme/theme.dart';
import 'package:test/widgets/footer.dart';
import 'package:test/widgets/header.dart';
import 'package:test/widgets/main.dart';

void main() async {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Portail IT BCUL',
      theme: AppTheme.theme,
      home: const Home(),
    );
  }
}

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
