import 'package:flutter/material.dart';

class KeywordsList extends StatelessWidget {
  final List<dynamic> keywords;

  const KeywordsList({
    super.key,
    required this.keywords,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        spacing: 8,
        alignment: WrapAlignment.center,
        children: keywords
            .map((keyword) => KeywordTag(keyword: keyword['keyword']))
            .toList(),
      ),
    );
  }
}

class KeywordTag extends StatelessWidget {
  final String keyword;

  const KeywordTag({
    super.key,
    required this.keyword,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        keyword,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.blue,
        ),
      ),
    );
  }
}
