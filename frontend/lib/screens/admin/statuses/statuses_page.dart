import 'package:flutter/material.dart';
import 'package:portail_it/screens/admin/widgets/data_table_widget.dart';
import 'package:portail_it/screens/admin/widgets/form_dialog.dart';
import 'package:portail_it/services/resource_service.dart';
import 'package:portail_it/theme/theme.dart';

class StatusesPage extends StatefulWidget {
  const StatusesPage({super.key});

  @override
  State<StatusesPage> createState() => _StatusesPageState();
}

class _StatusesPageState extends State<StatusesPage> {
  final ResourceService _statusService = ResourceService(ResourceType.statuses);
  List<Map<String, dynamic>> _statuses = [];
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
              label: const Text('Add Status'),
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
            data: _statuses,
            onEdit: _showEditDialog,
            onDelete: _deleteStatus,
            onView: _showViewDialog,
            isLoading: _isLoading,
            emptyMessage: 'No statuses found',
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  Widget _buildStatusForm(
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
            hintText: 'Enter status name',
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
      ],
    );
  }

  Future<void> _createStatus(Map<String, dynamic> data) async {
    try {
      await _statusService.create(data);
      _showSuccessSnackbar('Status created successfully');
      _loadStatuses();
    } catch (e) {
      _showErrorSnackbar('Failed to create status: $e');
      rethrow;
    }
  }

  Future<void> _deleteStatus(Map<String, dynamic> status) async {
    try {
      await _statusService.delete(status['id']);
      _showSuccessSnackbar('Status deleted successfully');
      _loadStatuses();
    } catch (e) {
      _showErrorSnackbar('Failed to delete status: $e');
    }
  }

  Future<void> _loadStatuses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final statuses = await _statusService.getAll();
      setState(() {
        _statuses = statuses;
      });
    } catch (e) {
      _showErrorSnackbar('Failed to load statuses: $e');
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
        title: 'Create Status',
        initialData: {'name': ''},
        formBuilder: _buildStatusForm,
        onSubmit: _createStatus,
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> status) {
    showDialog(
      context: context,
      builder: (context) => FormDialog(
        title: 'Edit Status',
        initialData: Map<String, dynamic>.from(status),
        formBuilder: _buildStatusForm,
        onSubmit: (data) => _updateStatus(status['id'], data),
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

  void _showViewDialog(Map<String, dynamic> status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Status Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Name:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(status['name']),
            const SizedBox(height: 8),
            const Text(
              'ID:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(status['id'].toString()),
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

  Future<void> _updateStatus(int id, Map<String, dynamic> data) async {
    try {
      await _statusService.update(id, data);
      _showSuccessSnackbar('Status updated successfully');
      _loadStatuses();
    } catch (e) {
      _showErrorSnackbar('Failed to update status: $e');
      rethrow;
    }
  }
}
