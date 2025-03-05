import 'package:flutter/material.dart';
import 'search_filter.dart';

/// A chip widget that displays a filter tag
class FilterTagChip extends StatelessWidget {
  final SearchFilter filter;
  final VoidCallback? onRemove;

  const FilterTagChip({
    super.key,
    required this.filter,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: Chip(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        backgroundColor: filter.color.withValues(alpha: 0.1),
        side: BorderSide(color: filter.color.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        label: Text(
          '${filter.type}:${filter.value}',
          style: TextStyle(
            fontSize: 12,
            color: filter.color,
            fontWeight: FontWeight.w500,
          ),
        ),
        deleteIcon: Icon(
          Icons.close_rounded,
          size: 16,
          color: filter.color,
        ),
        onDeleted: onRemove,
      ),
    );
  }
}
