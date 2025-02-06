import 'package:flutter/material.dart';

class SearchBar extends StatelessWidget {
  final ValueChanged<String> onSearch;
  final String searchText;

  const SearchBar({
    super.key,
    required this.onSearch,
    required this.searchText,
  });

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
        child: TextField(
          controller: TextEditingController(text: searchText)
            ..selection = TextSelection.fromPosition(
              TextPosition(offset: searchText.length),
            ),
          decoration: InputDecoration(
            hintText: 'Rechercher par mot clé, description, titre, ...',
            prefixIcon: const Icon(
              Icons.search,
              color: Color(0xFF2C3E50),
            ),
            suffixIcon: searchText.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => onSearch(''),
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
          onChanged: onSearch,
        ),
      ),
    );
  }
}
