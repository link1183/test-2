import 'package:flutter/material.dart';
import 'package:portail_it/theme/theme.dart';

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
    final maxWidth = 318.0;
    final List<KeywordTag> tags = keywords
        .map((keyword) => KeywordTag(
              keyword: keyword['keyword'],
              searchQuery: searchQuery,
            ))
        .toList();

    return SizedBox(
      height: 24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          double currentWidth = 0;
          int visibleCount = 0;

          for (var tag in tags) {
            final tagWidth = _calculateTagWidth(tag.keyword);
            if (currentWidth + tagWidth > maxWidth) {
              break;
            }
            currentWidth += tagWidth + 8;
            visibleCount++;
          }

          if (visibleCount < tags.length) {
            final visibleTags = tags.take(visibleCount).toList();
            final hiddenKeywords =
                tags.skip(visibleCount).map((tag) => tag.keyword).toList();

            return Wrap(
              spacing: 8,
              runSpacing: 0,
              alignment: WrapAlignment.start,
              children: [
                ...visibleTags,
                Tooltip(
                  message: hiddenKeywords.join(", "),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Wrap(
            spacing: 8,
            runSpacing: 0,
            alignment: WrapAlignment.start,
            children: tags,
          );
        },
      ),
    );
  }

  double _calculateTagWidth(String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 12),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    return textPainter.width + 16;
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
            ? AppTheme.highlightYellow
            : AppTheme.accent.withCustomOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: HighlightedText(
        text: keyword,
        query: searchQuery,
        style: TextStyle(
          fontSize: 12,
          color: isHighlighted ? AppTheme.textPrimary : AppTheme.accent,
        ),
      ),
    );
  }
}
