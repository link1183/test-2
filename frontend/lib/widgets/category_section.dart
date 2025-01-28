import 'package:flutter/material.dart';
import 'link_card.dart';

class CategorySection extends StatelessWidget {
  final Map<String, dynamic> category;
  final bool isExpanded;
  final VoidCallback onToggle;

  const CategorySection({
    super.key,
    required this.category,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    const double cellSpacing = 16.0;

    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 32, 0, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: Text(
                    category['category_name'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFF2C3E50),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: isExpanded ? null : 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isExpanded ? 1.0 : 0.0,
            child: Center(
              child: Wrap(
                spacing: cellSpacing,
                runSpacing: cellSpacing,
                alignment: WrapAlignment.center,
                children: (category['links'] as List)
                    .map((link) => LinkCard(link: link))
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
