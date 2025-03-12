import 'package:backend/db/database.dart';
import 'package:backend/utils/logger.dart';

class KeywordService {
  final AppDatabase db;
  final _logger = LoggerFactory.getLogger('KeywordService');

  KeywordService(this.db);

  Future<int> createKeyword(String keyword) async {
    try {
      return await db.createKeyword(keyword: keyword);
    } catch (e, stackTrace) {
      _logger
          .error('Error creating keyword', e, stackTrace, {'keyword': keyword});
      throw Exception('Failed to create keyword: ${e.toString()}');
    }
  }

  Future<bool> deleteKeyword(int id) async {
    try {
      return await db.deleteKeyword(id);
    } catch (e, stackTrace) {
      _logger.error('Error deleting keyword', e, stackTrace, {'id': id});
      throw Exception('Failed to delete keyword: ${e.toString()}');
    }
  }

  List<Map<String, dynamic>> getAllKeywords() {
    try {
      return db.getAllKeywords();
    } catch (e, stackTrace) {
      _logger.error('Error retrieving all keywords', e, stackTrace);
      throw Exception('Failed to retrieve keywords');
    }
  }

  Map<String, dynamic>? getKeywordById(int id) {
    try {
      return db.getKeywordById(id);
    } catch (e, stackTrace) {
      _logger
          .error('Error retrieving keyword by ID', e, stackTrace, {'id': id});
      throw Exception('Failed to retrieve keyword');
    }
  }

  List<Map<String, dynamic>> getLinksByKeywordId(int keywordId) {
    try {
      return db.getLinksByKeywordId(keywordId);
    } catch (e, stackTrace) {
      _logger.error('Error retrieving links by keyword ID', e, stackTrace,
          {'keywordId': keywordId});
      throw Exception('Failed to retrieve links for keyword');
    }
  }

  Future<bool> updateKeyword(int id, String keyword) async {
    try {
      return await db.updateKeyword(id: id, keyword: keyword);
    } catch (e, stackTrace) {
      _logger.error('Error updating keyword', e, stackTrace,
          {'id': id, 'keyword': keyword});
      throw Exception('Failed to update keyword: ${e.toString()}');
    }
  }
}
