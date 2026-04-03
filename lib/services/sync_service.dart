import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_providers.dart';
import '../services/api_config.dart';
import '../services/event_book_service.dart';
import '../services/gift_service.dart';
import '../services/guest_service.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final String? message;
  final DateTime? lastSyncAt;

  SyncState({this.status = SyncStatus.idle, this.message, this.lastSyncAt});

  SyncState copyWith({
    SyncStatus? status,
    String? message,
    DateTime? lastSyncAt,
  }) {
    return SyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}

class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;

  SyncNotifier(this._ref) : super(SyncState());

  bool get _isAuthenticated => _ref.read(authStateProvider).isAuthenticated;
  Dio get _dio => _ref.read(dioProvider);

  Future<void> syncAll() async {
    if (!_isAuthenticated) return;
    if (state.status == SyncStatus.syncing) return;

    state = state.copyWith(status: SyncStatus.syncing, message: '正在执行全量同步...');

    try {
      final remoteGuests = await _fetchRemoteGuests();
      final guestIdMap = await _syncGuests(remoteGuests);

      final remoteEventBooks = await _fetchRemoteEventBooks();
      final eventBookIdMap = await _syncEventBooks(remoteEventBooks);

      final remoteGifts = await _fetchRemoteGifts();
      final giftCount = await _syncGifts(
        remoteGifts: remoteGifts,
        guestIdMap: guestIdMap,
        eventBookIdMap: eventBookIdMap,
      );

      state = state.copyWith(
        status: SyncStatus.success,
        message: '全量同步完成：宾客 ${guestIdMap.length}，活动簿 ${eventBookIdMap.length}，礼金新增 $giftCount',
        lastSyncAt: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: '同步失败: $e',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRemoteGuests() async {
    final response = await _dio.get(
      ApiConfig.guests,
      queryParameters: {'page': 1, 'pageSize': 500},
      options: Options(extra: {'showLoading': false}),
    );
    final data = response.data['data'] as List<dynamic>? ?? const [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _fetchRemoteEventBooks() async {
    final response = await _dio.get(
      ApiConfig.eventBooks,
      options: Options(extra: {'showLoading': false}),
    );
    final data = (response.data['data'] as Map<String, dynamic>? ?? const {})['eventBooks'] as List<dynamic>? ?? const [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> _fetchRemoteGifts() async {
    final response = await _dio.get(
      ApiConfig.gifts,
      queryParameters: {'page': 1, 'pageSize': 1000},
      options: Options(extra: {'showLoading': false}),
    );
    final data = response.data['data'] as List<dynamic>? ?? const [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<Map<int, String>> _syncGuests(List<Map<String, dynamic>> remoteGuests) async {
    final localGuests = await const GuestService().getAllGuests();
    final remoteByKey = <String, String>{
      for (final guest in remoteGuests)
        _guestKey(
          name: guest['name'] as String? ?? '',
          relationship: guest['relationship'] as String? ?? '',
          phone: guest['phone'] as String?,
        ): guest['id'] as String,
    };

    final guestIdMap = <int, String>{};
    for (final guest in localGuests) {
      final key = _guestKey(
        name: guest.name,
        relationship: guest.relationship,
        phone: guest.phone,
      );
      final existingId = remoteByKey[key];
      if (existingId != null) {
        if (guest.id != null) guestIdMap[guest.id!] = existingId;
        continue;
      }

      final response = await _dio.post(
        ApiConfig.guests,
        data: {
          'name': guest.name,
          'relationship': guest.relationship,
          'phone': guest.phone,
          'note': guest.note,
        },
        options: Options(extra: {'showLoading': false}),
      );
      final remoteId = response.data['data']['id'] as String;
      remoteByKey[key] = remoteId;
      if (guest.id != null) guestIdMap[guest.id!] = remoteId;
    }
    return guestIdMap;
  }

  Future<Map<int, String>> _syncEventBooks(List<Map<String, dynamic>> remoteEventBooks) async {
    final localBooks = await const EventBookService().getAllEventBooks();
    final remoteByKey = <String, String>{
      for (final book in remoteEventBooks)
        _eventBookKey(
          name: book['name'] as String? ?? '',
          type: book['type'] as String? ?? '',
          eventDate: book['eventDate'] as String? ?? '',
        ): book['id'] as String,
    };

    final eventBookIdMap = <int, String>{};
    for (final book in localBooks) {
      final key = _eventBookKey(
        name: book.name,
        type: book.type,
        eventDate: _dateOnly(book.date),
      );
      final existingId = remoteByKey[key];
      if (existingId != null) {
        if (book.id != null) eventBookIdMap[book.id!] = existingId;
        continue;
      }

      final response = await _dio.post(
        ApiConfig.eventBooks,
        data: {
          'name': book.name,
          'type': book.type,
          'eventDate': _dateOnly(book.date),
          'lunarDate': book.lunarDate,
          'note': book.note,
        },
        options: Options(extra: {'showLoading': false}),
      );
      final remoteId = response.data['data']['id'] as String;
      remoteByKey[key] = remoteId;
      if (book.id != null) eventBookIdMap[book.id!] = remoteId;
    }
    return eventBookIdMap;
  }

  Future<int> _syncGifts({
    required List<Map<String, dynamic>> remoteGifts,
    required Map<int, String> guestIdMap,
    required Map<int, String> eventBookIdMap,
  }) async {
    final localGifts = await const GiftService().getAllGifts();
    final remoteKeys = {
      for (final gift in remoteGifts)
        _giftKey(
          guestId: gift['guestId'] as String? ?? '',
          amount: (gift['amount'] as num?)?.toDouble() ?? 0,
          isReceived: gift['isReceived'] as bool? ?? false,
          eventType: gift['eventType'] as String? ?? '',
          occurredAt: gift['occurredAt'] as String? ?? '',
          note: gift['note'] as String?,
          eventBookId: gift['eventBookId'] as String?,
        ),
    };

    var createdCount = 0;
    for (final gift in localGifts) {
      final remoteGuestId = guestIdMap[gift.guestId];
      if (remoteGuestId == null) continue;
      final remoteEventBookId = gift.eventBookId == null ? null : eventBookIdMap[gift.eventBookId!];

      final key = _giftKey(
        guestId: remoteGuestId,
        amount: gift.amount,
        isReceived: gift.isReceived,
        eventType: gift.eventType,
        occurredAt: _dateOnly(gift.date),
        note: gift.note,
        eventBookId: remoteEventBookId,
      );
      if (remoteKeys.contains(key)) continue;

      await _dio.post(
        ApiConfig.gifts,
        data: {
          'guestId': remoteGuestId,
          'isReceived': gift.isReceived,
          'amount': gift.amount,
          'eventType': gift.eventType,
          'eventBookId': remoteEventBookId,
          'occurredAt': _dateOnly(gift.date),
          'note': gift.note,
        },
        options: Options(extra: {'showLoading': false}),
      );
      remoteKeys.add(key);
      createdCount++;
    }
    return createdCount;
  }

  String _guestKey({required String name, required String relationship, String? phone}) {
    return '${name.trim()}|${relationship.trim()}|${(phone ?? '').trim()}';
  }

  String _eventBookKey({required String name, required String type, required String eventDate}) {
    return '${name.trim()}|${type.trim()}|${eventDate.trim()}';
  }

  String _giftKey({
    required String guestId,
    required double amount,
    required bool isReceived,
    required String eventType,
    required String occurredAt,
    String? note,
    String? eventBookId,
  }) {
    return '$guestId|${amount.toStringAsFixed(2)}|$isReceived|${eventType.trim()}|${occurredAt.trim()}|${(eventBookId ?? '').trim()}|${(note ?? '').trim()}';
  }

  String _dateOnly(DateTime value) => value.toIso8601String().split('T').first;
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>(
  (ref) => SyncNotifier(ref),
);
