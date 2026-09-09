class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class BadRequestException extends ApiException {
  BadRequestException(super.message) : super(statusCode: 400);
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([
    super.message = 'Your session has expired. Please log in again.',
  ]) : super(statusCode: 401);
}

class ForbiddenException extends ApiException {
  ForbiddenException([
    super.message = "You don't have permission to perform this action.",
  ]) : super(statusCode: 403);
}

class NotFoundException extends ApiException {
  NotFoundException([super.message = 'The requested resource was not found.'])
    : super(statusCode: 404);
}

class ConflictException extends ApiException {
  ConflictException(super.message) : super(statusCode: 409);
}

class ValidationException extends ApiException {
  final Map<String, dynamic>? errors;
  ValidationException(super.message, {this.errors}) : super(statusCode: 422);
}

class RateLimitException extends ApiException {
  final int? retryAfterSeconds;
  RateLimitException(super.message, {this.retryAfterSeconds})
    : super(statusCode: 429);
}

class ServerException extends ApiException {
  ServerException([
    super.message = 'Something went wrong. Please try again later.',
  ]) : super(statusCode: 500);
}

class NetworkException extends ApiException {
  NetworkException([
    super.message = 'No internet connection. Please check your connection.',
  ]);
}

class TimeoutException extends ApiException {
  TimeoutException([super.message = 'Request timed out. Please try again.']);
}
