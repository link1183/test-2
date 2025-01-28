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

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    const double cellWidth = 280.0;
    const double cellHeight = 200.0;

    return SizedBox(
      width: cellWidth,
      height: cellHeight,
      child: InkWell(
        onTap: () => _launchURL(link['doc_link']),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                spreadRadius: 2,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HighlightedText(
                        text: link['title'],
                        query: searchQuery,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      HighlightedText(
                        text: link['description'],
                        query: searchQuery,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Color(0xFF2C3E50),
                        ),
                        maxLines: 4,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              KeywordsList(
                keywords: link['keywords'] as List,
                searchQuery: searchQuery,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
