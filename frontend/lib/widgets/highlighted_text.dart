import 'package:flutter/material.dart';

class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;

  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    required this.style,
    this.textAlign,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    if (query.trim().isEmpty) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
      );
    }

    final matchExists = text.toLowerCase().contains(query.toLowerCase());
    if (!matchExists) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
      );
    }

    final spans = <TextSpan>[];
    final textLower = text.toLowerCase();
    final queryLower = query.toLowerCase();
    int currentIndex = 0;

    while (true) {
      final matchIndex = textLower.indexOf(queryLower, currentIndex);
      if (matchIndex == -1) {
        // Add remaining text
        spans.add(TextSpan(
          text: text.substring(currentIndex),
          style: style,
        ));
        break;
      }

      // Add text before match
      if (matchIndex > currentIndex) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, matchIndex),
          style: style,
        ));
      }

      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(matchIndex, matchIndex + query.length),
        style: style.copyWith(
          backgroundColor: Colors.yellow.withValues(alpha: 0.3),
          color: style.color,
        ),
      ));

      currentIndex = matchIndex + query.length;
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: textAlign ?? TextAlign.left,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
    );
  }
}
