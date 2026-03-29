import '../models/event_book.dart';
import 'database_service_native.dart' if (dart.library.js_interop) 'database_service_web_indexed.dart';

class EventBookService {
  const EventBookService();

  Future<int> insertEventBook(EventBook eventBook) {
    return nativeDb.insertEventBook(eventBook);
  }

  Future<List<EventBook>> getAllEventBooks() {
    return nativeDb.getAllEventBooks();
  }

  Future<EventBook?> getEventBookById(int id) {
    return nativeDb.getEventBookById(id);
  }

  Future<int> updateEventBook(EventBook eventBook) {
    return nativeDb.updateEventBook(eventBook);
  }

  Future<int> deleteEventBook(int id) {
    return nativeDb.deleteEventBook(id);
  }

  Future<double> getEventBookReceivedTotal(int eventBookId) {
    return nativeDb.getEventBookReceivedTotal(eventBookId);
  }

  Future<double> getEventBookSentTotal(int eventBookId) {
    return nativeDb.getEventBookSentTotal(eventBookId);
  }

  Future<int> getEventBookGiftCount(int eventBookId) {
    return nativeDb.getEventBookGiftCount(eventBookId);
  }

  Future<Map<int, int>> getEventBookGiftCounts(List<int> eventBookIds) {
    return nativeDb.getEventBookGiftCounts(eventBookIds);
  }
}
