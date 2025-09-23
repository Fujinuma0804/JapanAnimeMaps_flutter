import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Error types for different map operations
enum MapErrorType {
  locationPermission,
  locationService,
  networkConnection,
  firebaseAuth,
  firestore,
  imageLoading,
  routeCalculation,
  markerCreation,
  checkIn,
  search,
  unknown
}

/// Error severity levels
enum MapErrorSeverity {
  low, // Non-critical, can continue operation
  medium, // Affects some functionality but app can continue
  high, // Critical error, requires user action
  fatal // App cannot continue
}

/// Error information container
class MapError {
  final MapErrorType type;
  final MapErrorSeverity severity;
  final String message;
  final String? userMessage;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  final Map<String, dynamic>? context;

  MapError({
    required this.type,
    required this.severity,
    required this.message,
    this.userMessage,
    this.originalError,
    this.stackTrace,
    DateTime? timestamp,
    this.context,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'MapError(type: $type, severity: $severity, message: $message, timestamp: $timestamp)';
  }
}

/// Comprehensive error handling utility for map operations
class MapErrorHandler {
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  /// Handle location-related errors
  static MapError handleLocationError(dynamic error,
      {Map<String, dynamic>? context}) {
    if (error is LocationServiceDisabledException) {
      return MapError(
        type: MapErrorType.locationService,
        severity: MapErrorSeverity.high,
        message: 'Location services are disabled',
        userMessage: '位置情報サービスが無効です。設定で有効にしてください。',
        originalError: error,
        context: context,
      );
    } else if (error is PermissionDeniedException) {
      return MapError(
        type: MapErrorType.locationPermission,
        severity: MapErrorSeverity.high,
        message: 'Location permission denied',
        userMessage: '位置情報の許可が必要です。設定で許可してください。',
        originalError: error,
        context: context,
      );
    } else if (error.toString().contains('deniedForever') ||
        error.toString().contains('permanently denied')) {
      return MapError(
        type: MapErrorType.locationPermission,
        severity: MapErrorSeverity.fatal,
        message: 'Location permission permanently denied',
        userMessage: '位置情報が永久に拒否されました。設定から手動で許可してください。',
        originalError: error,
        context: context,
      );
    } else if (error is TimeoutException) {
      return MapError(
        type: MapErrorType.locationService,
        severity: MapErrorSeverity.medium,
        message: 'Location request timeout',
        userMessage: '位置情報の取得に時間がかかっています。しばらく待ってから再試行してください。',
        originalError: error,
        context: context,
      );
    } else {
      return MapError(
        type: MapErrorType.locationService,
        severity: MapErrorSeverity.medium,
        message: 'Unknown location error: ${error.toString()}',
        userMessage: '位置情報の取得中にエラーが発生しました。',
        originalError: error,
        context: context,
      );
    }
  }

  /// Handle Firebase-related errors
  static MapError handleFirebaseError(dynamic error,
      {Map<String, dynamic>? context}) {
    if (error is FirebaseAuthException) {
      return MapError(
        type: MapErrorType.firebaseAuth,
        severity: MapErrorSeverity.high,
        message: 'Firebase Auth error: ${error.code} - ${error.message}',
        userMessage: _getFirebaseAuthUserMessage(error.code),
        originalError: error,
        context: context,
      );
    } else if (error is FirebaseException) {
      return MapError(
        type: MapErrorType.firestore,
        severity: MapErrorSeverity.medium,
        message: 'Firebase error: ${error.code} - ${error.message}',
        userMessage: _getFirebaseUserMessage(error.code),
        originalError: error,
        context: context,
      );
    } else {
      return MapError(
        type: MapErrorType.firestore,
        severity: MapErrorSeverity.medium,
        message: 'Unknown Firebase error: ${error.toString()}',
        userMessage: 'データの取得中にエラーが発生しました。',
        originalError: error,
        context: context,
      );
    }
  }

