import 'package:flutter/material.dart';

class SearchFilter {
  final String type;
  final String value;
  final Color color;

  const SearchFilter({
    required this.type,
    required this.value,
    this.color = const Color(0xFF2C3E50),
  });

  @override
  String toString() {
    return '$type:$value';
  }

  static Map<String, Color> defaultColors = {
    'category': Colors.blue.shade700,
    'type': Colors.purple.shade700,
    'tag': Colors.teal.shade700,
    'keyword': Colors.orange.shade700,
    'status': Colors.green.shade700,
  };

  factory SearchFilter.fromTypeValue(String type, String value) {
    return SearchFilter(
      type: type,
      value: value,
      color: defaultColors[type.toLowerCase()] ?? const Color(0xFF2C3E50),
    );
  }
}

/// Parses a search query into regular text and filter tags
class SearchParser {
  /// Parse a search query into regular text and filter tags
  /// Example input: "vmware type:document category: network"
  /// Output: {
  ///   text: "vmware",
  ///   filters: [SearchFilter(type: "type", value, "document"), ...]
  /// }
  static Map<String, dynamic> parseQuery(String query) {
    final List<SearchFilter> filters = [];
    final List<String> textParts = [];

    final RegExp filterRegex = RegExp(r'(\w+):(\w+)');

    bool inQuotes = false;
    List<String> parts = [];
    String currentPart = '';

    for (int i = 0; i < query.length; i++) {
      final char = query[i];

      if (char == '"') {
        inQuotes = !inQuotes;
        currentPart += char;
      } else if (char == ' ' && !inQuotes) {
        if (currentPart.isNotEmpty) {
          parts.add(currentPart);
          currentPart = '';
        }
      } else {
        currentPart += char;
      }
    }

    if (currentPart.isNotEmpty) {
      parts.add(currentPart);
    }

    for (final part in parts) {
      final match = filterRegex.firstMatch(part);
      if (match != null) {
        // This is a filter tag
        final type = match.group(1)!;
        final value = match.group(2)!;
        filters.add(SearchFilter.fromTypeValue(type, value));
      } else {
        textParts.add(part);
      }
    }

    return {
      'text': textParts.join(' '),
      'filters': filters,
    };
  }

  static String buildQuery(String text, List<SearchFilter> filters) {
    final parts = <String>[];

    if (text.isNotEmpty) {
      parts.add(text);
    }

    for (final filter in filters) {
      parts.add('${filter.type}:${filter.value}');
    }

    return parts.join(' ');
  }
}
