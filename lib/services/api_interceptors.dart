import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Dio 拦截器 - 统一处理请求/响应/错误
class ApiInterceptor extends Interceptor {
  final String? Function() getToken;
  final VoidCallback? onUnauthorized;

  ApiInterceptor({
    required this.getToken,
    this.onUnauthorized,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 添加 token
    final token = getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // 添加通用请求头
    options.headers['Accept'] = 'application/json';
    options.headers['Content-Type'] = 'application/json';

    if (kDebugMode) {
      print('🌐 API Request: ${options.method} ${options.uri}');
      if (options.data != null) {
        print('📤 Request Data: ${options.data}');
      }
    }

    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      print('✅ API Response: ${response.statusCode} ${response.requestOptions.uri}');
      print('📥 Response Data: ${response.data}');
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      print('❌ API Error: ${err.message}');
      print('🔍 Error Type: ${err.type}');
      if (err.response != null) {
        print('📛 Status Code: ${err.response?.statusCode}');
        print('📛 Error Data: ${err.response?.data}');
      }
    }

    // 处理 401 未授权
    if (err.response?.statusCode == 401) {
      onUnauthorized?.call();
    }

    super.onError(err, handler);
  }
}

/// Loading 拦截器 - 显示/隐藏加载状态
class LoadingInterceptor extends Interceptor {
  final void Function() onShowLoading;
  final void Function() onHideLoading;

  LoadingInterceptor({
    required this.onShowLoading,
    required this.onHideLoading,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 检查是否需要显示 loading（可通过 extra 参数控制）
    final showLoading = options.extra['showLoading'] as bool? ?? true;
    if (showLoading) {
      onShowLoading();
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    onHideLoading();
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    onHideLoading();
    super.onError(err, handler);
  }
}

/// API 异常类
class ApiException implements Exception {
  final String message;
  final int? code;
  final dynamic data;

  ApiException({
    required this.message,
    this.code,
    this.data,
  });

  @override
  String toString() => message;

  /// 从 DioException 转换
  factory ApiException.fromDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: '网络连接超时，请检查网络设置',
          code: -1,
        );
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;

        if (statusCode == 401) {
          return ApiException(
            message: '登录已过期，请重新登录',
            code: statusCode,
          );
        } else if (statusCode == 403) {
          return ApiException(
            message: '没有权限访问',
            code: statusCode,
          );
        } else if (statusCode == 404) {
          return ApiException(
            message: '请求的资源不存在',
            code: statusCode,
          );
        } else if (statusCode == 500) {
          return ApiException(
            message: '服务器错误，请稍后重试',
            code: statusCode,
          );
        }

        // 尝试从响应中提取错误信息
        String message = '请求失败';
        if (data is Map && data['message'] != null) {
          message = data['message'] as String;
        }

        return ApiException(
          message: message,
          code: statusCode,
          data: data,
        );
      case DioExceptionType.cancel:
        return ApiException(
          message: '请求已取消',
          code: -2,
        );
      case DioExceptionType.unknown:
        if (error.error.toString().contains('SocketException')) {
          return ApiException(
            message: '网络连接失败，请检查网络设置',
            code: -3,
          );
        }
        return ApiException(
          message: '未知错误：${error.message}',
          code: -4,
        );
      default:
        return ApiException(
          message: error.message ?? '请求失败',
          code: -5,
        );
    }
  }
}