  /// Handle network-related errors
  static MapError handleNetworkError(dynamic error,
      {Map<String, dynamic>? context}) {
    if (error is SocketException) {
      return MapError(
        type: MapErrorType.networkConnection,
        severity: MapErrorSeverity.high,
        message: 'Network connection error: ${error.message}',
        userMessage: 'インターネット接続を確認してください。',
        originalError: error,
        context: context,
      );
    } else if (error is TimeoutException) {
      return MapError(
        type: MapErrorType.networkConnection,
        severity: MapErrorSeverity.medium,
        message: 'Network timeout: ${error.message}',
        userMessage: 'ネットワーク接続がタイムアウトしました。再試行してください。',
        originalError: error,
        context: context,
      );
    } else if (error is http.ClientException) {
      return MapError(
        type: MapErrorType.networkConnection,
        severity: MapErrorSeverity.medium,
        message: 'HTTP client error: ${error.message}',
        userMessage: 'ネットワークエラーが発生しました。',
        originalError: error,
        context: context,
      );
    } else {
      return MapError(
        type: MapErrorType.networkConnection,
        severity: MapErrorSeverity.medium,
        message: 'Unknown network error: ${error.toString()}',
        userMessage: 'ネットワークエラーが発生しました。',
        originalError: error,
        context: context,
      );
    }
  }

  /// Handle image loading errors
  static MapError handleImageError(dynamic error,
      {Map<String, dynamic>? context}) {
    return MapError(
      type: MapErrorType.imageLoading,
      severity: MapErrorSeverity.low,
      message: 'Image loading error: ${error.toString()}',
      userMessage: '画像の読み込みに失敗しました。',
      originalError: error,
      context: context,
    );
  }

  /// Handle route calculation errors
  static MapError handleRouteError(dynamic error,
      {Map<String, dynamic>? context}) {
    if (error is TimeoutException) {
      return MapError(
        type: MapErrorType.routeCalculation,
        severity: MapErrorSeverity.medium,
        message: 'Route calculation timeout',
        userMessage: 'ルート計算に時間がかかっています。',
        originalError: error,
        context: context,
      );
    } else {
      return MapError(
        type: MapErrorType.routeCalculation,
        severity: MapErrorSeverity.medium,
        message: 'Route calculation error: ${error.toString()}',
        userMessage: 'ルートの計算中にエラーが発生しました。',
        originalError: error,
        context: context,
      );
    }
  }

  /// Generic error handler that determines error type automatically
  static MapError handleError(dynamic error, {Map<String, dynamic>? context}) {
    if (error is LocationServiceDisabledException ||
        error is PermissionDeniedException ||
        (error.toString().contains('deniedForever') ||
            error.toString().contains('permanently denied')) ||
        error is TimeoutException && context?['operation'] == 'location') {
      return handleLocationError(error, context: context);
    } else if (error is FirebaseAuthException || error is FirebaseException) {
      return handleFirebaseError(error, context: context);
    } else if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return handleNetworkError(error, context: context);
    } else if (context?['operation'] == 'image') {
      return handleImageError(error, context: context);
    } else if (context?['operation'] == 'route') {
      return handleRouteError(error, context: context);
    } else {
      return MapError(
        type: MapErrorType.unknown,
        severity: MapErrorSeverity.medium,
        message: 'Unknown error: ${error.toString()}',
        userMessage: '予期しないエラーが発生しました。',
        originalError: error,
        context: context,
      );
    }
  }

  /// Execute operation with retry logic and error handling
  static Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = _maxRetries,
    Duration retryDelay = _retryDelay,
    Duration timeout = _defaultTimeout,
    Map<String, dynamic>? context,
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempts = 0;
    dynamic lastError;

    while (attempts <= maxRetries) {
      try {
        return await operation().timeout(timeout);
      } catch (error) {
        lastError = error;
        attempts++;

        // Check if we should retry this error
        if (attempts <= maxRetries &&
            (shouldRetry?.call(error) ?? _shouldRetryError(error))) {
          await Future.delayed(retryDelay * attempts); // Exponential backoff
          continue;
        } else {
          break;
        }
      }
    }

