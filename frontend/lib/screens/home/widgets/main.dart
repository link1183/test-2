import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:portail_it/middlewares/auth_provider.dart';
import 'package:portail_it/services/api_client.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'category_section/category_section.dart';
import 'search_bar.dart' as search_bar;
import 'search_filter.dart';

class FilteredCategory {
  final Map<String, dynamic> originalCategory;
  final List<dynamic> filteredLinks;

  FilteredCategory({
    required this.originalCategory,
    required this.filteredLinks,
  });
}

class Main extends StatefulWidget {
  const Main({super.key});

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  static const String _recentSearchesKey = 'recent_searches';
  static const int _maxRecentSearches = 10;
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
  String? _selectedSearchScope;

  final Map<String, List<String>> _availableFilters = {
    'category': [],
    'type': [
      'document',
      'tool',
      'video',
      'tutorial',
      'reference',
      'application',
      'library'
    ],
    'status': ['active', 'archived', 'draft'],
  };

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
                availableFilters: _availableFilters,
                onSearchScopeChanged: _handleSearchScopeChanged,
                selectedScope: _selectedSearchScope,
              ),
              if (filteredCategories.isEmpty &&
                  (searchText.isNotEmpty || _selectedSearchScope != null))
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
                        isExpanded:
                            searchText.isEmpty && _selectedSearchScope == null
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
  void dispose() {
    _searchFocusNode.dispose();
    _keyboardListenerFocusNode.dispose();
    super.dispose();
  }

  void handleSearch(String query) {
    final trimmedQuery = query.trim();

    if (trimmedQuery.isNotEmpty && trimmedQuery != searchText) {
      _saveRecentSearches(trimmedQuery);
    }

    setState(() {
      searchText = trimmedQuery;
      _filterCategories();
    });
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

  void _extractKeywords() {
    Set<String> keywordSet = {};
    Set<String> categorySet = {};

    for (var category in categories) {
      if (category['category_name'] != null) {
        categorySet.add(category['category_name'].toString());
      }
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
      _availableFilters['category'] = categorySet.toList();
    });
  }

  void _filterCategories() {
    if (searchText.isEmpty && _selectedSearchScope == null) {
      // No search query and no scope filter - show all categories
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

    final parsedQuery = SearchParser.parseQuery(searchText);
    final plainText = parsedQuery['text'] as String;
    final filters = parsedQuery['filters'] as List<SearchFilter>;

    filteredCategories = [];
    final searchLower = plainText.toLowerCase();

    for (var category in categories) {
      bool categoryMatches = true;

      // Check if this category matches the selected scope
      if (_selectedSearchScope != null) {
        final categoryName = category['category_name']?.toString() ?? '';
        if (categoryName != _selectedSearchScope) {
          categoryMatches = false;
        }
      }

      // Check if this category matches any category filters
      for (final filter in filters) {
        if (filter.type.toLowerCase() == 'category') {
          final categoryName =
              category['category_name']?.toString().toLowerCase() ?? '';
          if (!categoryName.contains(filter.value.toLowerCase())) {
            categoryMatches = false;
            break;
          }
        }
      }

      if (!categoryMatches) {
        continue;
      }

      final links = (category['links'] as List).where((link) {
        // Check if the link matches all other filters
        for (final filter in filters) {
          if (filter.type.toLowerCase() == 'category') {
            continue;
          } else if (filter.type.toLowerCase() == 'type') {
            final typeValue = link['type']?.toString().toLowerCase() ?? '';
            if (!typeValue.contains(filter.value.toLowerCase())) {
              return false;
            }
          } else if (filter.type.toLowerCase() == 'status') {
            final statusValue = link['status']?.toString().toLowerCase() ?? '';
            if (!statusValue.contains(filter.value.toLowerCase())) {
              return false;
            }
          }
        }

        // If there's no search text, include all links that passed the filters
        if (searchLower.isEmpty) {
          return true;
        }

        // Search in title and description
        final title = link['title'].toString().toLowerCase();
        final description = link['description'].toString().toLowerCase();

        if (title.contains(searchLower) || description.contains(searchLower)) {
          return true;
        }

        // Search in keywords
        final keywords = link['keywords'] as List;
        return keywords.any((keyword) =>
            keyword['keyword'].toString().toLowerCase().contains(searchLower));
      }).toList();

      if (links.isNotEmpty) {
        filteredCategories.add(FilteredCategory(
          originalCategory: category,
          filteredLinks: links,
        ));
        expandedIds.add(category['category_id'].toString());
      }
    }
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

  void _handleSearchScopeChanged(String? newScope) {
    setState(() {
      _selectedSearchScope = newScope;
      _filterCategories();
    });
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
}
