import 'package:flutter/material.dart';

class Manager {
  final int id;
  final String name;
  final String surname;

  const Manager({
    required this.id,
    required this.name,
    required this.surname,
  });

  String get fullName => '$name $surname';

  // Factory to create from JSON
  factory Manager.fromJson(Map<String, dynamic> json) {
    return Manager(
      id: json['id'] as int,
      name: json['name'] as String,
      surname: json['surname'] as String,
    );
  }
}

class ManagersList extends StatelessWidget {
  final List<dynamic> managers;
  final double maxWidth;

  const ManagersList({
    super.key,
    required this.managers,
    this.maxWidth = 280,
  });

  @override
  Widget build(BuildContext context) {
    if (managers.isEmpty) return const SizedBox.shrink();

    final List<Manager> managersList = managers
        .map((m) => Manager.fromJson(m as Map<String, dynamic>))
        .toList();

    return Row(
      children: [
        const Icon(
          Icons.people_outline,
          size: 14,
          color: Color(0xFF2C3E50),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return _buildManagersRow(
                managersList,
                constraints.maxWidth,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildManagersRow(List<Manager> managers, double availableWidth) {
    final List<Widget> visibleManagers = [];
    double currentWidth = 0;
    int visibleCount = 0;
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (var manager in managers) {
      final managerWidget = _buildManagerChip(manager);
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
                    .map((manager) => _buildManagerChip(manager))
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

  Widget _buildManagerChip(Manager manager) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () {
          // TODO: Implement navigation/action when clicking on a manager
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFF2C3E50).withValues(alpha: 0.1),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            manager.fullName,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF2C3E50),
            ),
          ),
        ),
      ),
    );
  }
}