    // If we get here, all retries failed
    throw handleError(lastError, context: context);
  }

  /// Execute operation with timeout and error handling
  static Future<T> executeWithTimeout<T>(
    Future<T> Function() operation, {
    Duration timeout = _defaultTimeout,
    Map<String, dynamic>? context,
  }) async {
    try {
      return await operation().timeout(timeout);
    } catch (error) {
      throw handleError(error, context: context);
    }
  }

  /// Show error dialog to user
  static void showErrorDialog(BuildContext context, MapError error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_getErrorTitle(error.severity)),
          content: Text(error.userMessage ?? error.message),
          actions: [
            if (error.severity == MapErrorSeverity.high ||
                error.severity == MapErrorSeverity.fatal)
              TextButton(
                onPressed: () => _handleErrorAction(context, error),
                child: Text(_getErrorActionText(error.type)),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show error snackbar
  static void showErrorSnackbar(BuildContext context, MapError error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.userMessage ?? error.message),
        backgroundColor: _getErrorColor(error.severity),
        duration: Duration(
            seconds: error.severity == MapErrorSeverity.fatal ? 10 : 4),
        action: error.severity == MapErrorSeverity.high ||
                error.severity == MapErrorSeverity.fatal
            ? SnackBarAction(
                label: '設定',
                textColor: Colors.white,
                onPressed: () => _handleErrorAction(context, error),
              )
            : null,
      ),
    );
  }

  /// Log error for debugging
  static void logError(MapError error) {
    print('🚨 MapError: ${error.toString()}');
    if (error.originalError != null) {
      print('Original error: ${error.originalError}');
    }
    if (error.stackTrace != null) {
      print('Stack trace: ${error.stackTrace}');
    }
    if (error.context != null) {
      print('Context: ${error.context}');
    }
  }

  // Private helper methods

  static bool _shouldRetryError(dynamic error) {
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    if (error is http.ClientException) return true;
    if (error is FirebaseException) {
      // Retry on certain Firebase error codes
      return ['unavailable', 'deadline-exceeded', 'resource-exhausted']
          .contains(error.code);
    }
    return false;
  }

  static String _getFirebaseAuthUserMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'ユーザーが見つかりません。';
      case 'wrong-password':
        return 'パスワードが間違っています。';
      case 'email-already-in-use':
        return 'このメールアドレスは既に使用されています。';
      case 'weak-password':
        return 'パスワードが弱すぎます。';
      case 'invalid-email':
        return '無効なメールアドレスです。';
      case 'user-disabled':
        return 'このアカウントは無効化されています。';
      case 'too-many-requests':
        return 'リクエストが多すぎます。しばらく待ってから再試行してください。';
      case 'network-request-failed':
        return 'ネットワークエラーが発生しました。';
      default:
        return '認証エラーが発生しました。';
    }
  }

  static String _getFirebaseUserMessage(String code) {
    switch (code) {
      case 'permission-denied':
        return 'アクセス権限がありません。';
      case 'unavailable':
        return 'サービスが一時的に利用できません。';
      case 'deadline-exceeded':
        return 'リクエストがタイムアウトしました。';
      case 'resource-exhausted':
        return 'リソースが不足しています。';
      case 'failed-precondition':
        return '操作の前提条件が満たされていません。';
      case 'aborted':
        return '操作が中断されました。';
      case 'out-of-range':
        return '範囲外の値が指定されました。';
      case 'unimplemented':
        return 'この機能は実装されていません。';
      case 'internal':
        return '内部エラーが発生しました。';
      case 'data-loss':
        return 'データが失われました。';
      default:
        return 'データベースエラーが発生しました。';
    }
  }

  static String _getErrorTitle(MapErrorSeverity severity) {
    switch (severity) {
      case MapErrorSeverity.low:
        return '情報';
      case MapErrorSeverity.medium:
        return '注意';
      case MapErrorSeverity.high:
        return 'エラー';
      case MapErrorSeverity.fatal:
        return '重大なエラー';
    }
  }

  static Color _getErrorColor(MapErrorSeverity severity) {
    switch (severity) {
      case MapErrorSeverity.low:
        return Colors.blue;
      case MapErrorSeverity.medium:
        return Colors.orange;
      case MapErrorSeverity.high:
        return Colors.red;
      case MapErrorSeverity.fatal:
        return Colors.red.shade900;
    }
  }

  static String _getErrorActionText(MapErrorType type) {
    switch (type) {
      case MapErrorType.locationPermission:
      case MapErrorType.locationService:
        return '設定を開く';
      case MapErrorType.networkConnection:
        return '再接続';
      case MapErrorType.firebaseAuth:
        return '再ログイン';
      default:
        return '再試行';
    }
  }

  static void _handleErrorAction(BuildContext context, MapError error) {
    Navigator.of(context).pop(); // Close dialog first

    switch (error.type) {
      case MapErrorType.locationPermission:
      case MapErrorType.locationService:
        // Open app settings
        // Note: You might need to add a package like app_settings for this
        break;
      case MapErrorType.networkConnection:
        // Could trigger a network check or refresh
        break;
      case MapErrorType.firebaseAuth:
        // Could trigger re-authentication
        break;
      default:
        // Default action
        break;
    }
  }
}
