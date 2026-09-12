import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskflow/core/api_client.dart';
import 'package:taskflow/core/api_exceptions.dart';
import 'package:taskflow/core/secure_storage.dart';

class InMemorySecureStorage extends SecureStorageService {
  String? _token;

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<void> deleteToken() async {
    _token = null;
  }

  @override
  Future<bool> hasToken() async => _token != null;
}

void main() {
  group('ApiClient Test Suite', () {
    test('Successful GET request returns decoded JSON', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/tasks');
        expect(request.headers['Authorization'], 'Bearer fake-jwt-token');
        return http.Response(
          jsonEncode([
            {'id': '1', 'title': 'Test Task'},
          ]),
          200,
        );
      });

      final storage = InMemorySecureStorage();
      await storage.saveToken('fake-jwt-token');

      final apiClient = ApiClient(
        baseUrl: 'http://test.local',
        client: mockClient,
        storage: storage,
      );

      final result = await apiClient.get('/tasks');
      expect(result, isA<List>());
      expect(result[0]['title'], 'Test Task');
    });

    test('400 Bad Request throws BadRequestException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Invalid ObjectId'}), 400);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://test.local',
        client: mockClient,
        storage: InMemorySecureStorage(),
      );

      expect(
        () => apiClient.get('/teams/bad-id'),
        throwsA(isA<BadRequestException>()),
      );
    });

    test(
      '401 Unauthorized triggers onUnauthorized callback and throws UnauthorizedException',
      () async {
        bool unauthorizedCalled = false;
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'detail': 'Could not validate credentials'}),
            401,
          );
        });

        final apiClient = ApiClient(
          baseUrl: 'http://test.local',
          client: mockClient,
          storage: InMemorySecureStorage(),
          onUnauthorized: () {
            unauthorizedCalled = true;
          },
        );

        expect(
          () => apiClient.get('/projects'),
          throwsA(isA<UnauthorizedException>()),
        );
        await Future.delayed(const Duration(milliseconds: 50));
        expect(unauthorizedCalled, isTrue);
      },
    );

    test('403 Forbidden throws ForbiddenException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Admin privileges required'}),
          403,
        );
      });

      final apiClient = ApiClient(
        baseUrl: 'http://test.local',
        client: mockClient,
        storage: InMemorySecureStorage(),
      );

      expect(
        () => apiClient.delete('/projects/123'),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('404 Not Found throws NotFoundException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'detail': 'Task not found'}), 404);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://test.local',
        client: mockClient,
        storage: InMemorySecureStorage(),
      );

      expect(
        () => apiClient.get('/tasks/nonexistent'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('422 Validation Error throws ValidationException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': 'Employees cannot modify project_id or assigned_to',
          }),
          422,
        );
      });

      final apiClient = ApiClient(
        baseUrl: 'http://test.local',
        client: mockClient,
        storage: InMemorySecureStorage(),
      );

      expect(
        () => apiClient.put('/tasks/123', body: {'project_id': '456'}),
        throwsA(isA<ValidationException>()),
      );
    });

    test('500 Server Error throws ServerException', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Error', 500);
      });

      final apiClient = ApiClient(
        baseUrl: 'http://test.local',
        client: mockClient,
        storage: InMemorySecureStorage(),
      );

      expect(() => apiClient.get('/health'), throwsA(isA<ServerException>()));
    });

    test('http.ClientException throws NetworkException', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection failed');
      });

      final apiClient = ApiClient(
        baseUrl: 'http://test.local',
        client: mockClient,
        storage: InMemorySecureStorage(),
      );

      expect(() => apiClient.get('/tasks'), throwsA(isA<NetworkException>()));
    });
  });
}
