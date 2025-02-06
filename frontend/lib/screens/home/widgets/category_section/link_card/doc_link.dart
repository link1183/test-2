import 'package:flutter/material.dart';
import 'package:portail_it/theme/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class DocLink extends StatelessWidget {
  final String docLink;
  const DocLink({super.key, required this.docLink});

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
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        border: Border.all(
          color: AppTheme.primary.withCustomOpacity(0.2),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTertiaryTapUp: (_) => _launchURL(docLink),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _launchURL(docLink),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: AppTheme.primary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Docs',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
