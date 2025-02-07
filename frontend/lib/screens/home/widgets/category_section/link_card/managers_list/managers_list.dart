import 'package:flutter/material.dart';
import 'package:portail_it/screens/home/widgets/category_section/link_card/managers_list/managers_row.dart';

class Manager {
  final int id;
  final String name;
  final String surname;
  final String link;

  const Manager({
    required this.id,
    required this.name,
    required this.surname,
    required this.link,
  });

  String get fullName => '$name $surname';

  factory Manager.fromJson(Map<String, dynamic> json) {
    return Manager(
      id: json['id'] as int,
      name: json['name'] as String,
      surname: json['surname'] as String,
      link: json['link'] as String,
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
              return ManagersRow(
                managers: managersList,
                availableWidth: constraints.maxWidth,
              );
            },
          ),
        ),
      ],
    );
  }
}
