import 'package:flutter/material.dart';
import 'package:portail_it/screens/admin/widgets/data_table_widget.dart';
import 'package:portail_it/screens/admin/widgets/form_dialog.dart';
import 'package:portail_it/services/resource_service.dart';
import 'package:portail_it/theme/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class ManagersPage extends StatefulWidget {
  const ManagersPage({super.key});

  @override
  State<ManagersPage> createState() => _ManagersPageState();
}

class _ManagersPageState extends State<ManagersPage> {
  final ResourceService _managerService =
      ResourceService(ResourceType.managers);
  List<Map<String, dynamic>> _managers = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: _showCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Manager'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: DataTableWidget(
            columns: const ['id', 'name', 'surname', 'link'],
            data: _managers,
            onEdit: _showEditDialog,
            onDelete: _deleteManager,
            onView: _showViewDialog,
            isLoading: _isLoading,
            emptyMessage: 'No managers found',
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadManagers();
  }

  Widget _buildManagerForm(
    BuildContext context,
    Map<String, dynamic> formData,
    Function(String, dynamic) updateField,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Name *',
            hintText: 'Enter first name',
            border: OutlineInputBorder(),
          ),
          initialValue: formData['name']?.toString() ?? '',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a name';
            }
            return null;
          },
          onChanged: (value) => updateField('name', value),
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Surname *',
            hintText: 'Enter last name',
            border: OutlineInputBorder(),
          ),
          initialValue: formData['surname']?.toString() ?? '',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a surname';
            }
            return null;
          },
          onChanged: (value) => updateField('surname', value),
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Link',
            hintText: 'Enter optional profile URL',
            border: OutlineInputBorder(),
          ),
          initialValue: formData['link']?.toString() ?? '',
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              if (!Uri.tryParse(value)!.isAbsolute) {
                return 'Please enter a valid URL';
              }
            }
            return null;
          },
          onChanged: (value) => updateField('link', value),
        ),
      ],
    );
  }

  Future<void> _createManager(Map<String, dynamic> data) async {
    try {
      await _managerService.create(data);
      _showSuccessSnackbar('Manager created successfully');
      _loadManagers();
    } catch (e) {
      _showErrorSnackbar('Failed to create manager: $e');
      rethrow;
    }
  }

  Future<void> _deleteManager(Map<String, dynamic> manager) async {
    try {
      await _managerService.delete(manager['id']);
      _showSuccessSnackbar('Manager deleted successfully');
      _loadManagers();
    } catch (e) {
      _showErrorSnackbar('Failed to delete manager: $e');
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showErrorSnackbar('Could not launch $url');
    }
  }

  Future<void> _loadManagers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final managers = await _managerService.getAll();
      setState(() {
        _managers = managers;
      });
    } catch (e) {
      _showErrorSnackbar('Failed to load managers: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => FormDialog(
        title: 'Create Manager',
        initialData: {
          'name': '',
          'surname': '',
          'link': '',
        },
        formBuilder: _buildManagerForm,
        onSubmit: _createManager,
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> manager) {
    showDialog(
      context: context,
      builder: (context) => FormDialog(
        title: 'Edit Manager',
        initialData: Map<String, dynamic>.from(manager),
        formBuilder: _buildManagerForm,
        onSubmit: (data) => _updateManager(manager['id'], data),
        isEdit: true,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showViewDialog(Map<String, dynamic> manager) {
    final hasLink = manager['link'] != null &&
        manager['link'].toString().isNotEmpty &&
        Uri.tryParse(manager['link'].toString())?.isAbsolute == true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${manager['name']} ${manager['surname']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ID:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(manager['id'].toString()),
            const SizedBox(height: 8),
            const Text(
              'Name:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(manager['name']),
            const SizedBox(height: 8),
            const Text(
              'Surname:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(manager['surname']),
            const SizedBox(height: 8),
            const Text(
              'Link:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (hasLink)
              InkWell(
                onTap: () => _launchUrl(manager['link'].toString()),
                child: Text(
                  manager['link'].toString(),
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              )
            else
              const Text('No link available'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateManager(int id, Map<String, dynamic> data) async {
    try {
      await _managerService.update(id, data);
      _showSuccessSnackbar('Manager updated successfully');
      _loadManagers();
    } catch (e) {
      _showErrorSnackbar('Failed to update manager: $e');
      rethrow;
    }
  }
}
