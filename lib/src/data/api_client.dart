// dart
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef ToastHandler =
    void Function(
      String message, {
      String? actionLabel,
      Future<void> Function()? onAction,
    });

String _defaultBaseUrl() {
  final defined = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  if (defined.isNotEmpty) return defined;
  if (kIsWeb) return 'http://localhost:80001';
  if (Platform.isAndroid) return 'http://192.168.31.106:8000';
  return 'http://localhost:8000';
}

class ApiClient {
  final Dio dio;
  final ToastHandler? toast;
  final int _maxRetries;

  ApiClient._(this.dio, this.toast, this._maxRetries);

  factory ApiClient.auto({ToastHandler? toastHandler, int maxRetries = 2}) {
    final dio = Dio(BaseOptions(baseUrl: _defaultBaseUrl()));
    final client = ApiClient._(dio, toastHandler, maxRetries);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opts, handler) async {
          // notify UI that a request started (optional)
          client.toast?.call('Request started');
          final token = await FirebaseAuth.instance.currentUser?.getIdToken();
          if (token != null) opts.headers['Authorization'] = 'Bearer $token';
          return handler.next(opts);
        },
        onError: (e, handler) async {
          // handle 401 token refresh first
          if (e.response?.statusCode == 401) {
            final fresh = await FirebaseAuth.instance.currentUser?.getIdToken(
              true,
            );
            if (fresh != null) {
              e.requestOptions.headers['Authorization'] = 'Bearer $fresh';
              try {
                final clone = await dio.fetch(e.requestOptions);
                client.toast?.call('Session refreshed');
                return handler.resolve(clone);
              } catch (_) {
                // fall through to show error / retry below
              }
            }
          }

          // network / connectivity errors - attempt automatic retries
          final dioError = e is DioExceptionType ? e : null;
          final isNetworkError =
              dioError != null &&
              (dioError.type == DioExceptionType.unknown ||
                  dioError.type == DioExceptionType.connectionTimeout ||
                  dioError.type == DioExceptionType.receiveTimeout);

          if (isNetworkError) {
            for (int attempt = 0; attempt < client._maxRetries; attempt++) {
              final backoffMs = 300 * (1 << attempt);
              await Future.delayed(Duration(milliseconds: backoffMs));
              try {
                final resp = await dio.fetch(e.requestOptions);
                client.toast?.call('Retry succeeded');
                return handler.resolve(resp);
              } catch (_) {
                // continue retrying
              }
            }

            // automatic retries exhausted -> show toast with manual retry action
            client.toast?.call(
              'Request failed',
              actionLabel: 'Retry',
              onAction: () async {
                client.toast?.call('Retrying...');
                try {
                  final resp = await dio.fetch(e.requestOptions);
                  client.toast?.call('Retry succeeded');
                  // Note: original caller already received the error; this manual retry
                  // is a separate request the UI can react to.
                  return;
                } catch (_) {
                  client.toast?.call('Retry failed');
                }
              },
            );
          }

          if (e.type == DioExceptionType.badResponse) {
            final statusCode = e.response?.statusCode ?? 0;

            String msg;
            if (statusCode == 404) {
              msg = 'Endpoint not found (404)';
            } else if (statusCode == 500 || statusCode == 503) {
              msg = 'Server is currently down. Please try again later.';
            } else {
              msg = 'Unexpected server error (code: $statusCode)';
            }

            client.toast?.call(
              msg,
              actionLabel: 'Retry',
              onAction: () async {
                client.toast?.call('Retrying...');
                try {
                  final resp = await dio.fetch(e.requestOptions);
                  client.toast?.call('Retry succeeded');
                } catch (_) {
                  client.toast?.call('Retry failed');
                }
              },
            );
          }

          return handler.next(e);
        },
      ),
    );

    return client;
  }

  // Helper if UI wants to programmatically retry using stored RequestOptions
  Future<Response> retry(RequestOptions options) => dio.fetch(options);
}
