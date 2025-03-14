import 'package:flutter/material.dart';
import 'package:portail_it/screens/admin/categories/categories_page.dart';
import 'package:portail_it/screens/admin/keywords/keywords_page.dart';
import 'package:portail_it/screens/admin/links/links_page.dart';
import 'package:portail_it/screens/admin/managers/managers_page.dart';
import 'package:portail_it/screens/admin/statuses/statuses_page.dart';
import 'package:portail_it/screens/admin/views/views_page.dart';
import 'package:portail_it/screens/shared/widgets/footer.dart';
import 'package:portail_it/screens/shared/widgets/header.dart';
import 'package:portail_it/theme/theme.dart';

class AdminDashboard extends StatefulWidget {
  static const routeName = '/admin';

  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final _pages = [
    const LinksPage(),
    const CategoriesPage(),
    const KeywordsPage(),
    const StatusesPage(),
    const ViewsPage(),
    const ManagersPage(),
  ];

  final _pageTitles = [
    'Liens',
    'Catégories',
    'Mots-clés',
    'Statuts',
    'Vues',
    'Responsables',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          const Header(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sidebar navigation
                Container(
                  width: 250,
                  color: AppTheme.primary,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        color: AppTheme.primary.withCustomOpacity(0.8),
                        child: const Row(
                          children: [
                            Icon(Icons.admin_panel_settings,
                                color: AppTheme.textLight),
                            SizedBox(width: 12),
                            Text(
                              'Administration',
                              style: TextStyle(
                                color: AppTheme.textLight,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _pageTitles.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              leading: Icon(
                                _getIconForIndex(index),
                                color: _selectedIndex == index
                                    ? Colors.white
                                    : Colors.white70,
                              ),
                              title: Text(
                                _pageTitles[index],
                                style: TextStyle(
                                  color: _selectedIndex == index
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                              ),
                              selected: _selectedIndex == index,
                              selectedTileColor:
                                  AppTheme.primary.withCustomOpacity(0.3),
                              onTap: () {
                                setState(() {
                                  _selectedIndex = index;
                                });
                              },
                            );
                          },
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.exit_to_app,
                            color: Colors.white70),
                        title: const Text(
                          'Retour au portail',
                          style: TextStyle(color: Colors.white70),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
                // Main content area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Page title bar
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        color: Colors.white,
                        child: Row(
                          children: [
                            Text(
                              _pageTitles[_selectedIndex],
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Page content
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(24.0),
                          child: _pages[_selectedIndex],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Footer(),
        ],
      ),
    );
  }

  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0:
        return Icons.link;
      case 1:
        return Icons.category;
      case 2:
        return Icons.key;
      case 3:
        return Icons.track_changes;
      case 4:
        return Icons.visibility;
      case 5:
        return Icons.people;
      default:
        return Icons.circle;
    }
  }
}

