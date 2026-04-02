import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/http_client.dart';
import '../services/api_config.dart';
import '../services/api_interceptors.dart';
import '../services/api_services.dart';

const _kAccessToken = 'access_token';
const _kRefreshToken = 'refresh_token';
const _kUserId = 'user_id';
const _kUsername = 'username';
const _kEmail = 'email';
const _kFullName = 'full_name';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// ============================================
/// Dio 和 HttpClient Providers
/// ============================================

/// Dio Provider
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: ApiConfig.connectTimeout,
    receiveTimeout: ApiConfig.receiveTimeout,
  ));

  dio.interceptors.add(
    ApiInterceptor(
      getToken: () => ref.read(authTokenProvider),
      getRefreshToken: () => ref.read(refreshTokenProvider),
      refreshTokens: (rt) async {
        try {
          final refreshDio = Dio(BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: ApiConfig.connectTimeout,
            receiveTimeout: ApiConfig.receiveTimeout,
          ));
          final resp = await refreshDio.post(
            ApiConfig.refresh,
            data: {'refreshToken': rt},
          );
          final data = resp.data['data'] as Map<String, dynamic>?;
          if (data != null) {
            return {
              'accessToken': data['accessToken'] as String,
              'refreshToken': data['refreshToken'] as String,
            };
          }
        } catch (_) {}
        return null;
      },
      onTokensRefreshed: (accessToken, refreshToken) async {
        await ref.read(authStateProvider.notifier).updateTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
      },
      onUnauthorized: () async {
        await ref.read(authStateProvider.notifier).logout();
      },
    ),
  );

  // 添加 Loading 拦截器
  dio.interceptors.add(
    LoadingInterceptor(
      onShowLoading: () {
        ref.read(loadingStateProvider.notifier).show();
      },
      onHideLoading: () {
        ref.read(loadingStateProvider.notifier).hide();
      },
    ),
  );

  return dio;
});

/// HttpClient Provider
final httpClientProvider = Provider<HttpClient>((ref) {
  return HttpClient(ref.watch(dioProvider));
});

/// ============================================
/// Auth State Providers
/// ============================================

/// Auth Token Provider
final authTokenProvider = StateProvider<String?>((ref) => null);

/// Refresh Token Provider
final refreshTokenProvider = StateProvider<String?>((ref) => null);

/// Auth State Provider
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(ref),
);

class AuthState {
  final bool isAuthenticated;
  final String? userId;
  final String? username;
  final String? email;
  final String? fullName;

  AuthState({
    this.isAuthenticated = false,
    this.userId,
    this.username,
    this.email,
    this.fullName,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? userId,
    String? username,
    String? email,
    String? fullName,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
    );
  }
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthStateNotifier(this._ref) : super(AuthState());

  FlutterSecureStorage get _storage => _ref.read(secureStorageProvider);

  /// 从持久化存储恢复认证状态
  Future<void> restoreAuth() async {
    final accessToken = await _storage.read(key: _kAccessToken);
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (accessToken == null) return;

    final userId = await _storage.read(key: _kUserId);
    final username = await _storage.read(key: _kUsername);
    final email = await _storage.read(key: _kEmail);
    final fullName = await _storage.read(key: _kFullName);

    state = AuthState(
      isAuthenticated: true,
      userId: userId,
      username: username,
      email: email,
      fullName: fullName,
    );
    _ref.read(authTokenProvider.notifier).state = accessToken;
    _ref.read(refreshTokenProvider.notifier).state = refreshToken;
  }

  /// 登录
  Future<void> login({
    required String userId,
    required String username,
    required String email,
    required String fullName,
    required String accessToken,
    required String refreshToken,
  }) async {
    state = AuthState(
      isAuthenticated: true,
      userId: userId,
      username: username,
      email: email,
      fullName: fullName,
    );
    _ref.read(authTokenProvider.notifier).state = accessToken;
    _ref.read(refreshTokenProvider.notifier).state = refreshToken;

    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
    await _storage.write(key: _kUserId, value: userId);
    await _storage.write(key: _kUsername, value: username);
    await _storage.write(key: _kEmail, value: email);
    await _storage.write(key: _kFullName, value: fullName);
  }

  /// 登出
  Future<void> logout() async {
    state = AuthState(isAuthenticated: false);
    _ref.read(authTokenProvider.notifier).state = null;
    _ref.read(refreshTokenProvider.notifier).state = null;

    await _storage.deleteAll();
  }

  /// 更新 token（刷新后调用）
  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _ref.read(authTokenProvider.notifier).state = accessToken;
    _ref.read(refreshTokenProvider.notifier).state = refreshToken;
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
  }

  /// 更新用户信息
  void updateUser({
    String? username,
    String? email,
    String? fullName,
  }) {
    state = state.copyWith(
      username: username,
      email: email,
      fullName: fullName,
    );
  }
}

/// ============================================
/// Loading State Provider
/// ============================================

final loadingStateProvider =
    StateNotifierProvider<LoadingStateNotifier, int>((ref) {
  return LoadingStateNotifier();
});

class LoadingStateNotifier extends StateNotifier<int> {
  LoadingStateNotifier() : super(0);

  void show() {
    state++;
  }

  void hide() {
    if (state > 0) {
      state--;
    }
  }

  bool get isLoading => state > 0;
}

/// ============================================
/// API Service Providers
/// ============================================

/// 认证 API 服务
final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService(ref.watch(httpClientProvider));
});

/// 礼金 API 服务
final giftApiServiceProvider = Provider<GiftApiService>((ref) {
  return GiftApiService(ref.watch(httpClientProvider));
});

/// 联系人 API 服务
final guestApiServiceProvider = Provider<GuestApiService>((ref) {
  return GuestApiService(ref.watch(httpClientProvider));
});

/// 活动账本 API 服务
final eventBookApiServiceProvider = Provider<EventBookApiService>((ref) {
  return EventBookApiService(ref.watch(httpClientProvider));
});

/// 统计 API 服务
final statisticsApiServiceProvider = Provider<StatisticsApiService>((ref) {
  return StatisticsApiService(ref.watch(httpClientProvider));
});

/// 提醒 API 服务
final reminderApiServiceProvider = Provider<ReminderApiService>((ref) {
  return ReminderApiService(ref.watch(httpClientProvider));
});

/// 导出 API 服务
final exportApiServiceProvider = Provider<ExportApiService>((ref) {
  return ExportApiService(ref.watch(httpClientProvider));
});
