import '../models/gift.dart';
import '../models/guest.dart';
import '../models/event_book.dart';
import 'http_client.dart';
import 'api_config.dart';

/// ============================================
/// 认证 API 服务
/// ============================================

class AuthApiService {
  final HttpClient _client;

  AuthApiService(this._client);

  /// 用户登录
  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    return await _client.post<LoginResponse>(
      path: ApiConfig.login,
      data: {
        'email': email,
        'password': password,
      },
      fromJson: LoginResponse.fromJson,
    );
  }

  /// 用户注册
  Future<RegisterResponse> register({
    required String email,
    required String password,
    required String username,
    required String fullName,
  }) async {
    return await _client.post<RegisterResponse>(
      path: ApiConfig.register,
      data: {
        'email': email,
        'password': password,
        'username': username,
        'fullName': fullName,
      },
      fromJson: RegisterResponse.fromJson,
    );
  }

  /// 刷新令牌
  Future<LoginResponse> refreshToken(String refreshToken) async {
    return await _client.post<LoginResponse>(
      path: ApiConfig.refresh,
      data: {'refreshToken': refreshToken},
      fromJson: LoginResponse.fromJson,
    );
  }

  /// 登出
  Future<void> logout(String refreshToken) async {
    await _client.postVoid(
      path: ApiConfig.logout,
      data: {'refreshToken': refreshToken},
    );
  }

  /// 修改密码
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.postVoid(
      path: ApiConfig.changePassword,
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  /// 获取当前用户信息
  Future<UserResponse> getCurrentUser() async {
    return await _client.get<UserResponse>(
      path: ApiConfig.userMe,
      fromJson: UserResponse.fromJson,
    );
  }

  /// 更新用户信息
  Future<UserResponse> updateUser({
    String? username,
    String? email,
    String? fullName,
  }) async {
    return await _client.put<UserResponse>(
      path: ApiConfig.userMe,
      data: {
        if (username != null) 'username': username,
        if (email != null) 'email': email,
        if (fullName != null) 'fullName': fullName,
      },
      fromJson: UserResponse.fromJson,
    );
  }
}

/// 登录响应
class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn: json['expiresIn'] as int,
    );
  }
}

/// 注册响应
class RegisterResponse {
  final String userId;
  final String username;
  final String email;
  final String fullName;
  final DateTime createdAt;

