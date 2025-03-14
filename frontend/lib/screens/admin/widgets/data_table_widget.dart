import 'package:flutter/material.dart';
import 'package:portail_it/theme/theme.dart';

class ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final String tooltip;

  const ActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class DataTableWidget extends StatelessWidget {
  final List<String> columns;
  final List<Map<String, dynamic>> data;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onDelete;
  final Function(Map<String, dynamic>) onView;
  final bool isLoading;
  final String emptyMessage;
  final Widget? floatingActionButton;

  const DataTableWidget({
    super.key,
    required this.columns,
    required this.data,
    required this.onEdit,
    required this.onDelete,
    required this.onView,
    this.isLoading = false,
    this.emptyMessage = 'Aucune donnée',
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (data.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.inbox,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          else
            Card(
              elevation: 2,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: PaginatedDataTable(
                    header: const Text(''),
                    rowsPerPage: 10,
                    columns: [
                      ...columns.map(
                        (column) => DataColumn(
                          label: Text(
                            column,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const DataColumn(
                        label: Text(
                          'Actions',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    source: _DataSource(
                      data: data,
                      columns: columns,
                      onEdit: onEdit,
                      onDelete: onDelete,
                      onView: onView,
                      context: context,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

class _DataSource extends DataTableSource {
  final List<Map<String, dynamic>> data;
  final List<String> columns;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onDelete;
  final Function(Map<String, dynamic>) onView;
  final BuildContext context;

  _DataSource({
    required this.data,
    required this.columns,
    required this.onEdit,
    required this.onDelete,
    required this.onView,
    required this.context,
  });

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => data.length;

  @override
  int get selectedRowCount => 0;

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final item = data[index];

    return DataRow(
      cells: [
        ...columns.map(
          (column) => DataCell(
            Text(
              _formatCellValue(item[column]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ActionButton(
                icon: Icons.visibility,
                onPressed: () => onView(item),
                color: AppTheme.accent,
                tooltip: 'Voir',
              ),
              const SizedBox(width: 8),
              ActionButton(
                icon: Icons.edit,
                onPressed: () => onEdit(item),
                color: Colors.amber,
                tooltip: 'Modifier',
              ),
              const SizedBox(width: 8),
              ActionButton(
                icon: Icons.delete,
                onPressed: () => _confirmDelete(item),
                color: Colors.red,
                tooltip: 'Supprimer',
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmDelete(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cet élément ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDelete(item);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  String _formatCellValue(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      return value.join(', ');
    }
    return value.toString();
  }
}
