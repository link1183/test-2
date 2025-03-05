import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:portail_it/screens/home/widgets/filter_tag_chip.dart';
import 'package:portail_it/screens/home/widgets/search_filter.dart';
import 'package:portail_it/theme/theme.dart';

import 'highlighted_text.dart';

class SearchBar extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final String searchText;
  final FocusNode focusNode;
  final FocusNode? parentFocusNode;
  final List<String> recentSearches;
  final List<String> availableKeywords;
  final Map<String, List<String>>? availableFilters;
  final ValueChanged<String?>? onSearchScopeChanged;
  final String? selectedScope;

  const SearchBar({
    super.key,
    required this.onSearch,
    required this.searchText,
    required this.focusNode,
    this.parentFocusNode,
    this.recentSearches = const <String>[],
    this.availableKeywords = const <String>[],
    this.availableFilters,
    this.onSearchScopeChanged,
    this.selectedScope,
  });

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  static const Duration _debounceTime = Duration(milliseconds: 300);
  late TextEditingController _controller;
  List<String> _suggestions = [];
  Map<String, String> _originalCasingSuggestions = {};
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  int _selectedSuggestionIndex = -1;
  bool _isHistoryMenuOpen = false;
  final LayerLink _historyLayerLink = LayerLink();

  OverlayEntry? _historyOverlayEntry;
  Timer? _debounceTimer;

  String _plainSearchText = '';
  List<SearchFilter> _activeFilters = [];
  bool _showFilterSuggestions = false;
  String? _currentFilterType;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Search Scope Selector
                if (widget.availableFilters?['category'] != null)
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.searchFieldBackground,
                      borderRadius: BorderRadius.circular(12.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8.0,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    margin: const EdgeInsets.only(right: 8.0),
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: widget.selectedScope,
                        icon: const Icon(Icons.arrow_drop_down,
                            color: Color(0xFF2C3E50)),
                        borderRadius: BorderRadius.circular(8.0),
                        hint: Text('Toutes les catégories',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            )),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Toutes les catégories'),
                          ),
                          ...widget.availableFilters!['category']!.map(
                            (category) => DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            ),
                          ),
                        ],
                        onChanged: widget.onSearchScopeChanged,
                      ),
                    ),
                  ),
                // Search Bar
                Expanded(
                  child: CompositedTransformTarget(
                    link: _historyLayerLink,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.searchFieldBackground,
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8.0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: _handleKeyEvent,
                        child: TextField(
                          controller: _controller,
                          focusNode: widget.focusNode,
                          decoration: InputDecoration(
                            hintText:
                                'Rechercher par mot clé, description, titre, ...',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Color(0xFF2C3E50),
                            ),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // History button
                                IconButton(
                                  icon: Icon(
                                    Icons.history,
                                    color: _isHistoryMenuOpen
                                        ? Theme.of(context).primaryColor
                                        : const Color(0xFF2C3E50),
                                  ),
                                  onPressed: widget.recentSearches.isNotEmpty
                                      ? _toggleHistoryMenu
                                      : null,
                                  tooltip: 'Recent Searches',
                                ),
                                // Clear button
                                if (widget.searchText.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _controller.text = '';
                                      _debounceTimer?.cancel();
                                      widget.onSearch('');
                                      _removeOverlay();
                                      if (widget.parentFocusNode != null) {
                                        widget.parentFocusNode!.requestFocus();
                                      }
                                    },
                                    color: const Color(0xFF2C3E50),
                                  ),
                              ],
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 14.0,
                            ),
                          ),
                          style: Theme.of(context).textTheme.bodyLarge,
                          onChanged: (_) {
                            // Don't call widget.onSearch - it will be called after debounce
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_activeFilters.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _activeFilters.map((filter) {
                    return FilterTagChip(
                      filter: filter,
                      onRemove: () {
                        _removeFilter(filter);
                      },
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchText != _controller.text.trim()) {
      _controller.text = widget.searchText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.searchText.length),
      );
      _parseInitialSearchText();
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onSearchTextChanged);
    _controller.dispose();
    _debounceTimer?.cancel();
    _removeHistoryOverlay();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchText);
    widget.focusNode.addListener(_onFocusChange);
    _controller.addListener(_onSearchTextChanged);

    _parseInitialSearchText();
  }

  void _applyFilterSuggestion(String suggestion) {
    if (_currentFilterType == null) return;

    final currentText = _controller.text;
    final filterTypeIndex = currentText.lastIndexOf('${_currentFilterType!}:');

    if (filterTypeIndex >= 0) {
      final beforeFilter = currentText.substring(0, filterTypeIndex);
      final afterFilter = _getTextAfterFilter(currentText, filterTypeIndex);

      final completeFilter = '${_currentFilterType!}:$suggestion';
      final newText = beforeFilter + completeFilter + afterFilter;

      _controller.text = newText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: (beforeFilter + completeFilter).length),
      );

      _showFilterSuggestions = false;
      _currentFilterType = null;

      _debounceTimer?.cancel();
      widget.onSearch(newText);
      _removeOverlay();
    }
  }

  void _detectFilterTyping(String query) {
    final filterTypeRegex = RegExp(r'(\w+):$');
    final match = filterTypeRegex.firstMatch(query);

    if (match != null) {
      final filterType = match.group(1)!.toLowerCase();
      if (widget.availableFilters?.containsKey(filterType) ?? false) {
        _showFilterSuggestions = true;
        _currentFilterType = filterType;
        return;
      }
    }

    final filterValueRegex = RegExp(r'(\w+):(\w*)$');
    final valueMatch = filterValueRegex.firstMatch(query);

    if (valueMatch != null) {
      final filterType = valueMatch.group(1)!.toLowerCase();
      if (widget.availableFilters?.containsKey(filterType) ?? false) {
        _showFilterSuggestions = true;
        _currentFilterType = filterType;
        return;
      }
    }

    _showFilterSuggestions = false;
    _currentFilterType = null;
  }

  String _getTextAfterFilter(String text, int filterStartIndex) {
    final match =
        RegExp(r'\w+:\w*').firstMatch(text.substring(filterStartIndex));
    if (match != null) {
      final endIndex = filterStartIndex + match.end;
      if (endIndex < text.length) {
        return text.substring(endIndex);
      }
    }
    return '';
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _removeOverlay();
        _removeHistoryOverlay();
        widget.onSearch('');
        widget.focusNode.unfocus();

        if (widget.parentFocusNode != null) {
          widget.parentFocusNode!.requestFocus();
        }
      } else if (_overlayEntry != null) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          setState(() {
            if (_selectedSuggestionIndex < 0) {
              _selectedSuggestionIndex = 0;
            } else {
              _selectedSuggestionIndex =
                  (_selectedSuggestionIndex + 1) % _suggestions.length;
            }
          });
          _overlayEntry!.markNeedsBuild();
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          setState(() {
            if (_selectedSuggestionIndex < 0) {
              _selectedSuggestionIndex = _suggestions.length - 1;
            } else {
              _selectedSuggestionIndex = _selectedSuggestionIndex <= 0
                  ? _suggestions.length - 1
                  : _selectedSuggestionIndex - 1;
            }
          });
          _overlayEntry!.markNeedsBuild();
        } else if (event.logicalKey == LogicalKeyboardKey.enter &&
            _selectedSuggestionIndex >= 0 &&
            _selectedSuggestionIndex < _suggestions.length) {
          final suggestion = _suggestions[_selectedSuggestionIndex];

          if (_showFilterSuggestions && _currentFilterType != null) {
            // Apply filter suggestion
            final originalCaseSuggestion =
                _originalCasingSuggestions[suggestion] ?? suggestion;
            _applyFilterSuggestion(originalCaseSuggestion);
          } else {
            // Apply regular suggestion
            final originalCaseSuggestion =
                _originalCasingSuggestions[suggestion] ?? suggestion;
            widget.onSearch(originalCaseSuggestion);
            _controller.text = originalCaseSuggestion;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: originalCaseSuggestion.length),
            );
            _removeOverlay();
          }
        }
      }
    }
  }

  void _onFocusChange() {
    if (!widget.focusNode.hasFocus) {
      _removeOverlay();
      if (widget.parentFocusNode != null) {
        widget.parentFocusNode!.requestFocus();
      }
    } else if (widget.focusNode.hasFocus && _controller.text.isNotEmpty) {
      _showOverlay();
    }
  }

  void _onSearchTextChanged() {
    final originalQuery = _controller.text.trim();
    final query = _controller.text.trim().toLowerCase();

    if (originalQuery.isEmpty) {
      _removeOverlay();
      _plainSearchText = '';
      _activeFilters = [];
      return;
    }

    _detectFilterTyping(originalQuery);

    if (_showFilterSuggestions && _currentFilterType != null) {
      _updateFilterSuggestions(query);
    } else {
      _updateSuggestions(query);
    }

    if (_suggestions.isNotEmpty && widget.focusNode.hasFocus) {
      if (_overlayEntry == null) {
        _showOverlay();
      } else {
        _overlayEntry!.markNeedsBuild();
      }
    } else {
      _removeOverlay();
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceTime, () {
      final parsed = SearchParser.parseQuery(originalQuery);
      _plainSearchText = parsed['text'] as String;
      _activeFilters = parsed['filters'] as List<SearchFilter>;

      widget.onSearch(originalQuery);
    });
  }

  void _parseInitialSearchText() {
    if (widget.searchText.isNotEmpty) {
      final parsed = SearchParser.parseQuery(widget.searchText);
      _plainSearchText = parsed['text'] as String;
      _activeFilters = parsed['filters'] as List<SearchFilter>;
    }
  }

  void _removeFilter(SearchFilter filter) {
    setState(() {
      _activeFilters.remove(filter);

      final newQuery =
          SearchParser.buildQuery(_plainSearchText, _activeFilters);
      _controller.text = newQuery;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: newQuery.length),
      );

      widget.onSearch(newQuery);
    });
  }

  void _removeHistoryOverlay() {
    if (_historyOverlayEntry != null) {
      _historyOverlayEntry!.remove();
      _historyOverlayEntry = null;
    }
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  void _showHistoryOverlay() {
    if (_historyOverlayEntry != null || widget.recentSearches.isEmpty) return;

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _historyOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _historyLayerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: 250,
              ),
              decoration: BoxDecoration(
                color: AppTheme.searchFieldBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'Recent Searches',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    if (widget.recentSearches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No recent searches',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: widget.recentSearches.length,
                          itemBuilder: (context, index) {
                            final search = widget.recentSearches[index];
                            return InkWell(
                              onTap: () {
                                widget.onSearch(search);
                                _controller.text = search;
                                _controller.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(offset: search.length),
                                );
                                _removeHistoryOverlay();
                                setState(() {
                                  _isHistoryMenuOpen = false;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 12.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.history,
                                      size: 18,
                                      color: Colors.grey.shade600,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        search,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_historyOverlayEntry!);
  }

  void _showOverlay() {
    if (_overlayEntry != null || _suggestions.isEmpty) return;

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: 200,
              ),
              decoration: BoxDecoration(
                color: AppTheme.searchFieldBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    final isRecentSearch = !_showFilterSuggestions &&
                        widget.recentSearches
                            .map((e) => e.toLowerCase())
                            .contains(suggestion);
                    final isSelected = index == _selectedSuggestionIndex;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (_showFilterSuggestions &&
                              _currentFilterType != null) {
                            // Apply filter suggestion
                            final originalCaseSuggestion =
                                _originalCasingSuggestions[suggestion] ??
                                    suggestion;
                            _applyFilterSuggestion(originalCaseSuggestion);
                          } else {
                            // Apply regular suggestion
                            final originalCaseSuggestion =
                                _originalCasingSuggestions[suggestion] ??
                                    suggestion;
                            widget.onSearch(originalCaseSuggestion);
                            _controller.text = originalCaseSuggestion;
                            _controller.selection = TextSelection.fromPosition(
                              TextPosition(
                                  offset: originalCaseSuggestion.length),
                            );
                            _removeOverlay();
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF5F5F5) : null,
                            border: isSelected
                                ? Border(
                                    left: BorderSide(
                                      color: const Color(0xFF2C3E50),
                                      width: 3.0,
                                    ),
                                  )
                                : null,
                          ),
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                _showFilterSuggestions
                                    ? Icons.label_outline
                                    : (isRecentSearch
                                        ? Icons.history
                                        : Icons.search),
                                color: Colors.grey,
                                size: 18,
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: _showFilterSuggestions
                                    ? RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.black,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: '${_currentFilterType!}:',
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            TextSpan(
                                              text: _originalCasingSuggestions[
                                                      suggestion] ??
                                                  suggestion,
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : HighlightedText(
                                        text: _originalCasingSuggestions[
                                                suggestion] ??
                                            suggestion,
                                        highlight: _controller.text.trim(),
                                        style: TextStyle(fontSize: 14),
                                        highlightStyle: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          backgroundColor: Colors.yellow
                                              .withValues(alpha: 0.3),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  // History dropdown methods
  void _toggleHistoryMenu() {
    if (_historyOverlayEntry != null) {
      _removeHistoryOverlay();
    } else {
      _showHistoryOverlay();
    }

    setState(() {
      _isHistoryMenuOpen = !_isHistoryMenuOpen;
    });
  }

  void _updateFilterSuggestions(String query) {
    if (_currentFilterType == null ||
        !(widget.availableFilters?.containsKey(_currentFilterType!) ?? false)) {
      _suggestions = [];
      return;
    }

    final filterValueRegex = RegExp('${_currentFilterType!}:(\\w*)');
    final match = filterValueRegex.firstMatch(query);
    final partialValue = match?.group(1) ?? '';

    final availableValues = widget.availableFilters![_currentFilterType!] ?? [];

    _suggestions = availableValues
        .where(
            (value) => value.toLowerCase().contains(partialValue.toLowerCase()))
        .take(5)
        .toList();

    _originalCasingSuggestions = {};
    for (final suggestion in _suggestions) {
      _originalCasingSuggestions[suggestion.toLowerCase()] = suggestion;
    }
  }

  void _updateSuggestions(String query) {
    if (query.isEmpty) {
      _suggestions = [];
      _originalCasingSuggestions = {};
      return;
    }

    final recentMatches = widget.recentSearches
        .where((term) => term.toLowerCase().contains(query))
        .toList();

    final keywordMatches = widget.availableKeywords
        .where((keyword) => keyword.toLowerCase().contains(query))
        .where((keyword) => !recentMatches.contains(keyword))
        .toList();

    final combinedSuggestions =
        [...recentMatches, ...keywordMatches].take(5).toList();

    _originalCasingSuggestions = {};
    for (final suggestion in combinedSuggestions) {
      _originalCasingSuggestions[suggestion.toLowerCase()] = suggestion;
    }

    _suggestions = combinedSuggestions.map((s) => s.toLowerCase()).toList();
  }
}
