import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'keyword_tag.dart';
import 'highlighted_text.dart';

class LinkCard extends StatelessWidget {
  final Map<String, dynamic> link;
  final String searchQuery;

  const LinkCard({
    super.key,
    required this.link,
    required this.searchQuery,
  });

  Future<void> _launchURL(String urlString, {bool newTab = false}) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(
      url,
      webOnlyWindowName: newTab ? '_blank' : '_self',
    )) {
      throw Exception('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    const double cellWidth = 350.0;
    const double cellHeight = 145.0;

    return SizedBox(
      width: cellWidth,
      height: cellHeight,
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTertiaryTapUp: (_) => _launchURL(link['link'], newTab: true),
            onTapDown: (_) => _launchURL(link['link'], newTab: true),
            child: InkWell(
              onTap: () => _launchURL(link['link']),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HighlightedText(
                      text: link['title'],
                      query: searchQuery,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: HighlightedText(
                              text: link['description'],
                              query: searchQuery,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.3,
                                color: Color(0xFF2C3E50),
                              ),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (link['doc_link'] != '') ...[
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: const Color(0xFF2C3E50)
                                  .withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTertiaryTapUp: (_) =>
                                _launchURL(link['doc_link'], newTab: true),
                            child: TextButton.icon(
                              onPressed: () => _launchURL(link['doc_link']),
                              icon: const Icon(Icons.description_outlined,
                                  size: 16),
                              label: const Text('Documentation'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF2C3E50),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    KeywordsList(
                      keywords: link['keywords'] as List,
                      searchQuery: searchQuery,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
