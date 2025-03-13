import 'package:backend/controllers/admin_controller.dart';
import 'package:backend/controllers/auth_controller.dart';
import 'package:backend/controllers/category_controller.dart';
import 'package:backend/controllers/keyword_controller.dart';
import 'package:backend/controllers/link_controller.dart';
import 'package:backend/controllers/manager_controller.dart';
import 'package:backend/controllers/status_controller.dart';
import 'package:backend/controllers/view_controller.dart';
import 'package:backend/db/database_connection_pool.dart';
import 'package:backend/middleware/auth_middleware.dart';
import 'package:backend/middleware/rate_limit_middleware.dart';
import 'package:backend/services/auth_service.dart';
import 'package:backend/services/category_service.dart';
import 'package:backend/services/encryption_service.dart';
import 'package:backend/services/keyword_service.dart';
import 'package:backend/services/link_manager_service.dart';
import 'package:backend/services/link_service.dart';
import 'package:backend/services/status_service.dart';
import 'package:backend/services/view_service.dart';
import 'package:shelf_router/shelf_router.dart';

class Api {
  final DatabaseConnectionPool _connectionPool;
  final AuthService _authService;

  // Controllers
  late final CategoryController _categoryController;
  late final KeywordController _keywordController;
  late final ViewController _viewController;
  late final StatusController _statusController;
  late final ManagerController _managerController;
  late final LinkController _linkController;
  late final AuthController _authController;
  late final AdminController _adminController;

  Api({
    required AuthService authService,
    required DatabaseConnectionPool connectionPool,
  })  : _connectionPool = connectionPool,
        _authService = authService {
    // Create middleware
    final authMiddleware = AuthMiddleware(_authService);
    final rateLimitMiddleware = RateLimitMiddleware(_authService);

    // Create services
    final categoryService = CategoryService(_connectionPool);
    final statusService = StatusService(_connectionPool);
    final keywordService = KeywordService(_connectionPool);
    final viewService = ViewService(_connectionPool);
    final managerService = LinkManagerService(_connectionPool);
    final linkService = LinkService(_connectionPool);
    final encryptionService = EncryptionService();

    // Initialize controllers
    _authController =
        AuthController(_authService, encryptionService, rateLimitMiddleware);
    _categoryController = CategoryController(categoryService, authMiddleware);
    _keywordController = KeywordController(keywordService, authMiddleware);
    _linkController = LinkController(linkService, authMiddleware);
    _managerController = ManagerController(managerService, authMiddleware);
    _statusController = StatusController(statusService, authMiddleware);
    _viewController = ViewController(viewService, authMiddleware);
    _adminController = AdminController(_connectionPool, authMiddleware);
  }

  Router get router {
    final router = Router();

    router.mount('/categories', _categoryController.router.call);
    router.mount('/keywords', _keywordController.router.call);
    router.mount('/statuses', _statusController.router.call);
    router.mount('/views', _viewController.router.call);
    router.mount('/managers', _managerController.router.call);
    router.mount('/links', _linkController.router.call);
    router.mount('/', _authController.router.call);
    router.mount('/admin', _adminController.router.call);

    return router;
  }
}
