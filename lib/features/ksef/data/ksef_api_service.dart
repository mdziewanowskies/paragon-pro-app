import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'models/ksef_models.dart';

class KsefApiService {
  final Dio _dio;
  final KsefEnvironment environment;
  KsefSessionToken? _session;

  KsefApiService({
    this.environment = KsefEnvironment.production,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 60);
  }

  String get _baseUrl => environment.baseUrl;

  bool get hasActiveSession =>
      _session != null && !_session!.isExpired;

  // ─── AUTH: Authorize with token ───────────────────────────────

  /// Initialize an interactive session using API token authorization.
  /// KSeF API v2: POST /online/Session/InitToken
  Future<KsefSessionToken> initSessionWithToken({
    required String nip,
    required String apiToken,
  }) async {
    debugPrint('=== KSeF: InitToken ===');
    debugPrint('NIP: $nip');
    debugPrint('Environment: ${environment.label}');

    // Step 1: Get challenge (validates NIP exists in KSeF)
    await _getAuthChallenge(nip);

    // Step 2: Init session with token
    final url = '$_baseUrl/online/Session/InitToken';

    final body = {
      'context': {
        'contextIdentifier': {
          'type': 'onip',
          'identifier': nip,
        },
      },
      'token': apiToken,
    };

    try {
      final response = await _dio.post(url, data: body);
      debugPrint('KSeF InitToken response: ${response.statusCode}');
      debugPrint('KSeF InitToken data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _session = KsefSessionToken.fromJson(
            response.data as Map<String, dynamic>);

        _dio.options.headers['SessionToken'] = _session!.sessionToken;

        debugPrint(
            'KSeF Session established. Ref: ${_session!.referenceNumber}');
        return _session!;
      }

      throw KsefApiException(
        'Nie udało się utworzyć sesji KSeF',
        statusCode: response.statusCode,
        details: response.data?.toString(),
      );
    } on DioException catch (e) {
      throw _handleDioError(e, 'InitToken');
    }
  }

  /// KSeF API v2: POST /online/Session/AuthorisationChallenge
  Future<Map<String, dynamic>> _getAuthChallenge(String nip) async {
    final url = '$_baseUrl/online/Session/AuthorisationChallenge';
    final body = {
      'contextIdentifier': {
        'type': 'onip',
        'identifier': nip,
      },
    };

    try {
      final response = await _dio.post(url, data: body);
      debugPrint('KSeF AuthChallenge: ${response.statusCode}');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e, 'AuthorisationChallenge');
    }
  }

  // ─── SESSION: Status & Terminate ──────────────────────────────

  /// KSeF API v2: GET /online/Session/Status
  Future<Map<String, dynamic>> getSessionStatus() async {
    _ensureSession();

    try {
      final response = await _dio.get(
        '$_baseUrl/online/Session/Status',
        options: Options(
          headers: {'SessionToken': _session!.sessionToken},
        ),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e, 'SessionStatus');
    }
  }

  /// KSeF API v2: GET /online/Session/Terminate
  Future<void> terminateSession() async {
    if (_session == null) return;

    try {
      await _dio.get(
        '$_baseUrl/online/Session/Terminate',
        options: Options(
          headers: {'SessionToken': _session!.sessionToken},
        ),
      );
      debugPrint('KSeF Session terminated');
    } catch (e) {
      debugPrint('KSeF terminate error (non-critical): $e');
    } finally {
      _session = null;
      _dio.options.headers.remove('SessionToken');
    }
  }

  // ─── INVOICES: Query ──────────────────────────────────────────

  /// KSeF API v2: POST /online/Query/Invoice/Sync
  /// Synchronous query - returns results immediately (max 100 invoices)
  Future<List<KsefInvoice>> queryInvoicesSync({
    required KsefQueryCriteria criteria,
    int pageSize = 100,
    int pageOffset = 0,
  }) async {
    _ensureSession();

    final url = '$_baseUrl/online/Query/Invoice/Sync?PageSize=$pageSize&PageOffset=$pageOffset';

    try {
      final response = await _dio.post(
        url,
        data: criteria.toQueryBody(),
        options: Options(
          headers: {'SessionToken': _session!.sessionToken},
        ),
      );

      debugPrint('KSeF QuerySync response: ${response.statusCode}');

      final data = response.data as Map<String, dynamic>;
      final invoiceHeaderList =
          data['invoiceHeaderList'] as List<dynamic>? ?? [];

      debugPrint('KSeF QuerySync found ${invoiceHeaderList.length} invoices');

      return invoiceHeaderList
          .map((e) =>
              KsefInvoice.fromQueryResponse(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e, 'QueryInvoiceSync');
    }
  }

  /// KSeF API v2: POST /online/Query/Invoice/Async/Init
  /// Asynchronous query - for large datasets
  Future<String> queryInvoicesAsyncInit({
    required KsefQueryCriteria criteria,
  }) async {
    _ensureSession();

    final url = '$_baseUrl/online/Query/Invoice/Async/Init';

    try {
      final response = await _dio.post(
        url,
        data: criteria.toQueryBody(),
        options: Options(
          headers: {'SessionToken': _session!.sessionToken},
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final queryId =
          data['elementReferenceNumber'] as String? ??
              data['queryElementReferenceNumber'] as String? ??
              '';

      debugPrint('KSeF AsyncQuery initiated. QueryID: $queryId');
      return queryId;
    } on DioException catch (e) {
      throw _handleDioError(e, 'QueryInvoiceAsyncInit');
    }
  }

  /// KSeF API v2: GET /online/Query/Invoice/Async/Status/{QueryElementReferenceNumber}
  Future<Map<String, dynamic>> queryInvoicesAsyncStatus(
      String queryId) async {
    _ensureSession();

    try {
      final response = await _dio.get(
        '$_baseUrl/online/Query/Invoice/Async/Status/$queryId',
        options: Options(
          headers: {'SessionToken': _session!.sessionToken},
        ),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e, 'QueryInvoiceAsyncStatus');
    }
  }

  /// KSeF API v2: GET /online/Query/Invoice/Async/Fetch/{QueryElementReferenceNumber}
  Future<List<KsefInvoice>> queryInvoicesAsyncFetch(
      String queryId,
      {int pageSize = 100,
      int pageOffset = 0}) async {
    _ensureSession();

    try {
      final response = await _dio.get(
        '$_baseUrl/online/Query/Invoice/Async/Fetch/$queryId?PageSize=$pageSize&PageOffset=$pageOffset',
        options: Options(
          headers: {'SessionToken': _session!.sessionToken},
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final invoiceHeaderList =
          data['invoiceHeaderList'] as List<dynamic>? ?? [];

      return invoiceHeaderList
          .map((e) =>
              KsefInvoice.fromQueryResponse(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _handleDioError(e, 'QueryInvoiceAsyncFetch');
    }
  }

  // ─── INVOICES: Download ───────────────────────────────────────

  /// KSeF API v2: GET /online/Invoice/Get/{KsefReferenceNumber}
  /// Downloads full invoice XML
  Future<String> downloadInvoice(String ksefReferenceNumber) async {
    _ensureSession();

    try {
      final response = await _dio.get(
        '$_baseUrl/online/Invoice/Get/$ksefReferenceNumber',
        options: Options(
          headers: {
            'SessionToken': _session!.sessionToken,
            'Accept': 'application/octet-stream',
          },
          responseType: ResponseType.plain,
        ),
      );

      return response.data as String;
    } on DioException catch (e) {
      throw _handleDioError(e, 'DownloadInvoice');
    }
  }

  // ─── COMMON: UPO (Receipt confirmation) ───────────────────────

  /// KSeF API v2: GET /common/Invoice/{KsefReferenceNumber}/Status
  Future<Map<String, dynamic>> getInvoiceStatus(
      String ksefReferenceNumber) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/common/Invoice/$ksefReferenceNumber/Status',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleDioError(e, 'InvoiceStatus');
    }
  }

  // ─── HELPERS ──────────────────────────────────────────────────

  void _ensureSession() {
    if (_session == null) {
      throw KsefApiException('Brak aktywnej sesji KSeF. Zaloguj się ponownie.');
    }
    if (_session!.isExpired) {
      _session = null;
      _dio.options.headers.remove('SessionToken');
      throw KsefApiException('Sesja KSeF wygasła. Zaloguj się ponownie.');
    }
  }

  KsefApiException _handleDioError(DioException e, String operation) {
    debugPrint('=== KSeF DioError: $operation ===');
    debugPrint('Status: ${e.response?.statusCode}');
    debugPrint('Data: ${e.response?.data}');
    debugPrint('Message: ${e.message}');

    final statusCode = e.response?.statusCode;
    final responseData = e.response?.data;

    String message;
    String? details;

    if (responseData is Map) {
      final exception = responseData['exception'] as Map<String, dynamic>?;
      message = exception?['exceptionDetailList']
              ?.first?['exceptionDescription'] as String? ??
          exception?['serviceCode'] as String? ??
          'Błąd komunikacji z KSeF';
      details = responseData.toString();
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Przekroczono czas oczekiwania na odpowiedź KSeF';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'Brak połączenia z serwerem KSeF';
    } else {
      message = 'Błąd komunikacji z KSeF ($operation)';
      details = e.message;
    }

    return KsefApiException(
      message,
      statusCode: statusCode,
      details: details,
    );
  }
}

class KsefApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? details;

  KsefApiException(this.message, {this.statusCode, this.details});

  @override
  String toString() => message;
}
