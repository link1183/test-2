import 'package:backend/db/database_exceptions.dart';
import 'package:backend/utils/logger.dart';
import 'package:sqlite3/sqlite3.dart';

class TransactionManager {
  final Database _db;
  final _logger = LoggerFactory.getLogger('TransactionManager');
  bool _inTransaction = false;

  TransactionManager(this._db);

  Future<void> beginTransaction() async {
    if (_inTransaction) {
      throw DatabaseException('Transaction already in progress');
    }

    try {
      _db.execute('BEGIN TRANSACTION;');
      _inTransaction = true;
    } catch (e, stackTrace) {
      _logger.error('Failed to begin transaction', e, stackTrace);
      throw DatabaseException('Failed to begin transaction', e, stackTrace);
    }
  }

  Future<void> commitTransaction() async {
    if (!_inTransaction) {
      throw DatabaseException('No transaction in progress');
    }

    try {
      _db.execute('COMMIT;');
      _inTransaction = false;
    } catch (e, stackTrace) {
      _logger.error('Failed to commit transaction', e, stackTrace);
      throw DatabaseException('Failed to commit transaction', e, stackTrace);
    }
  }

  Future<void> rollbackTransaction() async {
    if (!_inTransaction) {
      throw DatabaseException('No transaction in progress');
    }

    try {
      _db.execute('ROLLBACK;');
      _inTransaction = false;
    } catch (e, stackTrace) {
      _logger.error('Failed to rollback transaction', e, stackTrace);
      throw DatabaseException('Failed to rollback transaction', e, stackTrace);
    }
  }
}
