import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SearchBar extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final String searchText;

  const SearchBar({
    super.key,
    required this.onSearch,
    required this.searchText,
  });

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchText);
  }

  @override
  void didUpdateWidget(SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchText != _controller.text) {
      _controller.text = widget.searchText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.searchText.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onSearch('');
        _focusNode.unfocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
          focusNode: _focusNode,
          onKeyEvent: _handleKeyEvent,
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Rechercher par mot clé, description, titre, ...',
              prefixIcon: const Icon(
                Icons.search,
                color: Color(0xFF2C3E50),
              ),
              suffixIcon: widget.searchText.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => widget.onSearch(''),
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
            onChanged: widget.onSearch,
          ),
        ),
      ),
    );
  }
}
