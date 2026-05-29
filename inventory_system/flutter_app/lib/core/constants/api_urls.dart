class ApiUrls {
  static String _baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://devanshsavla17-inventory-backend.hf.space',
  );
  static String _wsBaseUrl = const String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://devanshsavla17-inventory-backend.hf.space',
  );

  static String get baseUrl => _baseUrl;
  static String get wsBaseUrl => _wsBaseUrl;

  static void setBaseUrl(String url) {
    var formatted = url.trim();
    if (formatted.endsWith('/')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    if (formatted.startsWith('https://')) {
      _baseUrl = formatted;
      _wsBaseUrl = formatted.replaceFirst('https://', 'wss://');
    } else if (formatted.startsWith('http://')) {
      _baseUrl = formatted;
      _wsBaseUrl = formatted.replaceFirst('http://', 'ws://');
    } else {
      _baseUrl = 'http://$formatted';
      _wsBaseUrl = 'ws://$formatted';
    }
  }

  static const String signupPublic = '/api/public/signup/';
  static const String resolveTenant = '/api/public/resolve-tenant/';
  static const String loginPublic = '/api/public/login/';
  
  static const String login = '/api/auth/login/';
  static const String refresh = '/api/auth/refresh/';
  static const String logout = '/api/auth/logout/';
  static const String me = '/api/auth/me/';
  static const String users = '/api/users/';

  static const String products = '/api/products/';
  static const String variants = '/api/variants/';
  static const String variantMatrix = '/api/variants/matrix/';
  static const String variantBulkImport = '/api/variants/bulk-import/';

  static const String stockIncoming = '/api/stock/incoming/';
  static const String stockOutgoing = '/api/stock/outgoing/';
  static const String stockEntries = '/api/stock/entries/';
  static const String stockLive = '/api/stock/live/';
  static const String transfers = '/api/transfers/';
  static const String orders = '/api/orders/';

  static const String suppliers = '/api/suppliers/';
  static const String purchaseOrders = '/api/purchase-orders/';

  static const String locations = '/api/locations/';

  static const String reportDaily = '/api/reports/daily/';
  static const String reportWeekly = '/api/reports/weekly/';
  static const String reportMonthly = '/api/reports/monthly/';
  static const String reportMovement = '/api/reports/movement/';
  static const String reportLowStock = '/api/reports/low-stock/';
  static const String reportExpiring = '/api/reports/expiring/';
  static const String reportExport = '/api/reports/export/';

  static const String dashboardSummary = '/api/dashboard/summary/';
  static const String notifications = '/api/notifications/';

  static const String wsStock = '/ws/stock/';

  static String stockApprove(int id) => '/api/stock/entries/$id/approve/';
  static String stockLiveVariant(int id) => '/api/stock/live/$id/';
  static String productDetail(int id) => '/api/products/$id/';
  static String variantDetail(int id) => '/api/variants/$id/';
  static String supplierDetail(int id) => '/api/suppliers/$id/';
  static String poDetail(int id) => '/api/purchase-orders/$id/';
  static String poReceive(int id) => '/api/purchase-orders/$id/receive/';
  static String userDetail(int id) => '/api/users/$id/';
  static String reportForecast(int variantId) => '/api/reports/forecast/$variantId/';
  static String notificationRead(int id) => '/api/notifications/$id/read/';
  static const String notificationReadAll = '/api/notifications/read-all/';
  static const String productSearch = '/api/products/search/';
}
