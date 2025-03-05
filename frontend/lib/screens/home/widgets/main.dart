import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:portail_it/middlewares/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'category_section/category_section.dart';
import 'search_bar.dart' as search_bar;
import 'package:portail_it/services/api_client.dart';

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> categories = [];
  List<FilteredCategory> filteredCategories = [];
  Set<String> expandedIds = {};
  String? expandedId;
  String searchText = '';
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _keyboardListenerFocusNode = FocusNode();

  List<String> _recentSearches = [];
  List<String> _allKeywords = [];
  static const String _recentSearchesKey = 'recent_searches';
  static const int _maxRecentSearches = 10;

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _recentSearches = prefs.getStringList(_recentSearchesKey) ?? [];
      });
    } catch (e) {
      print('Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentSearches(String query) async {
    if (query.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      List<String> updatedSearches = [query];

      updatedSearches.addAll(_recentSearches.where((term) => term != query));

      if (updatedSearches.length > _maxRecentSearches) {
        updatedSearches = updatedSearches.sublist(0, _maxRecentSearches);
      }

      setState(() {
        _recentSearches = updatedSearches;
      });

      await prefs.setStringList(_recentSearchesKey, updatedSearches);
    } catch (e) {
      print('Error saving recent search: $e');
    }
  }

  void _extractKeywords() {
    Set<String> keywordSet = {};

    for (var category in categories) {
      final links = category['links'] as List;
      for (var link in links) {
        final titleWords = link['title']
            .toString()
            .split(' ')
            .where((word) => word.length > 3)
            .toList();
        keywordSet.addAll(titleWords);

        final keywords = link['keywords'] as List;
        for (var keywordObj in keywords) {
          keywordSet.add(keywordObj['keyword'].toString());
        }
      }
    }

    setState(() {
      _allKeywords = keywordSet.toList();
    });
  }

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
    final trimmedQuery = query.trim();

    if (trimmedQuery.isNotEmpty && trimmedQuery != searchText) {
      _saveRecentSearches(trimmedQuery);
    }

    setState(() {
      searchText = trimmedQuery;
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

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final isCtrlPressed = HardwareKeyboard.instance.logicalKeysPressed
              .contains(LogicalKeyboardKey.controlLeft) ||
          HardwareKeyboard.instance.logicalKeysPressed
              .contains(LogicalKeyboardKey.controlRight);

      if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyF) {
        event.logicalKey.debugFillProperties(DiagnosticPropertiesBuilder());
        _searchFocusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double maxContainerWidth = 1140;

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadCategories,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return KeyboardListener(
      focusNode: _keyboardListenerFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () {
          if (!_keyboardListenerFocusNode.hasFocus) {
            _keyboardListenerFocusNode.requestFocus();
          }
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: maxContainerWidth),
          margin: const EdgeInsets.symmetric(horizontal: 50),
          child: Column(
            children: [
              search_bar.SearchBar(
                searchText: searchText,
                onSearch: handleSearch,
                focusNode: _searchFocusNode,
                parentFocusNode: _keyboardListenerFocusNode,
                recentSearches: _recentSearches,
                availableKeywords: _allKeywords,
              ),
              if (filteredCategories.isEmpty && searchText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'No results found',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              else
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
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
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _keyboardListenerFocusNode.requestFocus();
    _loadRecentSearches();

    Future.delayed(const Duration(milliseconds: 10), () {
      _loadCategories();
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _keyboardListenerFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.get('/api/categories');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          categories = data['categories'];
          filteredCategories = categories
              .map((category) => FilteredCategory(
                    originalCategory: category,
                    filteredLinks: category['links'],
                  ))
              .toList();
          _isLoading = false;
        });

        _extractKeywords();
      } else if (response.statusCode == 401) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.logout();
        setState(() {
          _error = 'Session expired. Please login again.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load categories: ${response.body}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
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
