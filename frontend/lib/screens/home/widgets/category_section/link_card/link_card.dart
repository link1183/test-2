import 'package:flutter/material.dart';
import 'package:portail_it/theme/theme.dart';
import 'package:portail_it/screens/home/widgets/category_section/link_card/doc_link.dart';
import 'package:portail_it/screens/home/widgets/category_section/link_card/managers_list/managers_list.dart';
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
    if (!await launchUrl(
      url,
      webOnlyWindowName: '_blank',
    )) {
      throw Exception('Could not launch $urlString');
    }
  }

  @override
  Widget build(BuildContext context) {
    const double cellWidth = 350.0;
    const double cellHeight = 200.0;

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
            onTertiaryTapUp: (_) => _launchURL(link['link']),
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
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    if ((link['managers'] as List?)?.isNotEmpty ?? false) ...[
                      ManagersList(managers: link['managers'] as List),
                      const SizedBox(height: 4),
                    ],
                    Expanded(
                      child: HighlightedText(
                        text: link['description'],
                        query: searchQuery,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          color: Color(0xFF2C3E50),
                        ),
                        maxLines: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (link['doc_link'].isNotEmpty) ...[
                      DocLink(docLink: link['doc_link']),
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
