import 'package:flutter/material.dart';
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
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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
        child: Column(
          children: [
            const Header(),
            SizedBox(height: 16),
            const Main(),
            SizedBox(height: 16),
            const Footer(),
          ],
        ),
      ),
    );
  }
}
