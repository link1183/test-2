import 'package:flutter/material.dart';
import 'package:portail_it/screens/admin/widgets/data_table_widget.dart';
import 'package:portail_it/screens/admin/widgets/form_dialog.dart';
import 'package:portail_it/services/resource_service.dart';
import 'package:portail_it/theme/theme.dart';

class LinksPage extends StatefulWidget {
  const LinksPage({super.key});

  @override
  State<LinksPage> createState() => _LinksPageState();
}

class _LinksPageState extends State<LinksPage> {
  final ResourceService _linkService = ResourceService(ResourceType.links);
  final ResourceService _categoryService =
      ResourceService(ResourceType.categories);
  final ResourceService _statusService = ResourceService(ResourceType.statuses);
  final ResourceService _keywordService =
      ResourceService(ResourceType.keywords);
  final ResourceService _viewService = ResourceService(ResourceType.views);
  final ResourceService _managerService =
      ResourceService(ResourceType.managers);

  List<Map<String, dynamic>> _links = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _statuses = [];
  List<Map<String, dynamic>> _keywords = [];
  List<Map<String, dynamic>> _views = [];
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
              label: const Text('Add Link'),
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
            columns: const [
              'id',
              'title',
              'link',
              'status_name',
              'category_name'
            ],
            data: _links,
            onEdit: _showEditDialog,
            onDelete: _deleteLink,
            onView: _showViewDialog,
            isLoading: _isLoading,
            emptyMessage: 'No links found',
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value),
        ],
      ),
    );
  }

  List<Widget> _buildKeywordsList(List? keywords) {
    if (keywords == null || keywords.isEmpty) {
      return [const Text('No keywords')];
    }

    return keywords
        .map((k) => Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text('• ${k['keyword']}'),
            ))
        .toList();
  }

  Widget _buildLinkForm(
    BuildContext context,
    Map<String, dynamic> formData,
    Function(String, dynamic) updateField,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Title *',
            hintText: 'Enter link title',
            border: OutlineInputBorder(),
          ),
          initialValue: formData['title']?.toString() ?? '',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a title';
            }
            return null;
          },
          onChanged: (value) => updateField('title', value),
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Link URL *',
            hintText: 'Enter full URL (https://example.com)',
            border: OutlineInputBorder(),
          ),
          initialValue: formData['link']?.toString() ?? '',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a URL';
            }
            if (!Uri.tryParse(value)!.isAbsolute) {
              return 'Please enter a valid URL';
            }
            return null;
          },
          onChanged: (value) => updateField('link', value),
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Description *',
            hintText: 'Enter link description',
            border: OutlineInputBorder(),
          ),
          initialValue: formData['description']?.toString() ?? '',
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a description';
            }
            return null;
          },
          onChanged: (value) => updateField('description', value),
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Documentation Link',
            hintText: 'Enter documentation URL (optional)',
            border: OutlineInputBorder(),
          ),
          initialValue: formData['doc_link']?.toString() ?? '',
          validator: (value) {
            if (value != null &&
                value.isNotEmpty &&
                !Uri.tryParse(value)!.isAbsolute) {
              return 'Please enter a valid URL';
            }
            return null;
          },
          onChanged: (value) => updateField('doc_link', value),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(
            labelText: 'Status *',
            border: OutlineInputBorder(),
          ),
          value: formData['status_id'] as int?,
          items: _statuses.map((status) {
            return DropdownMenuItem<int>(
              value: status['id'] as int,
              child: Text(status['name']),
            );
          }).toList(),
          validator: (value) {
            if (value == null) {
              return 'Please select a status';
            }
            return null;
          },
          onChanged: (value) => updateField('status_id', value),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          decoration: const InputDecoration(
            labelText: 'Category *',
            border: OutlineInputBorder(),
          ),
          value: formData['category_id'] as int?,
          items: _categories.map((category) {
            return DropdownMenuItem<int>(
              value: category['id'] as int,
              child: Text(category['name']),
            );
          }).toList(),
          validator: (value) {
            if (value == null) {
              return 'Please select a category';
            }
            return null;
          },
          onChanged: (value) => updateField('category_id', value),
        ),
        const SizedBox(height: 24),
        const Text(
          'Keywords',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Wrap(
          spacing: 8,
          children: _keywords.map((keyword) {
            final keywordId = keyword['id'] as int;
            final isSelected =
                (formData['keywordIds'] as List<int>?)?.contains(keywordId) ??
                    false;

            return FilterChip(
              label: Text(keyword['keyword']),
              selected: isSelected,
              onSelected: (value) {
                final currentKeywords =
                    List<int>.from(formData['keywordIds'] ?? []);
                if (value) {
                  currentKeywords.add(keywordId);
                } else {
                  currentKeywords.remove(keywordId);
                }
                updateField('keywordIds', currentKeywords);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Views',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Wrap(
          spacing: 8,
          children: _views.map((view) {
            final viewId = view['id'] as int;
            final isSelected =
                (formData['viewIds'] as List<int>?)?.contains(viewId) ?? false;

            return FilterChip(
              label: Text(view['name']),
              selected: isSelected,
              onSelected: (value) {
                final currentViews = List<int>.from(formData['viewIds'] ?? []);
                if (value) {
                  currentViews.add(viewId);
                } else {
                  currentViews.remove(viewId);
                }
                updateField('viewIds', currentViews);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Managers',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Wrap(
          spacing: 8,
          children: _managers.map((manager) {
            final managerId = manager['id'] as int;
            final isSelected =
                (formData['managerIds'] as List<int>?)?.contains(managerId) ??
                    false;

            return FilterChip(
              label: Text('${manager['name']} ${manager['surname']}'),
              selected: isSelected,
              onSelected: (value) {
                final currentManagers =
                    List<int>.from(formData['managerIds'] ?? []);
                if (value) {
                  currentManagers.add(managerId);
                } else {
                  currentManagers.remove(managerId);
                }
                updateField('managerIds', currentManagers);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Widget> _buildManagersList(List? managers) {
    if (managers == null || managers.isEmpty) {
      return [const Text('No managers')];
    }

    return managers
        .map((m) => Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text('• ${m['name']} ${m['surname']}'),
            ))
        .toList();
  }

  List<Widget> _buildViewsList(List? views) {
    if (views == null || views.isEmpty) {
      return [const Text('No views')];
    }

    return views
        .map((v) => Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text('• ${v['name']}'),
            ))
        .toList();
  }

  Future<void> _createLink(Map<String, dynamic> data) async {
    try {
      await _linkService.create(data);
      _showSuccessSnackbar('Link created successfully');
      _loadData();
    } catch (e) {
      _showErrorSnackbar('Failed to create link: $e');
      rethrow;
    }
  }

  Future<void> _deleteLink(Map<String, dynamic> link) async {
    try {
      await _linkService.delete(link['id']);
      _showSuccessSnackbar('Link deleted successfully');
      _loadData();
    } catch (e) {
      _showErrorSnackbar('Failed to delete link: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all required data in parallel
      final results = await Future.wait([
        _linkService.getAll(),
        _categoryService.getAll(),
        _statusService.getAll(),
        _keywordService.getAll(),
        _viewService.getAll(),
        _managerService.getAll(),
      ]);

      setState(() {
        _links = results[0];
        _categories = results[1];
        _statuses = results[2];
        _keywords = results[3];
        _views = results[4];
        _managers = results[5];
      });
    } catch (e) {
      _showErrorSnackbar('Failed to load data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCreateDialog() {
    final initialData = {
      'link': '',
      'title': '',
      'description': '',
      'doc_link': '',
      'status_id': _statuses.isNotEmpty ? _statuses[0]['id'] : null,
      'category_id': _categories.isNotEmpty ? _categories[0]['id'] : null,
      'viewIds': <int>[],
      'keywordIds': <int>[],
      'managerIds': <int>[],
    };

    showDialog(
      context: context,
      builder: (context) => FormDialog(
        title: 'Create Link',
        initialData: initialData,
        formBuilder: _buildLinkForm,
        onSubmit: _createLink,
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> link) {
    // For edit, we need to extract the IDs from the relationships
    final viewIds =
        (link['views'] as List?)?.map((v) => v['id'] as int).toList() ??
            <int>[];

    final keywordIds =
        (link['keywords'] as List?)?.map((k) => k['id'] as int).toList() ??
            <int>[];

    final managerIds =
        (link['managers'] as List?)?.map((m) => m['id'] as int).toList() ??
            <int>[];

    final editData = {
      ...link,
      'viewIds': viewIds,
      'keywordIds': keywordIds,
      'managerIds': managerIds,
    };

    showDialog(
      context: context,
      builder: (context) => FormDialog(
        title: 'Edit Link',
        initialData: editData,
        formBuilder: _buildLinkForm,
        onSubmit: (data) => _updateLink(link['id'], data),
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

  void _showViewDialog(Map<String, dynamic> link) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(link['title']),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailItem('Link', link['link']),
              _buildDetailItem('Description', link['description']),
              _buildDetailItem('Documentation', link['doc_link'] ?? 'N/A'),
              _buildDetailItem('Status', link['status_name'] ?? 'Unknown'),
              _buildDetailItem('Category', link['category_name'] ?? 'Unknown'),
              const SizedBox(height: 16),
              const Text(
                'Keywords',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ..._buildKeywordsList(link['keywords'] as List?),
              const SizedBox(height: 16),
              const Text(
                'Views',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ..._buildViewsList(link['views'] as List?),
              const SizedBox(height: 16),
              const Text(
                'Managers',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ..._buildManagersList(link['managers'] as List?),
            ],
          ),
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

  Future<void> _updateLink(int id, Map<String, dynamic> data) async {
    try {
      await _linkService.update(id, data);
      _showSuccessSnackbar('Link updated successfully');
      _loadData();
    } catch (e) {
      _showErrorSnackbar('Failed to update link: $e');
      rethrow;
    }
  }
}
