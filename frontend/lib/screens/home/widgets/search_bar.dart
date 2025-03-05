import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SearchBar extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final String searchText;
  final FocusNode focusNode;
  final FocusNode? parentFocusNode;

  const SearchBar({
    super.key,
    required this.onSearch,
    required this.searchText,
    required this.focusNode,
    this.parentFocusNode,
  });

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.searchText);

    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    widget.focusNode.removeListener(_onFocusChange);
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
      if (widget.parentFocusNode != null) {
        widget.parentFocusNode!.requestFocus();
      }
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.onSearch('');
        widget.focusNode.unfocus();

        if (widget.parentFocusNode != null) {
          widget.parentFocusNode!.requestFocus();
        }
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
                        widget.onSearch('');
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
            onChanged: widget.onSearch,
          ),
        ),
      ),
    );
  }
}
