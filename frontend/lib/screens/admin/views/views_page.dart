import 'package:flutter/material.dart';
import 'package:portail_it/screens/admin/widgets/data_table_widget.dart';
import 'package:portail_it/screens/admin/widgets/form_dialog.dart';
import 'package:portail_it/services/resource_service.dart';
import 'package:portail_it/theme/theme.dart';

class ViewsPage extends StatefulWidget {
  const ViewsPage({super.key});

  @override
  State<ViewsPage> createState() => _ViewsPageState();
}

class _ViewsPageState extends State<ViewsPage> {
  final ResourceService _viewService = ResourceService(ResourceType.views);
  List<Map<String, dynamic>> _views = [];
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
              label: const Text('Add View'),
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
            columns: const ['id', 'name'],
            data: _views,
            onEdit: _showEditDialog,
            onDelete: _deleteView,
            onView: _showViewDialog,
            isLoading: _isLoading,
            emptyMessage: 'No views found',
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadViews();
  }

  Widget _buildViewForm(
    BuildContext context,
    Map<String, dynamic> formData,
    Function(String, dynamic) updateField,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Enter view name',
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
        const Text(
          'The view name should match LDAP group names to control access. Users will only see links assigned to views matching their LDAP groups.',
          style: TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Future<void> _createView(Map<String, dynamic> data) async {
    try {
      await _viewService.create(data);
      _showSuccessSnackbar('View created successfully');
      _loadViews();
    } catch (e) {
      _showErrorSnackbar('Failed to create view: $e');
      rethrow;
    }
  }

  Future<void> _deleteView(Map<String, dynamic> view) async {
    try {
      await _viewService.delete(view['id']);
      _showSuccessSnackbar('View deleted successfully');
      _loadViews();
    } catch (e) {
      _showErrorSnackbar('Failed to delete view: $e');
    }
  }

  Future<void> _loadViews() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final views = await _viewService.getAll();
      setState(() {
        _views = views;
      });
    } catch (e) {
      _showErrorSnackbar('Failed to load views: $e');
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
        title: 'Create View',
        initialData: {'name': ''},
        formBuilder: _buildViewForm,
        onSubmit: _createView,
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> view) {
    showDialog(
      context: context,
      builder: (context) => FormDialog(
        title: 'Edit View',
        initialData: Map<String, dynamic>.from(view),
        formBuilder: _buildViewForm,
        onSubmit: (data) => _updateView(view['id'], data),
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

  void _showViewDialog(Map<String, dynamic> view) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('View Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Name:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(view['name']),
            const SizedBox(height: 8),
            const Text(
              'ID:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(view['id'].toString()),
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

  Future<void> _updateView(int id, Map<String, dynamic> data) async {
    try {
      await _viewService.update(id, data);
      _showSuccessSnackbar('View updated successfully');
      _loadViews();
    } catch (e) {
      _showErrorSnackbar('Failed to update view: $e');
      rethrow;
    }
  }
}
