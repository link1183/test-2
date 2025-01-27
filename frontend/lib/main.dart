import 'package:flutter/material.dart';
import 'package:test/widgets/footer.dart';
import 'package:test/widgets/header.dart';
import 'package:test/widgets/main.dart';
import 'package:http/http.dart' as http;
import 'dart:developer';

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

  Future<void> _getCategories() async {
    try {
      final response = await http.get(Uri.parse('/api/categories'));
      if (response.statusCode == 200) {
        log(response.body);
      }
    } catch (e) {
      log('Error fetching data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Header(),
            const Main(),
            SizedBox(height: 16),
            ElevatedButton.icon(
                onPressed: _getCategories, label: const Text('Get categories')),
            SizedBox(height: 16),
            const Footer(),
          ],
        ),
      ),
    );
  }
}
