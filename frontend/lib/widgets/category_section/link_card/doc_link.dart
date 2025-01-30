import 'package:flutter/material.dart';
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
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFF2C3E50).withValues(alpha: 0.2),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _launchURL(docLink),
          onSecondaryTap: () => _launchURL(docLink),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: Color(0xFF2C3E50),
                ),
                SizedBox(width: 4),
                Text(
                  'Docs',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
