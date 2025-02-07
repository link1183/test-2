import 'package:flutter/material.dart';
import 'package:portail_it/screens/home/widgets/category_section/link_card/managers_list/manager_chip.dart';
import 'package:portail_it/screens/home/widgets/category_section/link_card/managers_list/managers_list.dart';

class ManagersRow extends StatelessWidget {
  final List<Manager> managers;
  final double availableWidth;

  final double maxWidth = 280;

  const ManagersRow({
    super.key,
    required this.managers,
    required this.availableWidth,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> visibleManagers = [];
    double currentWidth = 0;
    int visibleCount = 0;
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (var manager in managers) {
      final managerWidget = ManagerChip(manager: manager);
      final textSpan = TextSpan(
        text: manager.fullName,
        style: const TextStyle(fontSize: 12),
      );
      textPainter.text = textSpan;
      textPainter.layout();

      final chipWidth = textPainter.width + 16;

      if (currentWidth + chipWidth > maxWidth) {
        break;
      }

      currentWidth += chipWidth + 4;
      visibleCount++;
      visibleManagers.add(managerWidget);
    }

    if (visibleCount < managers.length) {
      final remainingManagers = managers.skip(visibleCount).toList();
      visibleManagers.add(
        PopupMenuButton<void>(
          tooltip: 'Voir les autres managers',
          offset: const Offset(0, 30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+${remainingManagers.length}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          itemBuilder: (context) => [
            PopupMenuItem<void>(
              enabled: false,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: remainingManagers
                    .map((manager) => ManagerChip(manager: manager))
                    .toList(),
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: visibleManagers,
    );
  }
}
