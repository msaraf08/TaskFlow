import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'api_exceptions.dart';
import 'secure_storage.dart';

class ApiClient {
  final String baseUrl;
  final http.Client _client;
  final SecureStorageService _storage;
  void Function()? onUnauthorized;

  ApiClient({
    String? baseUrl,
    http.Client? client,
    SecureStorageService? storage,
    this.onUnauthorized,
  }) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
       _client = client ?? http.Client(),
       _storage = storage ?? SecureStorageService();

  Future<Map<String, String>> _headers({bool requiresAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await _storage.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? queryParams,
    bool requiresAuth = true,
  }) async {
    final params = queryParams ?? queryParameters;
    final uri = _buildUri(path, params);
    try {
      final headers = await _headers(requiresAuth: requiresAuth);
      final response = await _client
          .get(uri, headers: headers)
          .timeout(AppConfig.requestTimeout);
      return _handleResponse(response);
    } on SocketException {
      throw NetworkException();
    } on TimeoutException {
      throw TimeoutException();
    }
  }

  Future<dynamic> post(
    String path, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    final uri = _buildUri(path);
    try {
      final headers = await _headers(requiresAuth: requiresAuth);
      final response = await _client
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.requestTimeout);
      return _handleResponse(response);
    } on SocketException {
      throw NetworkException();
    } on TimeoutException {
      throw TimeoutException();
    }
  }

  Future<dynamic> put(
    String path, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    final uri = _buildUri(path);
    try {
      final headers = await _headers(requiresAuth: requiresAuth);
      final response = await _client
          .put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(AppConfig.requestTimeout);
      return _handleResponse(response);
    } on SocketException {
      throw NetworkException();
    } on TimeoutException {
      throw TimeoutException();
    }
  }

  Future<dynamic> delete(String path, {bool requiresAuth = true}) async {
    final uri = _buildUri(path);
    try {
      final headers = await _headers(requiresAuth: requiresAuth);
      final response = await _client
          .delete(uri, headers: headers)
          .timeout(AppConfig.requestTimeout);
      return _handleResponse(response);
    } on SocketException {
      throw NetworkException();
    } on TimeoutException {
      throw TimeoutException();
    }
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$normalizedBase$normalizedPath';

    final uri = Uri.parse(fullUrl);
    if (queryParams == null || queryParams.isEmpty) {
      return uri;
    }

    final cleanParams = <String, String>{};
    queryParams.forEach((key, value) {
      if (value != null) {
        cleanParams[key] = value.toString();
      }
    });

    return uri.replace(queryParameters: cleanParams);
  }

  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;

    if (statusCode == 204) {
      return null;
    }

    dynamic decodedBody;
    try {
      if (response.body.isNotEmpty) {
        decodedBody = jsonDecode(response.body);
      }
    } catch (_) {
      decodedBody = null;
    }

    final detail = (decodedBody is Map && decodedBody['detail'] != null)
        ? (decodedBody['detail'] is String
              ? decodedBody['detail']
              : decodedBody['detail'].toString())
        : (decodedBody is Map && decodedBody['message'] != null)
        ? decodedBody['message'].toString()
        : 'Request failed with status $statusCode';

    if (statusCode >= 200 && statusCode < 300) {
      return decodedBody;
    }

    if (statusCode == 400) {
      throw BadRequestException(detail);
    } else if (statusCode == 401) {
      onUnauthorized?.call();
      throw UnauthorizedException(detail);
    } else if (statusCode == 403) {
      throw ForbiddenException(detail);
    } else if (statusCode == 404) {
      throw NotFoundException(detail);
    } else if (statusCode == 409) {
      throw ConflictException(detail);
    } else if (statusCode == 422) {
      throw ValidationException(
        detail,
        errors: decodedBody is Map ? decodedBody.cast<String, dynamic>() : null,
      );
    } else if (statusCode == 429) {
      final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
      throw RateLimitException(
        'Too many requests. Please wait a moment.',
        retryAfterSeconds: retryAfter,
      );
    } else if (statusCode >= 500) {
      throw ServerException(
        'Server error ($statusCode). Please try again later.',
      );
    } else {
      throw ApiException(detail, statusCode: statusCode);
    }
  }
}
