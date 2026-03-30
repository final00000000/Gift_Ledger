import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_config.dart';
import '../services/api_interceptors.dart';
import '../services/http_client.dart';
import '../services/api_services.dart';

/// ============================================
/// Dio Provider
/// ============================================

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: ApiConfig.connectTimeout,
    receiveTimeout: ApiConfig.receiveTimeout,
  ));

  // 添加 API 拦截器
  dio.interceptors.add(
    ApiInterceptor(
      getToken: () {
        return ref.read(authTokenProvider);
      },
      onUnauthorized: () {
        ref.read(authStateProvider.notifier).logout();
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

/// ============================================
/// HttpClient Provider
/// ============================================

final httpClientProvider = Provider<HttpClient>((ref) {
  return HttpClient(ref.watch(dioProvider));
});

/// ============================================
/// Auth State Management
/// ============================================

/// Auth Token Provider
final authTokenProvider = StateProvider<String?>((ref) => null);

/// Auth State Provider
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(),
);

class AuthState {
  final bool isAuthenticated;
  final String? userId;
  final String? username;
  final String? email;

  AuthState({
    this.isAuthenticated = false,
    this.userId,
    this.username,
    this.email,
  });
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier() : super(AuthState());

  void login(String userId, String username, String email, String token) {
    state = AuthState(
      isAuthenticated: true,
      userId: userId,
      username: username,
      email: email,
    );
  }

  void logout() {
    state = AuthState(isAuthenticated: false);
  }
}

/// ============================================
/// Loading State Management
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

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return AuthApiService(ref.watch(httpClientProvider));
});

final giftApiServiceProvider = Provider<GiftApiService>((ref) {
  return GiftApiService(ref.watch(httpClientProvider));
});

final guestApiServiceProvider = Provider<GuestApiService>((ref) {
  return GuestApiService(ref.watch(httpClientProvider));
});

final eventBookApiServiceProvider = Provider<EventBookApiService>((ref) {
  return EventBookApiService(ref.watch(httpClientProvider));
});

final statisticsApiServiceProvider = Provider<StatisticsApiService>((ref) {
  return StatisticsApiService(ref.watch(httpClientProvider));
});

final reminderApiServiceProvider = Provider<ReminderApiService>((ref) {
  return ReminderApiService(ref.watch(httpClientProvider));
});

final exportApiServiceProvider = Provider<ExportApiService>((ref) {
  return ExportApiService(ref.watch(httpClientProvider));
});