  RegisterResponse({
    required this.userId,
    required this.username,
    required this.email,
    required this.fullName,
    required this.createdAt,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      userId: (json['userId'] ?? json['id']) as String,
      username: json['username'] as String,
      email: json['email'] as String,
      fullName: (json['fullName'] as String?) ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// 用户响应
class UserResponse {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final DateTime createdAt;

  UserResponse({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.createdAt,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      fullName: (json['fullName'] as String?) ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// ============================================
/// 礼金 API 服务
/// ============================================

class GiftApiService {
  final HttpClient _client;

  GiftApiService(this._client);

  /// 获取礼金列表（分页）
  Future<PagedResponse<Gift>> getGifts({
    int page = 1,
    int size = 20,
    String? guestId,
    bool? isReceived,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'size': size,
    };
    if (guestId != null) queryParams['guestId'] = guestId;
    if (isReceived != null) queryParams['isReceived'] = isReceived;

    return await _client.getPaged<Gift>(
      path: ApiConfig.gifts,
      queryParameters: queryParams,
      fromJson: Gift.fromJson,
    );
  }

  /// 获取单个礼金记录
  Future<Gift> getGift(String id) async {
    return await _client.get<Gift>(
      path: '${ApiConfig.gifts}/$id',
      fromJson: Gift.fromJson,
    );
  }

  /// 创建礼金记录
  Future<Gift> createGift(Gift gift) async {
    return await _client.post<Gift>(
      path: ApiConfig.gifts,
      data: gift.toJson(),
      fromJson: Gift.fromJson,
    );
  }

  /// 更新礼金记录
  Future<Gift> updateGift(String id, Gift gift) async {
    return await _client.put<Gift>(
      path: '${ApiConfig.gifts}/$id',
      data: gift.toJson(),
      fromJson: Gift.fromJson,
    );
  }

  /// 删除礼金记录
  Future<void> deleteGift(String id) async {
    await _client.delete(path: '${ApiConfig.gifts}/$id');
  }
}

/// ============================================
/// 联系人 API 服务
/// ============================================

class GuestApiService {
  final HttpClient _client;

  GuestApiService(this._client);

  /// 获取联系人列表（分页）
  Future<PagedResponse<Guest>> getGuests({
    int page = 1,
    int size = 20,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'size': size,
    };
    if (search != null) queryParams['search'] = search;

    return await _client.getPaged<Guest>(
      path: ApiConfig.guests,
      queryParameters: queryParams,
      fromJson: Guest.fromJson,
    );
  }

  /// 获取单个联系人
  Future<Guest> getGuest(String id) async {
    return await _client.get<Guest>(
      path: '${ApiConfig.guests}/$id',
      fromJson: Guest.fromJson,
    );
  }

  /// 创建联系人
  Future<Guest> createGuest(Guest guest) async {
    return await _client.post<Guest>(
      path: ApiConfig.guests,
      data: guest.toJson(),
      fromJson: Guest.fromJson,
    );
  }

  /// 更新联系人
  Future<Guest> updateGuest(String id, Guest guest) async {
    return await _client.put<Guest>(
      path: '${ApiConfig.guests}/$id',
      data: guest.toJson(),
      fromJson: Guest.fromJson,
    );
  }

  /// 删除联系人
  Future<void> deleteGuest(String id) async {
    await _client.delete(path: '${ApiConfig.guests}/$id');
  }
}

/// ============================================
/// 活动账本 API 服务
/// ============================================

class EventBookApiService {
  final HttpClient _client;

  EventBookApiService(this._client);

  /// 获取活动账本列表
  Future<List<EventBook>> getEventBooks() async {
    return await _client.getList<EventBook>(
      path: ApiConfig.eventBooks,
      fromJson: EventBook.fromJson,
    );
  }

  /// 获取单个活动账本
  Future<EventBook> getEventBook(String id) async {
    return await _client.get<EventBook>(
      path: '${ApiConfig.eventBooks}/$id',
      fromJson: EventBook.fromJson,
    );
  }

  /// 创建活动账本
  Future<EventBook> createEventBook(EventBook eventBook) async {
    return await _client.post<EventBook>(
      path: ApiConfig.eventBooks,
      data: eventBook.toJson(),
      fromJson: EventBook.fromJson,
    );
  }

  /// 更新活动账本
  Future<EventBook> updateEventBook(String id, EventBook eventBook) async {
    return await _client.put<EventBook>(
      path: '${ApiConfig.eventBooks}/$id',
      data: eventBook.toJson(),
      fromJson: EventBook.fromJson,
    );
  }

  /// 删除活动账本
  Future<void> deleteEventBook(String id) async {
    await _client.delete(path: '${ApiConfig.eventBooks}/$id');
  }
}

/// ============================================
/// 统计 API 服务
/// ============================================

class StatisticsApiService {
  final HttpClient _client;

  StatisticsApiService(this._client);

  /// 获取统计报告
  Future<StatisticsResponse> getSummary({
    DateTime? from,
    DateTime? to,
  }) async {
    final queryParams = <String, dynamic>{};
    if (from != null) {
      queryParams['from'] = from.toIso8601String().split('T')[0];
    }
    if (to != null) {
      queryParams['to'] = to.toIso8601String().split('T')[0];
    }

    return await _client.get<StatisticsResponse>(
      path: ApiConfig.reportsSummary,
      queryParameters: queryParams,
      fromJson: StatisticsResponse.fromJson,
    );
  }
}

/// 统计响应
class StatisticsResponse {
  final double totalReceived;
  final double totalSent;
  final double netAmount;
  final int giftCount;
  final int guestCount;
  final String period;

  StatisticsResponse({
    required this.totalReceived,
    required this.totalSent,
    required this.netAmount,
    required this.giftCount,
    required this.guestCount,
    required this.period,
  });

  factory StatisticsResponse.fromJson(Map<String, dynamic> json) {
    return StatisticsResponse(
      totalReceived: (json['totalReceived'] as num).toDouble(),
      totalSent: (json['totalSent'] as num).toDouble(),
      netAmount: (json['netAmount'] as num).toDouble(),
      giftCount: json['giftCount'] as int,
      guestCount: json['guestCount'] as int,
      period: json['period'] as String,
    );
  }
}

/// ============================================
/// 提醒 API 服务
/// ============================================

class ReminderApiService {
  final HttpClient _client;

  ReminderApiService(this._client);

  /// 获取待还礼提醒
  Future<List<ReminderItem>> getPendingReminders() async {
    return await _client.getList<ReminderItem>(
      path: ApiConfig.remindersPending,
      fromJson: ReminderItem.fromJson,
    );
  }
}

/// 提醒项
class ReminderItem {
  final Gift gift;
  final String guestName;
  final int daysSinceReceived;
  final double suggestedAmount;

  ReminderItem({
    required this.gift,
    required this.guestName,
    required this.daysSinceReceived,
    required this.suggestedAmount,
  });

  factory ReminderItem.fromJson(Map<String, dynamic> json) {
    return ReminderItem(
      gift: Gift.fromJson(json['gift'] as Map<String, dynamic>),
      guestName: json['guestName'] as String,
      daysSinceReceived: json['daysSinceReceived'] as int,
      suggestedAmount: (json['suggestedAmount'] as num).toDouble(),
    );
  }
}

/// ============================================
/// 导出 API 服务
/// ============================================

class ExportApiService {
  final HttpClient _client;

  ExportApiService(this._client);

  /// 导出 JSON 数据
  Future<ExportData> exportJson() async {
    return await _client.get<ExportData>(
      path: ApiConfig.exportsJson,
      fromJson: ExportData.fromJson,
    );
  }

  /// 导出 Excel 数据（返回文件 URL 或 Base64）
  Future<String> exportExcel() async {
    // TODO: 根据后端实际返回格式调整
    // 可能返回下载链接或 Base64 编码的文件内容
    return await _client.get<String>(
      path: ApiConfig.exportsExcel,
      fromJson: (json) => json['url'] as String,
    );
  }
}

/// 导出数据
class ExportData {
  final DateTime exportedAt;
  final List<Guest> guests;
  final List<EventBook> eventBooks;
  final List<Gift> gifts;

  ExportData({
    required this.exportedAt,
    required this.guests,
    required this.eventBooks,
    required this.gifts,
  });

  factory ExportData.fromJson(Map<String, dynamic> json) {
    return ExportData(
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      guests: (json['guests'] as List)
          .map((e) => Guest.fromJson(e as Map<String, dynamic>))
          .toList(),
      eventBooks: (json['eventBooks'] as List)
          .map((e) => EventBook.fromJson(e as Map<String, dynamic>))
          .toList(),
      gifts: (json['gifts'] as List)
          .map((e) => Gift.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
