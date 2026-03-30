/// 统一 API 响应格式（匹配后端）
class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;
  final int? page;
  final int? size;
  final int? total;

  ApiResponse({
    required this.code,
    required this.message,
    this.data,
    this.page,
    this.size,
    this.total,
  });

  /// 是否成功
  bool get isSuccess => code >= 200 && code < 300;

  /// 是否分页响应
  bool get isPaged => page != null && size != null && total != null;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse<T>(
      code: json['code'] as int,
      message: json['message'] as String,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      page: json['page'] as int?,
      size: json['size'] as int?,
      total: json['total'] as int?,
    );
  }

  Map<String, dynamic> toJson(Object? Function(T)? toJsonT) {
    final map = <String, dynamic>{
      'code': code,
      'message': message,
    };

    if (data != null && toJsonT != null) {
      map['data'] = toJsonT(data as T);
    } else {
      map['data'] = data;
    }

    if (page != null) map['page'] = page;
    if (size != null) map['size'] = size;
    if (total != null) map['total'] = total;

    return map;
  }
}

/// 分页数据包装（备用，如果后端使用嵌套格式）
class PagedData<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final int totalPages;

  PagedData({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory PagedData.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return PagedData<T>(
      items: (json['items'] as List)
          .map((item) => fromJsonT(item as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['pageSize'] as int,
      totalPages: json['totalPages'] as int,
    );
  }
}
