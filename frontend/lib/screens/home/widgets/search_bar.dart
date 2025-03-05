import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'highlighted_text.dart';
import 'dart:async';

class SearchBar extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final String searchText;
  final FocusNode focusNode;
  final FocusNode? parentFocusNode;
  final List<String> recentSearches;
  final List<String> availableKeywords;

  const SearchBar(
      {super.key,
      required this.onSearch,
      required this.searchText,
      required this.focusNode,
      this.parentFocusNode,
      this.recentSearches = const <String>[],
      this.availableKeywords = const <String>[]});

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  late TextEditingController _controller;
  List<String> _suggestions = [];
  Map<String, String> _originalCasingSuggestions = {};
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  int _selectedSuggestionIndex = -1;

  Timer? _debounceTimer;
  static const Duration _debounceTime = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchText);
    widget.focusNode.addListener(_onFocusChange);
    _controller.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _controller.removeListener(_onSearchTextChanged);
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchText != _controller.text.trim()) {
      _controller.text = widget.searchText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.searchText.length),
      );
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
      return;
    }

    _updateSuggestions(query);

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
      widget.onSearch(originalQuery);
    });
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                // Add this to clip the list items to the container's border radius
                borderRadius: BorderRadius.circular(8),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    final isRecentSearch =
                        widget.recentSearches.contains(suggestion);
                    final isSelected = index == _selectedSuggestionIndex;

                    // 2. Use a Container with InkWell instead of ListTile for better border control
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          final originalCaseSuggestion =
                              _originalCasingSuggestions[suggestion] ??
                                  suggestion;
                          widget.onSearch(originalCaseSuggestion);
                          _controller.text = originalCaseSuggestion;
                          _controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: originalCaseSuggestion.length),
                          );
                          _removeOverlay();
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
                                isRecentSearch ? Icons.history : Icons.search,
                                color: Colors.grey,
                                size: 18,
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: HighlightedText(
                                  text:
                                      _originalCasingSuggestions[suggestion] ??
                                          suggestion,
                                  highlight: _controller.text.trim(),
                                  style: TextStyle(fontSize: 14),
                                  highlightStyle: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    backgroundColor:
                                        Colors.yellow.withValues(alpha: 0.3),
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

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _removeOverlay();
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
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
                hintText: 'Rechercher par mot clé, description, titre, ...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF2C3E50),
                ),
                suffixIcon: widget.searchText.isNotEmpty
                    ? IconButton(
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
                      )
                    : null,
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
    );
  }
}
