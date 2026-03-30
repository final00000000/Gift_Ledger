import 'package:dio/dio.dart';
import '../models/api_response.dart';
import 'api_interceptors.dart';

/// HTTP 请求客户端封装
/// 负责统一处理请求和响应的封装/解封装
class HttpClient {
  final Dio _dio;

  HttpClient(this._dio);

  /// GET 请求 - 返回单个对象
  Future<T> get<T>({
    required String path,
    Map<String, dynamic>? queryParameters,
    required T Function(Map<String, dynamic>) fromJson,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );

      return _handleResponse<T>(response, fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// GET 请求 - 返回列表
  Future<List<T>> getList<T>({
    required String path,
    Map<String, dynamic>? queryParameters,
    required T Function(Map<String, dynamic>) fromJson,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );

      return _handleListResponse<T>(response, fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// GET 请求 - 返回分页数据
  Future<PagedResponse<T>> getPaged<T>({
    required String path,
    Map<String, dynamic>? queryParameters,
    required T Function(Map<String, dynamic>) fromJson,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );

      return _handlePagedResponse<T>(response, fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// POST 请求 - 返回单个对象
  Future<T> post<T>({
    required String path,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    required T Function(Map<String, dynamic>) fromJson,
    Options? options,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

      return _handleResponse<T>(response, fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// POST 请求 - 无返回数据
  Future<void> postVoid({
    required String path,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

      _validateResponse(response);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// PUT 请求 - 返回单个对象
  Future<T> put<T>({
    required String path,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    required T Function(Map<String, dynamic>) fromJson,
    Options? options,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );

      return _handleResponse<T>(response, fromJson);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// DELETE 请求 - 无返回数据
  Future<void> delete({
    required String path,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        queryParameters: queryParameters,
        options: options,
      );

      _validateResponse(response);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// 处理单个对象响应
  T _handleResponse<T>(
    Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    try {
      final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data as Map<String, dynamic>,
      );

      if (!apiResponse.isSuccess) {
        throw ApiException(
          message: apiResponse.message,
          code: apiResponse.code,
        );
      }

      if (apiResponse.data == null) {
        throw ApiException(
          message: '响应数据为空',
          code: apiResponse.code,
        );
      }

      return fromJson(apiResponse.data!);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: '数据解析失败: $e',
        code: -100,
      );
    }
  }

  /// 处理列表响应
  List<T> _handleListResponse<T>(
    Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    try {
      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data as List<dynamic>,
      );

      if (!apiResponse.isSuccess) {
        throw ApiException(
          message: apiResponse.message,
          code: apiResponse.code,
        );
      }

      if (apiResponse.data == null) {
        return [];
      }

      return apiResponse.data!
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: '数据解析失败: $e',
        code: -100,
      );
    }
  }

  /// 处理分页响应
  PagedResponse<T> _handlePagedResponse<T>(
    Response response,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    try {
      final apiResponse = ApiResponse<List<dynamic>>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data as List<dynamic>,
      );

      if (!apiResponse.isSuccess) {
        throw ApiException(
          message: apiResponse.message,
          code: apiResponse.code,
        );
      }

      final items = apiResponse.data
              ?.map((item) => fromJson(item as Map<String, dynamic>))
              .toList() ??
          [];

      return PagedResponse<T>(
        items: items,
        page: apiResponse.page ?? 1,
        size: apiResponse.size ?? items.length,
        total: apiResponse.total ?? items.length,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: '数据解析失败: $e',
        code: -100,
      );
    }
  }

  /// 验证响应（无返回数据）
  void _validateResponse(Response response) {
    try {
      final apiResponse = ApiResponse<dynamic>.fromJson(
        response.data as Map<String, dynamic>,
        (data) => data,
      );

      if (!apiResponse.isSuccess) {
        throw ApiException(
          message: apiResponse.message,
          code: apiResponse.code,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: '响应验证失败: $e',
        code: -100,
      );
    }
  }
}

/// 分页响应封装
class PagedResponse<T> {
  final List<T> items;
  final int page;
  final int size;
  final int total;

  PagedResponse({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });

  /// 总页数
  int get totalPages => size > 0 ? (total + size - 1) ~/ size : 0;

  /// 是否有下一页
  bool get hasNext => page < totalPages;

  /// 是否有上一页
  bool get hasPrevious => page > 1;
}
