import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:developer';
import 'dart:convert';
import 'category_section.dart';

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  List<dynamic> categories = [];
  int? expandedIndex;

  void toggleCategory(int index) {
    setState(() {
      expandedIndex = expandedIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    const double maxContainerWidth = 1000;

    return Container(
      constraints: const BoxConstraints(maxWidth: maxContainerWidth),
      margin: const EdgeInsets.symmetric(horizontal: 64),
      child: SingleChildScrollView(
        child: Column(
          children: categories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            return CategorySection(
              category: category,
              isExpanded: index == expandedIndex,
              onToggle: () => toggleCategory(index),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await http.get(Uri.parse('/api/categories'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          categories = data['categories'];
        });
      }
    } catch (e) {
      log('Error fetching data: $e');
    }
  }
}
