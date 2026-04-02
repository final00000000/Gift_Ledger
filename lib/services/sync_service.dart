import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/api_providers.dart';
import '../services/guest_service.dart';
import '../services/gift_service.dart';
import '../services/event_book_service.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final String? message;
  final DateTime? lastSyncAt;

  SyncState({this.status = SyncStatus.idle, this.message, this.lastSyncAt});

  SyncState copyWith({SyncStatus? status, String? message, DateTime? lastSyncAt}) {
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

  Future<void> syncAll() async {
    if (!_isAuthenticated) return;
    if (state.status == SyncStatus.syncing) return;

    state = state.copyWith(status: SyncStatus.syncing, message: '同步中...');

    try {
      await _uploadGuests();
      await _uploadEventBooks();
      await _uploadGifts();

      state = state.copyWith(
        status: SyncStatus.success,
        message: '同步完成',
        lastSyncAt: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        status: SyncStatus.error,
        message: '同步失败: $e',
      );
    }
  }

  Future<void> _uploadGuests() async {
    final guestApi = _ref.read(guestApiServiceProvider);
    final localGuests = await GuestService().getAllGuests();

    for (final guest in localGuests) {
      try {
        await guestApi.createGuest(guest);
      } catch (_) {}
    }
  }

  Future<void> _uploadEventBooks() async {
    final eventBookApi = _ref.read(eventBookApiServiceProvider);
    final localBooks = await EventBookService().getAllEventBooks();

    for (final book in localBooks) {
      try {
        await eventBookApi.createEventBook(book);
      } catch (_) {}
    }
  }

  Future<void> _uploadGifts() async {
    final giftApi = _ref.read(giftApiServiceProvider);
    final localGifts = await GiftService().getAllGifts();

    for (final gift in localGifts) {
      try {
        await giftApi.createGift(gift);
      } catch (_) {}
    }
  }
}

final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>(
  (ref) => SyncNotifier(ref),
);
