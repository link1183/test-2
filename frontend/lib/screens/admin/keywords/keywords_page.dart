import 'package:flutter/material.dart';
import 'package:portail_it/screens/admin/widgets/data_table_widget.dart';
import 'package:portail_it/screens/admin/widgets/form_dialog.dart';
import 'package:portail_it/services/resource_service.dart';
import 'package:portail_it/theme/theme.dart';

class KeywordsPage extends StatefulWidget {
  const KeywordsPage({super.key});

  @override
  State<KeywordsPage> createState() => _KeywordsPageState();
}

class _KeywordsPageState extends State<KeywordsPage> {
  final ResourceService _keywordService =
      ResourceService(ResourceType.keywords);
  List<Map<String, dynamic>> _keywords = [];
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
              label: const Text('Add Keyword'),
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
            columns: const ['id', 'keyword'],
            data: _keywords,
            onEdit: _showEditDialog,
            onDelete: _deleteKeyword,
            onView: _showViewDialog,
            isLoading: _isLoading,
            emptyMessage: 'No keywords found',
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadKeywords();
  }

  Widget _buildKeywordForm(
    BuildContext context,
    Map<String, dynamic> formData,
    Function(String, dynamic) updateField,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Keyword',
            hintText: 'Enter keyword',
            border: OutlineInputBorder(),
          ),
          initialValue: formData['keyword']?.toString() ?? '',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a keyword';
            }
            return null;
          },
          onChanged: (value) => updateField('keyword', value),
        ),
      ],
    );
  }

  Future<void> _createKeyword(Map<String, dynamic> data) async {
    try {
      await _keywordService.create(data);
      _showSuccessSnackbar('Keyword created successfully');
      _loadKeywords();
    } catch (e) {
      _showErrorSnackbar('Failed to create keyword: $e');
      rethrow;
    }
  }

  Future<void> _deleteKeyword(Map<String, dynamic> keyword) async {
    try {
      await _keywordService.delete(keyword['id']);
      _showSuccessSnackbar('Keyword deleted successfully');
      _loadKeywords();
    } catch (e) {
      _showErrorSnackbar('Failed to delete keyword: $e');
    }
  }

  Future<void> _loadKeywords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final keywords = await _keywordService.getAll();
      setState(() {
        _keywords = keywords;
      });
    } catch (e) {
      _showErrorSnackbar('Failed to load keywords: $e');
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
        title: 'Create Keyword',
        initialData: {'keyword': ''},
        formBuilder: _buildKeywordForm,
        onSubmit: _createKeyword,
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> keyword) {
    showDialog(
      context: context,
      builder: (context) => FormDialog(
        title: 'Edit Keyword',
        initialData: Map<String, dynamic>.from(keyword),
        formBuilder: _buildKeywordForm,
        onSubmit: (data) => _updateKeyword(keyword['id'], data),
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

  void _showViewDialog(Map<String, dynamic> keyword) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keyword Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Keyword:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(keyword['keyword']),
            const SizedBox(height: 8),
            const Text(
              'ID:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(keyword['id'].toString()),
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

  Future<void> _updateKeyword(int id, Map<String, dynamic> data) async {
    try {
      await _keywordService.update(id, data);
      _showSuccessSnackbar('Keyword updated successfully');
      _loadKeywords();
    } catch (e) {
      _showErrorSnackbar('Failed to update keyword: $e');
      rethrow;
    }
  }
}
