import 'package:flutter/material.dart';
import 'package:portail_it/screens/home/widgets/category_section/link_card/managers_list/managers_list.dart';
import 'package:toastification/toastification.dart';
import 'package:url_launcher/url_launcher.dart';

class ManagerChip extends StatelessWidget {
  final Manager manager;

  const ManagerChip({
    super.key,
    required this.manager,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () {
          if (manager.link.isNotEmpty) {
            _launchURL(manager.link);
          } else {
            toastification.show(
              context: context,
              closeOnClick: true,
              type: ToastificationType.info,
              style: ToastificationStyle.flatColored,
              title: Text("Information"),
              description:
                  Text("pas de lien disponible pour ${manager.fullName}"),
              alignment: Alignment.topRight,
              autoCloseDuration: const Duration(seconds: 3),
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: highModeShadow,
              showProgressBar: false,
              pauseOnHover: false,
              applyBlurEffect: false,
            );
          }
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

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(
      url,
      webOnlyWindowName: '_blank',
    )) {
      throw Exception('Could not launch $urlString');
    }
  }
}
