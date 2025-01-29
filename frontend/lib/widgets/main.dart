import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:developer';
import 'dart:convert';
import 'category_section.dart';
import 'search_bar.dart' as search_bar;

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  List<dynamic> categories = [];
  List<FilteredCategory> filteredCategories = [];
  Set<String> expandedIds = {};
  String? expandedId;
  String searchText = '';

  void toggleCategory(String categoryId) {
    setState(() {
      if (searchText.isEmpty) {
        expandedId = expandedId == categoryId ? null : categoryId;
      } else {
        if (expandedIds.contains(categoryId)) {
          expandedIds.remove(categoryId);
        } else {
          expandedIds.add(categoryId);
        }
      }
    });
  }

  void handleSearch(String query) {
    setState(() {
      searchText = query.trim();
      if (searchText.isEmpty) {
        filteredCategories = categories
            .map((category) => FilteredCategory(
                  originalCategory: category,
                  filteredLinks: category['links'],
                ))
            .toList();
        expandedIds.clear();
        expandedId = null;
        return;
      }

      filteredCategories = [];
      final searchLower = searchText.toLowerCase();

      for (var category in categories) {
        final links = (category['links'] as List).where((link) {
          final title = link['title'].toString().toLowerCase();
          final description = link['description'].toString().toLowerCase();

          if (title.contains(searchLower) ||
              description.contains(searchLower)) {
            return true;
          }

          final keywords = link['keywords'] as List;
          return keywords.any((keyword) => keyword['keyword']
              .toString()
              .toLowerCase()
              .contains(searchLower));
        }).toList();

        if (links.isNotEmpty) {
          filteredCategories.add(FilteredCategory(
            originalCategory: category,
            filteredLinks: links,
          ));
          expandedIds.add(category['category_id'].toString());
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const double maxContainerWidth = 1140;

    return Container(
      constraints: const BoxConstraints(maxWidth: maxContainerWidth),
      margin: const EdgeInsets.symmetric(horizontal: 50),
      child: Column(
        children: [
          search_bar.SearchBar(
            searchText: searchText,
            onSearch: handleSearch,
          ),
          if (filteredCategories.isEmpty && searchText.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'No results found',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2C3E50),
                ),
              ),
            )
          else
            SingleChildScrollView(
              child: Column(
                children: filteredCategories.map((filteredCategory) {
                  final category = {
                    ...filteredCategory.originalCategory,
                    'links': filteredCategory.filteredLinks,
                  };
                  final categoryId = category['category_id'].toString();

                  return CategorySection(
                    key: ValueKey(categoryId),
                    category: category,
                    isExpanded: searchText.isEmpty
                        ? expandedId == categoryId
                        : expandedIds.contains(categoryId),
                    onToggle: () => toggleCategory(categoryId),
                    searchQuery: searchText,
                  );
                }).toList(),
              ),
            ),
        ],
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
          filteredCategories = categories
              .map((category) => FilteredCategory(
                    originalCategory: category,
                    filteredLinks: category['links'],
                  ))
              .toList();
        });
      }
    } catch (e) {
      log('Error fetching data: $e');
    }
  }
}

class FilteredCategory {
  final Map<String, dynamic> originalCategory;
  final List<dynamic> filteredLinks;

  FilteredCategory({
    required this.originalCategory,
    required this.filteredLinks,
  });
}
