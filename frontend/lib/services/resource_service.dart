import 'dart:convert';

import 'package:portail_it/services/api_client.dart';
import 'package:portail_it/services/logger.dart';

class ResourceService {
  final ResourceType resourceType;

  const ResourceService(this.resourceType);

  Future<bool> create(Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.post(resourceType.endpoint, body: data);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['error']['message'] ?? 'Failed to create resource',
        );
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to create ${resourceType.name}', e, stackTrace);
      throw Exception('Failed to create: $e');
    }
  }

  Future<bool> delete(int id) async {
    try {
      final response = await ApiClient.delete('${resourceType.endpoint}/$id');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['error']['message'] ?? 'Failed to delete resource',
        );
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to delete ${resourceType.name}', e, stackTrace);
      throw Exception('Failed to delete: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAll() async {
    try {
      final response = await ApiClient.get(resourceType.endpoint);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body);

        // Different resources have different response structures
        switch (resourceType) {
          case ResourceType.categories:
            return List<Map<String, dynamic>>.from(data['categories']);
          case ResourceType.keywords:
            return List<Map<String, dynamic>>.from(data['keywords']);
          case ResourceType.links:
            return List<Map<String, dynamic>>.from(data['links']);
          case ResourceType.managers:
            return List<Map<String, dynamic>>.from(data['managers']);
          case ResourceType.statuses:
            return List<Map<String, dynamic>>.from(data['statuses']);
          case ResourceType.views:
            return List<Map<String, dynamic>>.from(data['views']);
          default:
            return [];
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['error']['message'] ?? 'Failed to get resources',
        );
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to get ${resourceType.name}', e, stackTrace);
      throw Exception('Failed to load data: $e');
    }
  }

  Future<Map<String, dynamic>> getById(int id) async {
    try {
      final response = await ApiClient.get('${resourceType.endpoint}/$id');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = json.decode(response.body);

        // Different resources have different response structures
        switch (resourceType) {
          case ResourceType.categories:
            return data['category'];
          case ResourceType.keywords:
            return data['keyword'];
          case ResourceType.links:
            return data['link'];
          case ResourceType.managers:
            return data['manager'];
          case ResourceType.statuses:
            return data['status'];
          case ResourceType.views:
            return data['view'];
          default:
            return {};
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['error']['message'] ?? 'Failed to get resource',
        );
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to get ${resourceType.name} by ID', e, stackTrace);
      throw Exception('Failed to load data: $e');
    }
  }

  Future<bool> update(int id, Map<String, dynamic> data) async {
    try {
      final response = await ApiClient.put(
        '${resourceType.endpoint}/$id',
        body: data,
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['error']['message'] ?? 'Failed to update resource',
        );
      }
    } catch (e, stackTrace) {
      Logger.error('Failed to update ${resourceType.name}', e, stackTrace);
      throw Exception('Failed to update: $e');
    }
  }

  static Map<String, dynamic> createEmptyCategory() {
    return {'name': ''};
  }

  static Map<String, dynamic> createEmptyKeyword() {
    return {'keyword': ''};
  }

  static Map<String, dynamic> createEmptyManager() {
    return {
      'name': '',
      'surname': '',
      'link': '',
    };
  }

  static Map<String, dynamic> createEmptyStatus() {
    return {'name': ''};
  }

  static Map<String, dynamic> createEmptyView() {
    return {'name': ''};
  }
}

enum ResourceType {
  categories,
  keywords,
  links,
  managers,
  statuses,
  views,
  admin,
}

extension ResourceTypeExtension on ResourceType {
  String get endpoint {
    switch (this) {
      case ResourceType.categories:
        return '/api/categories';
      case ResourceType.keywords:
        return '/api/keywords';
      case ResourceType.links:
        return '/api/links';
      case ResourceType.managers:
        return '/api/managers';
      case ResourceType.statuses:
        return '/api/statuses';
      case ResourceType.views:
        return '/api/views';
      case ResourceType.admin:
        return '/api/admin';
    }
  }
}
