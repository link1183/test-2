import 'package:flutter/material.dart';
import 'highlighted_text.dart';

class KeywordsList extends StatelessWidget {
  final List<dynamic> keywords;
  final String searchQuery;

  const KeywordsList({
    super.key,
    required this.keywords,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        spacing: 8,
        alignment: WrapAlignment.center,
        children: keywords
            .map((keyword) => KeywordTag(
                  keyword: keyword['keyword'],
                  searchQuery: searchQuery,
                ))
            .toList(),
      ),
    );
  }
}

class KeywordTag extends StatelessWidget {
  final String keyword;
  final String searchQuery;

  const KeywordTag({
    super.key,
    required this.keyword,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final bool isHighlighted = searchQuery.isNotEmpty &&
        keyword.toLowerCase().contains(searchQuery.toLowerCase());

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: isHighlighted
            ? Colors.yellow.withValues(alpha: 0.3)
            : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: HighlightedText(
        text: keyword,
        query: searchQuery,
        style: TextStyle(
          fontSize: 12,
          color: isHighlighted ? const Color(0xFF2C3E50) : Colors.blue,
        ),
      ),
    );
  }
}
