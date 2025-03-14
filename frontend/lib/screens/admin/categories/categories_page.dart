import 'package:flutter/material.dart';
import 'package:portail_it/screens/admin/widgets/data_table_widget.dart';
import 'package:portail_it/screens/admin/widgets/form_dialog.dart';
import 'package:portail_it/services/resource_service.dart';
import 'package:portail_it/theme/theme.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final ResourceService _categoryService =
      ResourceService(ResourceType.categories);
  List<Map<String, dynamic>> _categories = [];
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
              label: const Text('Add Category'),
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
            data: _categories,
            onEdit: _showEditDialog,
            onDelete: _deleteCategory,
            onView: _showViewDialog,
            isLoading: _isLoading,
            emptyMessage: 'No categories found',
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Widget _buildCategoryForm(
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
            hintText: 'Enter category name',
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

  Future<void> _createCategory(Map<String, dynamic> data) async {
    try {
      await _categoryService.create(data);
      _showSuccessSnackbar('Category created successfully');
      _loadCategories();
    } catch (e) {
      _showErrorSnackbar('Failed to create category: $e');
      rethrow;
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    try {
      await _categoryService.delete(category['id']);
      _showSuccessSnackbar('Category deleted successfully');
      _loadCategories();
    } catch (e) {
      _showErrorSnackbar('Failed to delete category: $e');
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await _categoryService.getAll();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      _showErrorSnackbar('Failed to load categories: $e');
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
        title: 'Create Category',
        initialData: {'name': ''},
        formBuilder: _buildCategoryForm,
        onSubmit: _createCategory,
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (context) => FormDialog(
        title: 'Edit Category',
        initialData: Map<String, dynamic>.from(category),
        formBuilder: _buildCategoryForm,
        onSubmit: (data) => _updateCategory(category['id'], data),
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

  void _showViewDialog(Map<String, dynamic> category) {
    // Just show the edit dialog in read-only mode for simplicity
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Category Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Name:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(category['name']),
            const SizedBox(height: 8),
            const Text(
              'ID:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(category['id'].toString()),
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

  Future<void> _updateCategory(int id, Map<String, dynamic> data) async {
    try {
      await _categoryService.update(id, data);
      _showSuccessSnackbar('Category updated successfully');
      _loadCategories();
    } catch (e) {
      _showErrorSnackbar('Failed to update category: $e');
      rethrow;
    }
  }
}

